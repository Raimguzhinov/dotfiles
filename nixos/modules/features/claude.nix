{ ... }:
{
  flake.homeModules.claude =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      typesafeSkills = pkgs.fetchFromGitHub {
        owner = "typesafe-ai";
        repo = "skills";
        rev = "65a39f393687675ce170e6094757de20370365b9";
        hash = "sha256-Lh2Y90TFv+njKqo/g5WXEHw0Rk1jQSH5POqKtrvy5kM=";
      };

      jevQuestions = pkgs.writers.writeJSON "jev-questions.json" {
        model = {
          type = "choice";
          instructions = "Which Claude model should execute `task`, a subagent job delegated by a coding agent? Pick the cheapest model that will reliably complete it; cost and latency rise steeply from haiku to fable.";
          criteria = {
            haiku = "Mechanical or lookup work with no real judgment: finding files or symbols, grepping, listing, reading and summarizing a few files, running a known command and reporting its output, trivial edits.";
            sonnet = "Routine engineering with a clear spec: implementing a well-defined change in a few files, writing tests for known behavior, straightforward bug fixes, focused code review, writing docs.";
            opus = "Hard engineering that needs careful reasoning: debugging unclear failures, cross-module refactors, design decisions with trade-offs, security or concurrency review, synthesizing research from many sources.";
            fable = "The most demanding long-horizon work where a mistake is costly and depth matters more than cost: open-ended investigations across many systems, novel architecture or algorithm design, low-level root-cause analysis, problems weaker models are likely to get wrong.";
          };
        };
      };

      jevRouter = pkgs.writeShellApplication {
        name = "jev-router";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          findutils
          jq
        ];
        text = # bash
          ''
            state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/jev-router"
            sessions_dir="$state_dir/sessions"
            log="$state_dir/decisions.jsonl"
            key_file=${lib.escapeShellArg config.sops.secrets."typesafe/api_key".path}
            excluded_root="$HOME/Work"
            min_confidence="''${JEV_MIN_CONFIDENCE:-0.25}"

            api_key() {
              if [[ -n "''${TYPESAFE_API_KEY:-}" ]]; then
                printf '%s' "$TYPESAFE_API_KEY"
              elif [[ -r "$key_file" ]]; then
                cat "$key_file"
              fi
            }

            is_off() {
              [[ -e "$sessions_dir/$1.off" ]]
            }

            notice() {
              jq -cn --arg m "jev: $1" '{systemMessage: $m}'
            }

            route() {
              local input session cwd key request response choice confidence
              input=$(cat)
              session=$(jq -r '.session_id // ""' <<<"$input")
              ! is_off "$session" || exit 0
              cwd=$(jq -r '.cwd // ""' <<<"$input")
              case "$cwd/" in
                "$excluded_root"/*) exit 0 ;;
              esac

              key=$(api_key)
              if [[ -z "$key" ]]; then
                notice "TypeSafe API key not found, subagent model left as is"
                exit 0
              fi

              request=$(jq -c --slurpfile q ${jevQuestions} '{
                model: "jev-latest",
                state: {
                  task: {
                    subagent_type: (.tool_input.subagent_type // "general-purpose"),
                    description: (.tool_input.description // ""),
                    prompt: ((.tool_input.prompt // "")[:12000])
                  }
                },
                questions: $q[0]
              }' <<<"$input")

              if ! response=$(curl -sS --fail-with-body --max-time 10 \
                -H @<(printf 'Authorization: Bearer %s\n' "$key") \
                -H 'Content-Type: application/json' \
                --data-binary "$request" \
                https://api.typesafe.ai/v1/systemone 2>&1); then
                notice "TypeSafe request failed: ''${response:0:200}"
                exit 0
              fi

              choice=$(jq -r '.answers.model.choice // empty' <<<"$response")
              confidence=$(jq -r '.answers.model.confidence // 0' <<<"$response")
              if [[ -z "$choice" ]]; then
                notice "unexpected TypeSafe response: ''${response:0:200}"
                exit 0
              fi

              mkdir -p "$state_dir"
              jq -cn \
                --arg ts "$(date -Is)" \
                --arg session "$session" \
                --arg description "$(jq -r '.tool_input.description // ""' <<<"$input")" \
                --arg requested "$(jq -r '.tool_input.model // "inherit"' <<<"$input")" \
                --argjson answer "$(jq -c '.answers.model' <<<"$response")" \
                --argjson min "$min_confidence" \
                '{ts: $ts, session: $session, description: $description, requested: $requested, answer: $answer, applied: ($answer.confidence >= $min)}' \
                >>"$log"

              if ! jq -e --argjson min "$min_confidence" '.answers.model.confidence >= $min' <<<"$response" >/dev/null; then
                notice "low confidence for $choice ($confidence), subagent model left as is"
                exit 0
              fi

              jq -c --arg choice "$choice" --arg confidence "$confidence" '{
                systemMessage: "jev → \($choice) (confidence \($confidence))",
                hookSpecificOutput: {
                  hookEventName: "PreToolUse",
                  permissionDecision: "allow",
                  updatedInput: (.tool_input + {model: $choice}),
                  additionalContext: "Jev router ran this subagent on the \($choice) model."
                }
              }' <<<"$input"
            }

            status() {
              if is_off "$1"; then
                echo "jev router: off for this session"
              else
                echo "jev router: on for this session (min confidence $min_confidence, never under $excluded_root)"
              fi
              [[ -n "$(api_key)" ]] || echo "warning: TypeSafe API key not found (sops typesafe/api_key or TYPESAFE_API_KEY)"
              [[ -s "$log" ]] || return 0
              jq -rs --arg s "$1" '
                map(select(.session == $s)) | .[-5:]
                | if length > 0 then "last decisions in this session:" else empty end,
                  (.[] | "  \(.ts)  \(.answer.choice)  \(.answer.confidence)  \(if .applied then "applied" else "skipped" end)  \(.description)")
              ' "$log"
            }

            if [[ "''${1:-}" == hook ]]; then
              route
              exit 0
            fi

            session="''${1:-}"
            if [[ ! "$session" =~ ^[A-Za-z0-9_-]+$ ]]; then
              echo "usage: jev-router hook | jev-router <session-id> [on|off|status]" >&2
              exit 1
            fi

            case "''${2:-status}" in
              on)
                rm -f "$sessions_dir/$session.off"
                status "$session"
                ;;
              off)
                mkdir -p "$sessions_dir"
                find "$sessions_dir" -name '*.off' -mtime +30 -delete
                touch "$sessions_dir/$session.off"
                status "$session"
                ;;
              status) status "$session" ;;
              *)
                echo "usage: /jev on | off | status" >&2
                exit 1
                ;;
            esac
          '';
      };

      appendSystemFile = pkgs.writeText "claude-append-system.md" /* markdown */ ''
        The user is a senior developer. Communication is plain, concise and actionable. Every answer exists to solve the problem.

        ## Language
        - Always reply in Russian. Code, identifiers, paths, commands and quoted tool output stay unchanged.

        ## Punctuation (prose only, never change code, commands or paths)
        - Never use a dash as punctuation: no "—", no "–", no " - " between words. Use a comma, colon, period or parentheses, or split the sentence. Hyphens inside words (read-only, кто-то) and "- " list markers are fine.
        - Never use ";" in prose. Split it into sentences.

        ## Style
        - The user reads the end of the answer first. Put the result or the most important fact last.
        - Use plain, specific words. State each fact once. Match the detail to the size of the request.
        - If the user's assumption is wrong, say so directly and explain why.
        - One sentence instead of two, one paragraph instead of two, when nothing is lost.
        - No flattery, praise or agreement without a reason. Never write "Отличный вопрос", "Вы абсолютно правы", "Честно говоря", "Давайте разберёмся", "По сути".
        - No analogies, emoji, decorative headings or motivational phrases.

        ## Reference codes
        When you list three or more findings, decisions, options, risks, questions or actions, prefix each with a code: F1 finding, D1 decision, O1 option, R1 risk, Q1 question, A1 action. Keep the same codes for the whole conversation. No codes in short answers.

        ## Scope
        - Do only what was asked, at the asked scope. No adjacent cleanup, refactoring, documentation or features.
        - No abstractions for hypothetical future needs.
        - Never claim completion without evidence.
        - Never add a co-author line to a commit message.
        - Summarize finished work briefly, not as a detailed report.

        ## Code comments
        - Almost never write comments in code, including godoc and other doc comments on functions, types and packages.
        - Write a comment only when the code cannot explain itself:
          - a workaround for a bug in a library, tool or upstream service
          - an order of operations, locking or concurrency rule that breaks if changed
          - a magic value imposed by a protocol, hardware or external API
          - code that looks dead, wrong or redundant but is intentional
          - a non-obvious side effect or performance trick
        - Never repeat what the code, names or types already say.
        - Format: one short sentence in Russian, no period at the end, no dashes, no ";".
        - Put it at the end of the code line. Only if it does not fit, put it on the line above.

        ## Commands
        If the whole user message is exactly one of these words, act as if its expansion was written instead. Inside a longer message they are ordinary words.
        - кратко: simplify and compress your previous answer, then repeat it.
        - проще: explain it as to an 18 year old, with simpler words and fewer of them.
        - суть: reduce your previous answer to the single thing that matters most.
        - пронумеруй: rewrite your previous answer with reference codes.

        ## Delegation
        You are the orchestrator. Split every task into subtasks and hand each subtask to a subagent with the Agent tool. A router reads each subagent's description and prompt and runs it on haiku, sonnet, opus or fable, so cheap work goes to cheap models and hard work to strong ones.
        - Never set the `model` parameter of the Agent tool. The router chooses it.
        - Delegate: searching and reading code, research in docs, on the web and on GitHub, running builds, tests and linters and analysing their output, implementing well-specified changes, writing tests, reviews and second opinions.
        - Do yourself: talking with the user, clarifying questions, decisions and plans, combining subagent results, and single steps so small that writing the brief costs more than doing them (one short read, one quick command).
        - One subagent, one goal. A subagent sees nothing of this conversation, so every brief is self-contained: the goal, the paths and facts you already know, the constraints, what must not be touched, and the exact shape and length limit of the report.
        - Describe the real difficulty in the description and the brief. Do not inflate or shrink it, the router picks the model from that text.
        - Launch independent subagents in the same turn so they run in parallel. Run them one after another only when one needs another's result.
        - Changes to the same files go to a single subagent, never to parallel ones.
        - Treat subagent reports as claims. Check the key facts (path:line, test output) before building on them or reporting work as done.
        - If a subagent fails or returns a weak result, brief it again with what was missing or split the task further. Do not silently redo the whole task yourself.
        - If you are yourself running as a subagent, do the work directly and never delegate further.

        ## Workflow for code tasks
        Work autonomously until the task is done or you are blocked.
        1. Locate: delegate finding the relevant code. Never guess file contents, APIs or paths.
        2. Plan: if the change touches more than one file, first write a numbered plan of at most 5 steps, each step a subagent brief.
        3. Edit: delegate one small change per subagent. Require matching the existing style and no files, dependencies or refactors that were not asked for.
        4. Verify: delegate running the narrowest build, test or lint command. On failure, send the error to a subagent to fix and re-run. After 3 failed attempts, stop and report.
        5. Report in at most 5 lines: what changed (path:line), how it was verified, what is left.

        Rules:
        - If the request is ambiguous, ask one question before editing anything.
        - If nothing can be run to verify, say so.
        - Do not repeat file contents or tool output back to the user.
        - If the same error appears twice in a row, stop and explain what you tried.

        ## Examples
        User: Файл legacy-config.json ещё где-то используется?
        Good: Нет. Нашёлся только сам файл.
        Bad: Отличный вопрос! Сейчас поищу по репозиторию. Ответ нет. Могу также удалить файл и проверить соседние.

        User: Добавить Redis в эту систему?
        Good: Не надо. Писатель один, состояние восстанавливается из SQLite, координации между хостами нет. Redis добавит точку отказа и не решит ни одной текущей проблемы.
        Bad: Вы абсолютно правы, Redis может помочь! Но вопрос глубже: речь не о кэше, а об архитектуре.
      '';

      claudeCode = pkgs.symlinkJoin {
        name = "claude-code";
        paths = [ pkgs-unstable.claude-code ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm $out/bin/claude
          makeWrapper ${lib.getExe pkgs-unstable.claude-code} $out/bin/claude \
            --add-flags "--append-system-prompt-file ${appendSystemFile}"
        '';
        inherit (pkgs-unstable.claude-code) meta version;
      };

      jevPlugin = pkgs.runCommand "claude-jev-router-plugin" { } ''
        install -Dm644 ${
          pkgs.writers.writeJSON "plugin.json" {
            name = "jev-router";
            description = "Routes Claude Code subagents to haiku, sonnet, opus or fable with TypeSafe Jev";
          }
        } $out/.claude-plugin/plugin.json
        install -Dm644 ${
          pkgs.writers.writeJSON "hooks.json" {
            hooks.PreToolUse = [
              {
                matcher = "Agent|Task";
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe jevRouter} hook";
                    timeout = 15;
                  }
                ];
              }
            ];
          }
        } $out/hooks/hooks.json
      '';
    in
    {
      programs.claude-code = {
        enable = true;
        package = claudeCode;

        plugins = [
          typesafeSkills
          jevPlugin
        ];

        commands.jev = # markdown
          ''
            ---
            description: Jev (TypeSafe) subagent model router — on, off, status
            argument-hint: on | off | status
            disable-model-invocation: true
            allowed-tools: Bash(${lib.getExe jevRouter}:*)
            ---
            !`${lib.getExe jevRouter} ''${CLAUDE_SESSION_ID} $ARGUMENTS`
          '';

        lspServers.gopls = {
          command = lib.getExe pkgs.gopls;
          extensionToLanguage.".go" = "go";
        };

        mcpServers = {
          context7 = {
            type = "http";
            url = "https://mcp.context7.com/mcp";
          };
          gh_grep = {
            type = "http";
            url = "https://mcp.grep.app";
          };
          codebase_memory = {
            type = "stdio";
            command = "npx";
            args = [
              "-y"
              "codebase-memory-mcp"
            ];
            env.CBM_ALLOWED_ROOT = config.home.homeDirectory;
          };
          searxng = {
            type = "stdio";
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:8899";
          };
          typst = {
            type = "stdio";
            command = "docker";
            args = [
              "run"
              "--rm"
              "-i"
              "ghcr.io/johannesbrandenburger/typst-mcp:latest"
            ];
          };
        };
      };
    };
}
