{ ... }:
{
  flake.homeModules.claude =
    {
      config,
      osConfig,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
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

      appendSystemFile = pkgs.writeText "claude-append-system.md" config.programs.harness.appendShared;

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
      programs.zsh.initContent = lib.mkOrder 2000 ''
        export _ZO_DOCTOR=0
        # снапшот шелла Claude Code снимается без CLAUDECODE, но и без терминала
        if [[ -n $CLAUDECODE || ! -t 0 ]]; then
          unalias cp mv mkdir cat ls 2>/dev/null
          unfunction cd 2>/dev/null
        fi
      '';

      programs.claude-code = {
        enable = true;
        package = claudeCode;

        plugins = [ jevPlugin ];

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

        lspServers = {
          gopls = {
            command = lib.getExe pkgs.gopls;
            extensionToLanguage.".go" = "go";
          };
          nixd = {
            command = lib.getExe pkgs.nixd;
            extensionToLanguage.".nix" = "nix";
          };
          typescript = {
            command = lib.getExe pkgs.typescript-language-server;
            args = [ "--stdio" ];
            extensionToLanguage = {
              ".ts" = "typescript";
              ".tsx" = "typescriptreact";
              ".js" = "javascript";
              ".jsx" = "javascriptreact";
            };
          };
          rust-analyzer = {
            command = lib.getExe pkgs.rust-analyzer;
            extensionToLanguage.".rs" = "rust";
          };
          pyright = {
            command = lib.getExe' pkgs.pyright "pyright-langserver";
            args = [ "--stdio" ];
            extensionToLanguage.".py" = "python";
          };
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
          huggingface = {
            type = "http";
            url = "https://huggingface.co/mcp?login";
          };
          codebase_memory = {
            type = "stdio";
            command = lib.getExe config.programs.harness.codebaseMemory;
            args = config.programs.harness.codebaseMemoryArgs;
            env.CBM_ALLOWED_ROOT = config.home.homeDirectory;
          };
          nixos = {
            type = "stdio";
            command = lib.getExe config.programs.harness.mcpNixos;
            args = [ ];
          };
          searxng = {
            type = "stdio";
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:${toString osConfig.services.searx.settings.server.port}";
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
