{ ... }:
let
  mkNvimHandoff =
    pkgs: opencode:
    let
      handoff =
        pkgs.writeShellScriptBin "opencode-nvim-handoff" # bash
          ''
            set -eu

            if [ -n "''${NVIM-}" ]; then
              echo "opencode уже запущен внутри Neovim — используй <leader>at, а не /nvim."
              exit 0
            fi

            if [ -z "''${OPENCODE_NVIM_HANDOFF-}" ] || [ -z "''${OPENCODE_NVIM_SERVER-}" ]; then
              echo "Передача сессии недоступна: opencode запущен не через обёртку из dotfiles."
              exit 0
            fi

            : > "$OPENCODE_NVIM_HANDOFF"
            set -f
            # shellcheck disable=SC2086
            set -- ''${1-}
            set +f
            for arg in "$@"; do
              printf '%s\n' "''${arg#@}" >> "$OPENCODE_NVIM_HANDOFF"
            done

            ${pkgs.curl}/bin/curl -sS -m 5 -X POST \
              -H 'Content-Type: application/json' \
              -d '{"type":"tui.command.execute","properties":{"command":"app.exit"}}' \
              "$OPENCODE_NVIM_SERVER/tui/publish" > /dev/null

            sleep 30
            rm -f "$OPENCODE_NVIM_HANDOFF"
            echo "Не удалось закрыть TUI opencode — передача сессии в Neovim отменена."
          '';

      subcommands =
        pkgs.runCommand "opencode-subcommands" { } # bash
          ''
            export HOME="$TMPDIR"
            ${opencode}/bin/opencode --help 2>&1 \
              | sed -e 's/\x1b\[[0-9;]*m//g' \
              | awk '
                  /^Commands:/ { block = 1; next }
                  block && (/^$/ || /^[^[:space:]]/) { block = 0 }
                  block && $1 == "opencode" && $2 !~ /^[[<]/ { print $2 }
                  block && match($0, /\[aliases: [^]]+\]/) {
                    list = substr($0, RSTART + 10, RLENGTH - 11)
                    n = split(list, parts, /, */)
                    for (i = 1; i <= n; i++) print parts[i]
                  }
                ' \
              | sort -u > "$out"

            found=$(wc -l < "$out")
            if [ "$found" -lt 5 ]; then
              echo "opencode --help: разобрано только $found подкоманд — формат вывода изменился" >&2
              exit 1
            fi
          '';

      launcher =
        pkgs.writeShellScriptBin "opencode" # bash
          ''
            set -u

            real="${opencode}/bin/opencode"

            if [ -n "''${1-}" ]; then
              while read -r subcommand; do
                [ "$1" = "$subcommand" ] && exec "$real" "$@"
              done < ${subcommands}
            fi

            port=""
            prev=""
            for arg in "$@"; do
              case "$arg" in
                --port=*) port="''${arg#--port=}" ;;
              esac
              [ "$prev" = "--port" ] && port="$arg"
              prev="$arg"
            done

            args=("$@")
            if [ -z "$port" ]; then
              for _ in $(seq 1 64); do
                candidate=$((30000 + RANDOM % 20000))
                if ! (exec 3<>/dev/tcp/127.0.0.1/"$candidate") 2> /dev/null; then
                  port="$candidate"
                  break
                fi
                exec 3>&- 2> /dev/null || true
              done
              [ -n "$port" ] && args=(--port "$port" "$@")
            fi

            case "$port" in
              "" | *[!0-9]*) port="" ;;
            esac

            if [ -n "$port" ]; then
              export OPENCODE_NVIM_SERVER="http://127.0.0.1:$port"
              if [ -z "''${NVIM-}" ]; then
                OPENCODE_NVIM_HANDOFF="''${XDG_RUNTIME_DIR:-/tmp}/opencode-nvim-handoff.$$"
                export OPENCODE_NVIM_HANDOFF
                rm -f "$OPENCODE_NVIM_HANDOFF"
              fi
            fi

            "$real" "''${args[@]}"
            status=$?

            state="''${OPENCODE_NVIM_HANDOFF-}"
            if [ -n "$state" ] && [ -e "$state" ]; then
              mapfile -t files < "$state"
              rm -f "$state"
              unset OPENCODE_NVIM_HANDOFF OPENCODE_NVIM_SERVER
              if ! command -v nvim > /dev/null; then
                echo "opencode: nvim не найден в PATH, передача сессии невозможна." >&2
                exit 1
              fi
              export OPENCODE_NVIM_RESUME=1
              exec nvim "''${files[@]}"
            fi

            exit $status
          '';

      wrapped = pkgs.symlinkJoin {
        name = "opencode-nvim-${opencode.version}";
        inherit (opencode) meta version;
        paths = [ opencode ];
        postBuild = ''
          rm -f "$out/bin/opencode"
          ln -s ${launcher}/bin/opencode "$out/bin/opencode"
        '';
      };
    in
    {
      inherit handoff wrapped;
    };
in
{
  perSystem =
    { pkgs, pkgs-unstable, ... }:
    {
      packages.opencode = (mkNvimHandoff pkgs pkgs-unstable.opencode).wrapped;
    };

  flake.homeModules.opencode =
    {
      config,
      inputs ? null,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:

    let
      inherit (lib)
        mkAfter
        ;

      nvimHandoff = mkNvimHandoff pkgs pkgs-unstable.opencode;

      opencodeConfigDir = "${config.xdg.configHome}/opencode";
      toolkitRepoUrl = "https://git.protei.ru/qa-stuff/llm/llm-toolkit.git";
      toolkitDir = "${config.home.homeDirectory}/Work/llm-toolkit";

      # --- Wrapper: sets UV env + PATH so install.sh's `uv run` works on NixOS ---
      # Per nixpkgs uv docs: UV_PYTHON + UV_PYTHON_DOWNLOADS=never + LD_LIBRARY_PATH
      installWrapper = pkgs.writeShellScriptBin "run-install" /* bash */ ''
        export PATH="${pkgs.uv}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.diffutils}/bin:${pkgs.gzip}/bin:${pkgs.gawk}/bin:${pkgs.openssh}/bin:$PATH"
        export UV_PYTHON=${pkgs.python3}/bin/python3
        export UV_PYTHON_DOWNLOADS=never
        export UV_NO_SYNC=1
        export UV_NO_CONFIG=1
        export UV_HTTP_TIMEOUT=5
        export LD_LIBRARY_PATH="${
          pkgs.lib.makeLibraryPath [
            pkgs.openssl
            pkgs.zlib
            pkgs.curl
            pkgs.stdenv.cc.cc
          ]
        }"
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o ConnectTimeout=3 -o BatchMode=yes"
        exec bash "$@"
      '';

      # --- Pre-seed: only Nix-specific overrides on top of repo config ---
      # merge_config.py does deep_merge(repo_template, existing) where existing wins.
      nixPreseedConfig = {
        "$schema" = "https://opencode.ai/config.json";
        share = "disabled";

        provider = {
          llamaCpp = {
            npm = "@ai-sdk/openai-compatible";
            name = "Local llama.cpp";
            options = {
              baseURL = "http://localhost:8085/v1";
              apiKey = "local";
            };
            models = {
              "qwen3.5-4b-mtp" = {
                name = "Qwen3.5-4B MTP";
                description = "Локальная модель для offline-кодинга";
                limit = {
                  context = 16384;
                  output = 8192;
                };
                options = {
                  temperature = 0.6;
                  topP = 0.95;
                  topK = 20;
                  minP = 0.0;
                  presencePenalty = 0.0;
                  repetitionPenalty = 1.0;
                };
              };
            };
          };
        };

        mcp = {
          context7 = {
            type = "remote";
            url = "https://mcp.context7.com/mcp";
            enabled = true;
          };
          gh_grep = {
            type = "remote";
            url = "https://mcp.grep.app";
            enabled = true;
          };
          searxng = {
            type = "local";
            command = [
              "npx"
              "-y"
              "mcp-searxng"
            ];
            environment.SEARXNG_URL = "http://127.0.0.1:8899";
            enabled = true;
          };
        };

        # plugin is LIST_UNION_KEY: repo ["opencode-auto-resume"] + ours = union
        plugin = [ "opencode-claude-auth@latest" ];
      };

      nixPreseedJsonFile = pkgs.writeText "opencode-preseed.json" (builtins.toJSON nixPreseedConfig);

      # --- .env template for llm-toolkit (rendered by sops-nix at activation) ---
      # sops.templates substitutes config.sops.placeholder."key" with actual secret values.
      # Result is available as config.sops.templates."llm-toolkit-env".path
    in
    {
      config = {

        home.packages = [
          pkgs.opencode-desktop
        ];

        programs.opencode = {
          enable = true;
          package = nvimHandoff.wrapped;

          commands.nvim = /* markdown */ ''
            ---
            description: Закрыть TUI opencode и продолжить текущую сессию в Neovim (opencode.nvim). Аргументы — файлы, которые нужно открыть
            ---

            !`${nvimHandoff.handoff}/bin/opencode-nvim-handoff "$ARGUMENTS"`
          '';

          # Skills и agents через нативный HM-модуль (xdg.configFile).
          # Порядок применения:
          #   1) Pre-seed — opencode.json из Nix (nixPreseedConfig)
          #   2) HM xdg.configFile → декларативные skills/agents из Nix
          #   3) home.activation (mkAfter) → install.sh из llm-toolkit (перезаписывает)
          #   4) Ручное создание файлов в ~/.config/opencode/skills/ или agents/
          #
          # Конфликты: если skill/agent с тем же именем существует в нескольких
          # источниках, приоритет — от последнего к первому (ручной > toolkit > Nix).
          #
          # Вариации декларативных skills:
          #   # Inline текст → opencode/skills/<name>/SKILL.md
          #   nix-review-checklist = "# Чек-лист...";
          #
          #   # Путь к файлу → opencode/skills/<name>/SKILL.md
          #   some-skill = ./path/to/SKILL.md;
          #
          #   # Путь к директории → opencode/skills/<name>/ (рекурсивно, все файлы)
          #   data-analysis = ./skills/data-analysis;
          #
          #   # Store path (строка) → работает аналогично
          #   beads = "${pkgs.beads.src}/claude-plugin/skills/beads";
          skills = {
            nix-review-checklist = /* markdown */ ''
              # Чек\u2011лист ревью Nix

              Быстрый чек\u2011лист для самопроверки перед PR/rebuild.

              ## Шаги

              1. Проверить, что новые `.nix` файлы добавлены в git (иначе `import-tree` их не увидит)
              2. Проверить Linux-only условия: использовать `system` + `builtins.elem`, не `pkgs.stdenv.isLinux` в `perSystem`
              3. Убедиться, что секреты не попали в nix store (только `sops.placeholder`/`sops.templates`)
              4. Прогнать форматирование: `nixfmt-rfc-style nixos/` (или `nixfmt`)
              5. Собрать без применения: `sudo nixos-rebuild build --flake ~/dotfiles/nixos`

              ## Результат

              Верни список найденных рисков и конкретные действия для исправления.
            '';
          };
          agents = {
            nix-code-reviewer = /* markdown */ ''
              # Ревьюер Nix-конфигураций

              Специалист по ревью Nix/NixOS/Home Manager.

              ## Что делать

              - Проверять корректность модульной структуры (flake-parts, опции, импорты)
              - Искать типовые ошибки: рекурсия `pkgs`/`perSystem`, неверные пути, опечатки в опциях
              - Упрощать выражения, избегать лишнего рефакторинга
              - Подсказывать, где лучше использовать `mkIf/mkDefault/mkForce`

              ## Формат ответа

              - Сначала краткий вывод (1\u20133 пункта)
              - Затем конкретные правки (с командами/фрагментами)
              - Не предлагать изменения вне запроса
            '';
          };
        };

        # Sops template: renders .env with secret values substituted at activation
        sops.templates."llm-toolkit-env" = {
          content = /* bash */ ''
            # Agent token from chat.protei.ru
            PROTEI_AGENT_TOKEN=${config.sops.placeholder."work_ai/litellm_api_key"}

            # YouTrack token for MCP
            YOUTRACK_TOKEN=${config.sops.placeholder."youtrack/token"}

            # LightRAG MCP settings
            LIGHTRAG_BASE_URL=${config.sops.placeholder."work_ai/lightrag_url"}

            # GitLab MCP token
            GITLAB_TOKEN=${config.sops.placeholder."git/gitlab_mcp_token"}

            # SFTP MCP (Logzone) credentials
            SFTP_USERNAME=
            SFTP_PASSWORD=
          '';
        };

        home.activation.setupOpencodeToolkit = mkAfter /* bash */ ''
          set -euo pipefail

          toolkit_dir="${toolkitDir}"
          opencode_dir="${opencodeConfigDir}"

          log() { printf '[opencode] %s\n' "$*" >&2; }

          # Clone / pull llm-toolkit (skip on network failure)
          export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"
          export GIT_TERMINAL_PROMPT=0

          toolkit_available="0"

          if [[ ! -d "$toolkit_dir/.git" ]]; then
            log "Cloning llm-toolkit to $toolkit_dir"
            if "${pkgs.coreutils}/bin/timeout" 30s "${pkgs.git}/bin/git" clone "${toolkitRepoUrl}" "$toolkit_dir" 2>/dev/null; then
              toolkit_available="1"
            else
              log "WARNING: git clone failed (no network/auth?). Skipping toolkit update."
            fi
          else
            log "Updating llm-toolkit"
            if "${pkgs.coreutils}/bin/timeout" 20s "${pkgs.git}/bin/git" -C "$toolkit_dir" pull --rebase 2>/dev/null; then
              toolkit_available="1"
            else
              log "WARNING: git pull failed. Using existing checkout."
              toolkit_available="1"
            fi
          fi

          sops_env="${config.sops.templates."llm-toolkit-env".path}"
          if [[ "$toolkit_available" == "1" ]] && [[ -f "$sops_env" ]]; then
            cp --reflink=never "$sops_env" "$toolkit_dir/.env"
            chmod 600 "$toolkit_dir/.env"
            log ".env deployed (sops-rendered)"
          fi

          # Ensure config directory exists
          mkdir -p "$opencode_dir"

          # Pre-seed opencode.json with Nix custom overrides
          # merge_config.py will deep_merge(repo_template, this) where this wins
          # --reflink=never avoids btrfs reflink to ro nix store which blocks writes
          cp --reflink=never "${nixPreseedJsonFile}" "$opencode_dir/opencode.json"
          log "Pre-seeded opencode.json with Nix overrides"

          # Run install.sh via wrapper (UV env + PATH baked into nix store binary)
          if [[ "$toolkit_available" == "1" ]]; then
            log "Running install.sh"
            rm -rf "$toolkit_dir/.venv"
            "${pkgs.uv}/bin/uv" venv --python "${pkgs.python3}/bin/python3" "$toolkit_dir/.venv"
            install_log="$toolkit_dir/.install.log"
            if "${installWrapper}/bin/run-install" "$toolkit_dir/scripts/install.sh" >"$install_log" 2>&1; then
              log "install.sh succeeded"
            else
              log "WARNING: install.sh failed (exit $?), see $install_log"
              while IFS= read -r line; do log "  $line"; done < "$install_log"
            fi
          else
            log "Skipping install (no toolkit available)"
          fi

          # Post-process: remove enabled_providers (repo restricts to ["Protei"])
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            "${pkgs.jq}/bin/jq" 'del(.enabled_providers)' "$opencode_dir/opencode.json" \
              > "$opencode_dir/opencode.json.tmp" && \
              mv "$opencode_dir/opencode.json.tmp" "$opencode_dir/opencode.json"
            log "Removed enabled_providers restriction"
          fi

          # Mirror opencode.json -> config.json (OpenCode reads both)
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            ln -sf "$opencode_dir/opencode.json" "$opencode_dir/config.json"
          fi

          log "opencode setup complete"
        '';
      };
    };
}
