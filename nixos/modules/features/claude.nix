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
          jq
        ];
        text = # bash
          ''
            state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/jev-router"
            flag="$state_dir/enabled"
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

            notice() {
              jq -cn --arg m "jev: $1" '{systemMessage: $m}'
            }

            route() {
              [[ -e "$flag" ]] || exit 0
              local input cwd key request response choice confidence
              input=$(cat)
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
                --arg description "$(jq -r '.tool_input.description // ""' <<<"$input")" \
                --arg requested "$(jq -r '.tool_input.model // "inherit"' <<<"$input")" \
                --argjson answer "$(jq -c '.answers.model' <<<"$response")" \
                --argjson min "$min_confidence" \
                '{ts: $ts, description: $description, requested: $requested, answer: $answer, applied: ($answer.confidence >= $min)}' \
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
              if [[ -e "$flag" ]]; then
                echo "jev router: on (min confidence $min_confidence, never under $excluded_root)"
              else
                echo "jev router: off"
              fi
              [[ -n "$(api_key)" ]] || echo "warning: TypeSafe API key not found (sops typesafe/api_key or TYPESAFE_API_KEY)"
              if [[ -s "$log" ]]; then
                echo "last decisions:"
                tail -n 5 "$log" | jq -r '"  \(.ts)  \(.answer.choice)  \(.answer.confidence)  \(if .applied then "applied" else "skipped" end)  \(.description)"'
              fi
            }

            case "''${1:-status}" in
              on)
                mkdir -p "$state_dir"
                touch "$flag"
                status
                ;;
              off)
                rm -f "$flag"
                status
                ;;
              status) status ;;
              hook) route ;;
              *)
                echo "usage: /jev on | off | status" >&2
                exit 1
                ;;
            esac
          '';
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
        package = pkgs-unstable.claude-code;

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
            !`${lib.getExe jevRouter} $ARGUMENTS`
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
