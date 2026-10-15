{ ... }:
{
  perSystem =
    { pkgs-unstable, ... }:
    {
      packages.opencode = pkgs-unstable.opencode;
    };

  flake.homeModules.opencode =
    {
      config,
      osConfig,
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
        export GIT_SSH_COMMAND="${lib.getExe pkgs.openssh} -o ConnectTimeout=3 -o BatchMode=yes"
        exec bash "$@"
      '';

      mcpServers = [
        "codebase_memory"
        "context7"
        "gh_grep"
        "gitlab"
        "rag"
        "searxng"
        "typst"
        "uc-dev"
        "youtrack"
      ];

      thinkingVariants = {
        off.chat_template_kwargs.enable_thinking = false;
        low.chat_template_kwargs = {
          enable_thinking = true;
          reasoning_effort = "low";
        };
        medium.chat_template_kwargs = {
          enable_thinking = true;
          reasoning_effort = "medium";
        };
        xhigh.chat_template_kwargs = {
          enable_thinking = true;
          reasoning_effort = "xhigh";
        };
      };

      # --- Pre-seed: only Nix-specific overrides on top of repo config ---
      # merge_config.py does deep_merge(repo_template, existing) where the repo
      # template wins on scalars; only keys it does not define survive from here.
      nixPreseedConfig = {
        "$schema" = "https://opencode.ai/config.json";
        share = "disabled";
        default_agent = "build";

        provider = {
          Protei.models.Coding.variants = thinkingVariants;
          Protei.models.Strict.variants = thinkingVariants;

          Protei.models.Small = {
            name = "Protei Small";
            id = "agent_proteya_slow";
            description = "Быстрая модель для мелких задач (заголовки, саммари)";
            status = "active";
            tool_call = true;
            attachment = true;
            reasoning = true;
            temperature = true;
            limit = {
              context = 131072;
              output = 8192;
            };
            modalities = {
              input = [
                "text"
                "image"
              ];
              output = [ "text" ];
            };
            options = {
              temperature = 1.0;
              topP = 0.95;
              topK = 20;
              minP = 0.0;
              presencePenalty = 0.0;
              repetitionPenalty = 1.0;
            };
            variants = thinkingVariants;
          };

          llamaCpp = {
            npm = "@ai-sdk/openai-compatible";
            name = "Local llama.cpp";
            options = {
              baseURL = "http://localhost:8085/v1";
              apiKey = "local";
            };
            models = {
              "ornith-ai/Ornith-1.5-35B-A3B" = {
                name = "Ornith 1.5 35B A3B";
                description = "Локальная модель для offline-кодинга";
                tool_call = true;
                reasoning = true;
                limit = {
                  context = 65536;
                  output = 8192;
                };
                options = {
                  temperature = 0.6;
                  topP = 0.95;
                  topK = 20;
                };
                variants = {
                  off.chat_template_kwargs.enable_thinking = false;
                  low.chat_template_kwargs = {
                    enable_thinking = true;
                    reasoning_effort = "low";
                  };
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
          codebase_memory = {
            type = "local";
            command = [
              "npx"
              "-y"
              "codebase-memory-mcp"
            ];
            environment.CBM_ALLOWED_ROOT = config.home.homeDirectory;
            enabled = true;
          };
          searxng = {
            type = "local";
            command = [
              "npx"
              "-y"
              "mcp-searxng"
            ];
            environment.SEARXNG_URL = "http://127.0.0.1:${toString osConfig.services.searx.settings.server.port}";
            enabled = true;
          };
          typst = {
            type = "local";
            command = [
              "docker"
              "run"
              "--rm"
              "-i"
              "ghcr.io/johannesbrandenburger/typst-mcp:latest"
            ];
            enabled = true;
          };
          uc-dev = {
            type = "local";
            command = [
              "uc-dev"
              "mcp"
            ];
            environment.UC_DEV_CORE = "${config.home.homeDirectory}/Work/core";
            enabled = true;
          };
        };

        # plugin is LIST_UNION_KEY: repo ["opencode-auto-resume"] + ours = union
        plugin = [
          "opencode-claude-auth@latest"
          "@cortexkit/aft-opencode@${config.programs.harness.aftVersion}"
        ];
      };

      nixPreseedJsonFile = pkgs.writeText "opencode-preseed.json" (builtins.toJSON nixPreseedConfig);

      # --- .env template for llm-toolkit (rendered by sops-nix at activation) ---
      # sops.templates substitutes config.sops.placeholder."key" with actual secret values.
      # Result is available as config.sops.templates."llm-toolkit-env".path
    in
    {
      config = {

        home.packages = [
          pkgs-unstable.opencode-desktop
        ];

        home.sessionVariables.ORT_DYLIB_PATH = "${pkgs.onnxruntime}/lib/libonnxruntime.so";

        programs.opencode = {
          enable = true;
          package = pkgs-unstable.opencode;

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
          export GIT_SSH_COMMAND="${lib.getExe pkgs.openssh} -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"
          export GIT_TERMINAL_PROMPT=0

          toolkit_available="0"

          if [[ ! -d "$toolkit_dir/.git" ]]; then
            log "Cloning llm-toolkit to $toolkit_dir"
            if "${pkgs.coreutils}/bin/timeout" 30s "${lib.getExe pkgs.git}" clone "${toolkitRepoUrl}" "$toolkit_dir" 2>/dev/null; then
              toolkit_available="1"
            else
              log "WARNING: git clone failed (no network/auth?). Skipping toolkit update."
            fi
          else
            log "Updating llm-toolkit"
            if "${pkgs.coreutils}/bin/timeout" 20s "${lib.getExe pkgs.git}" -C "$toolkit_dir" pull --rebase 2>/dev/null; then
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
          # merge_config.py will deep_merge(repo_template, this); the template wins
          # on conflicts, so anything it defines is forced back in the jq step below
          # --reflink=never avoids btrfs reflink to ro nix store which blocks writes
          cp --reflink=never "${nixPreseedJsonFile}" "$opencode_dir/opencode.json"
          log "Pre-seeded opencode.json with Nix overrides"

          # Run install.sh via wrapper (UV env + PATH baked into nix store binary)
          if [[ "$toolkit_available" == "1" ]]; then
            log "Running install.sh"
            rm -rf "$toolkit_dir/.venv"
            "${lib.getExe pkgs.uv}" venv --python "${pkgs.python3}/bin/python3" "$toolkit_dir/.venv"
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

          # Post-process values the repo template owns, so pre-seeding cannot win:
          #   - enabled_providers: repo restricts to ["Protei"]
          #   - variants.high: Qwen3.8-27B's chat template raises on any
          #     reasoning_effort outside (low, medium, xhigh)
          #   - Coding/Strict context: repo ships 131072 and 231072, the model is
          #     natively 262144
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            "${lib.getExe pkgs.jq}" \
              'del(.enabled_providers)
               | .model = "opencode/longcat-2.5-preview-free"
               | .small_model = "opencode/longcat-2.5-preview-free"
               | del(.mcp.logzone)
               | del(.provider.Protei.models[]?.variants.high)
               | .provider.Protei.models.Coding.limit = { context: 262144, output: 65536 }
               | .provider.Protei.models.Strict.limit.context = 262144' \
              "$opencode_dir/opencode.json" \
              > "$opencode_dir/opencode.json.tmp" && \
              mv "$opencode_dir/opencode.json.tmp" "$opencode_dir/opencode.json"
            log "Applied Nix overrides on top of repo template"
          fi

          # Mirror opencode.json -> config.json (OpenCode reads both)
          if [[ -f "$opencode_dir/opencode.json" ]]; then
            ln -sf "$opencode_dir/opencode.json" "$opencode_dir/config.json"
          fi

          if [[ ! -d "${config.xdg.cacheHome}/opencode/packages/@cortexkit/aft-opencode@${config.programs.harness.aftVersion}" ]]; then
            log "Warming up @cortexkit/aft-opencode plugin cache (first-run bun install is slow and can hang a live TUI session)"
            if ! "${pkgs.coreutils}/bin/timeout" 240s "${pkgs-unstable.opencode}/bin/opencode" run "warm up plugin cache" >/dev/null 2>&1; then
              log "WARNING: aft-opencode plugin warm-up failed or timed out (no network / provider unreachable?)"
            fi
          fi

          log "opencode setup complete"
        '';
      };
    };
}
