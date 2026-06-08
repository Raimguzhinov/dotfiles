{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.opencode = pkgs.opencode;
    };

  flake.homeModules.opencode =
    {
      config,
      inputs ? null,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        mkAfter
        ;

      opencodeConfigDir = "${config.xdg.configHome}/opencode";
      toolkitRepoUrl = "https://git.protei.ru/qa-stuff/llm/llm-toolkit.git";
      toolkitDir = "${config.home.homeDirectory}/Work/llm-toolkit";

      claudeForMeridian = "${pkgs.claude-code}/bin/claude";

      # --- Meridian patch (duplicate ESM export in 1.42.1) ---
      meridianPkgPatched =
        if inputs != null && inputs ? meridian then
          inputs.meridian.packages.${pkgs.system}.meridian.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

            postInstall = (old.postInstall or "") + ''
              for f in "$out"/lib/meridian/dist/tokenRefresh-*.js; do
                if [ -f "$f" ]; then
                  substituteInPlace "$f" \
                    --replace-fail \
                    'export { withClaudeLogContext, claudeLog, createPlatformCredentialStore, refreshOAuthToken, ensureFreshToken, startBackgroundRefresh, stopBackgroundRefresh };' \
                    'export { withClaudeLogContext, claudeLog };'
                fi
              done
            '';

            postFixup = (old.postFixup or "") + ''
              wrapProgram "$out/bin/meridian" \
                --set MERIDIAN_CLAUDE_PATH "${claudeForMeridian}"
            '';
          })
        else
          null;

      # --- Wrapper: sets UV env + PATH so install.sh's `uv run` works on NixOS ---
      # Per nixpkgs uv docs: UV_PYTHON + UV_PYTHON_DOWNLOADS=never + LD_LIBRARY_PATH
      installWrapper = pkgs.writeShellScriptBin "run-install" ''
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
          anthropic = {
            options = {
              baseURL = "http://127.0.0.1:3456/v1";
              apiKey = "x";
            };
          };

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
        };

        # plugin is LIST_UNION_KEY: repo ["opencode-auto-resume"] + ours = union
        plugin = [
          config.services.meridian.opencode.pluginPath
        ];
      };

      nixPreseedJsonFile = pkgs.writeText "opencode-preseed.json" (builtins.toJSON nixPreseedConfig);

      # --- .env template for llm-toolkit (rendered by sops-nix at activation) ---
      # sops.templates substitutes config.sops.placeholder."key" with actual secret values.
      # Result is available as config.sops.templates."llm-toolkit-env".path
    in
    {
      config = {
        programs.opencode = {
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
            nix-review-checklist = ''
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
            nix-code-reviewer = ''
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
        services.meridian = {
          enable = true;
          settings = {
            port = 3456;
            host = "127.0.0.1";
          };
          environment = {
            MERIDIAN_CLAUDE_PATH = claudeForMeridian;
          };
        }
        // lib.optionalAttrs (meridianPkgPatched != null) {
          package = meridianPkgPatched;
        };

        programs.opencode.enable = true;

        # Sops template: renders .env with secret values substituted at activation
        sops.templates."llm-toolkit-env" = {
          content = ''
            # Agent token from chat.protei.ru
            PROTEI_AGENT_TOKEN=${config.sops.placeholder."work_ai/litellm_api_key"}

            # YouTrack token for MCP
            YOUTRACK_TOKEN=${config.sops.placeholder."youtrack/token"}

            # LightRAG MCP settings
            LIGHTRAG_BASE_URL=http://localhost:9621

            # GitLab MCP token
            GITLAB_TOKEN=${config.sops.placeholder."git/gitlab_mcp_token"}

            # SFTP MCP (Logzone) credentials
            SFTP_USERNAME=
            SFTP_PASSWORD=
          '';
        };

        home.activation.setupOpencodeToolkit = mkAfter ''
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

          # Copy sops-rendered .env (sops-nix already substituted placeholders)
          if [[ "$toolkit_available" == "1" ]]; then
            cp --reflink=never "${config.sops.templates."llm-toolkit-env".path}" "$toolkit_dir/.env"
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

          # Post-process: remove enabled_providers (repo restricts to ["protei"])
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            "${pkgs.jq}/bin/jq" 'del(.enabled_providers)' "$opencode_dir/opencode.json" \
              > "$opencode_dir/opencode.json.tmp" && \
              mv "$opencode_dir/opencode.json.tmp" "$opencode_dir/opencode.json"
            log "Removed enabled_providers restriction"
          fi

          # Mirror opencode.json -> config.json (OpenCode reads both)
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            cp --reflink=never "$opencode_dir/opencode.json" "$opencode_dir/config.json"
          fi

          log "opencode setup complete"
        '';
      };
    };
}
