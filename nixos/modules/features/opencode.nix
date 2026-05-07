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
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        mkForce
        mkOption
        types
        ;

      cfg = config.programs.opencode;

      opencodeConfigDir = "${config.xdg.configHome}/opencode";
      toolkitRepoUrl = "ssh://git@git.protei.ru/qa-stuff/llm-toolkit.git";

      opencodeSettings = {
        provider = {
          protei = {
            npm = "@ai-sdk/openai-compatible";
            name = "Protei";
            options = {
              baseURL = "${config.sops.placeholder."work_ai/litellm_url"}/api";
              apiKey = config.sops.placeholder."work_ai/litellm_api_key";
            };
            models = {
              "Qwen/Qwen3.5-122B-A10B-FP8" = {
                name = "Qwen3.5-122b";
                limit = {
                  context = 262144;
                  output = 8192;
                };
              };
              "ПротеЯ-2" = {
                name = "ПротеЯ-2";
                limit = {
                  context = 262144;
                  output = 8192;
                };
              };
            };
          };
          llamaCpp = {
            npm = "@ai-sdk/openai-compatible";
            name = "Local llama.cpp";
            options = {
              baseURL = "http://127.0.0.1:8085/v1";
              apiKey = "local"; # OpenCode ожидает поле, но сам ключ не требуется
            };
            models = {
              "qwen2.5-coder-1.5b-instruct" = {
                name = "Qwen2.5 Coder 1.5B";
              };
            };
          };
        };

        model = "opencode-go/deepseek-v4-pro";
        small_model = "opencode/big-pickle";

        mcp = {
          youtrack = {
            type = "remote";
            url = config.sops.placeholder."work_ai/mcp_sse_url";
            enabled = true;
            headers = {
              youtrack_token = config.sops.placeholder."youtrack/token";
            };
          };
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

        permission = {
          read = {
            "~/.config/opencode/*" = "allow";
          };
          external_directory = {
            "~/.config/opencode/*" = "allow";
          };
        };
      };

      opencodeConfigRawJson = builtins.toJSON (
        {
          "$schema" = "https://opencode.ai/config.json";
        }
        // opencodeSettings
      );

      opencodeConfigRawJsonFile = pkgs.writeText "opencode-config-raw.json" opencodeConfigRawJson;

      opencodeConfigPrettyJsonFile =
        pkgs.runCommand "opencode-config.json" { nativeBuildInputs = [ pkgs.jq ]; }
          ''
            ${pkgs.jq}/bin/jq -S . < ${opencodeConfigRawJsonFile} > $out
          '';

      opencodeConfigJson = builtins.readFile opencodeConfigPrettyJsonFile;
    in
    {
      # Home Manager module (pinned in this flake) already provides
      # `programs.opencode.agents`, but does not provide `programs.opencode.skills`.
      options.programs.opencode.skills = mkOption {
        type = types.attrsOf (types.either types.lines types.path);
        default = { };
        description = ''
          Custom skills for opencode.

          The attribute name becomes the skill directory name, and the value is either:
          - Inline content as a string
          - A path to a file containing the skill content

          Each skill is written to {file}`$XDG_CONFIG_HOME/opencode/skills/<name>/SKILL.md`.
        '';
      };

      config = {
        programs.opencode = {
          enable = true;
          package = pkgs.opencode;
          enableMcpIntegration = true;
          settings = opencodeSettings;

          # Личные inline-примеры (живут в Nix, не в репозитории llm-toolkit)
          agents."nix-code-reviewer" = lib.mkDefault ''
            # Ревьюер Nix-конфигураций

            Специалист по ревью Nix/NixOS/Home Manager.

            ## Что делать

            - Проверять корректность модульной структуры (flake-parts, опции, импорты)
            - Искать типовые ошибки: рекурсия `pkgs`/`perSystem`, неверные пути, опечатки в опциях
            - Упрощать выражения, избегать лишнего рефакторинга
            - Подсказывать, где лучше использовать `mkIf/mkDefault/mkForce`

            ## Формат ответа

            - Сначала краткий вывод (1–3 пункта)
            - Затем конкретные правки (с командами/фрагментами)
            - Не предлагать изменения вне запроса
          '';

          skills."nix-review-checklist" = lib.mkDefault ''
            # Чек‑лист ревью Nix

            Быстрый чек‑лист для самопроверки перед PR/rebuild.

            ## Шаги

            1. Проверить, что новые `.nix` файлы добавлены в git (иначе `import-tree` их не увидит)
            2. Проверить Linux-only условия: использовать `system` + `builtins.elem`, не `pkgs.stdenv.isLinux` в `perSystem`
            3. Убедиться, что секреты не попали в nix store (только `sops.placeholder`/`sops.templates`)
            4. Прогнать форматирование: `nixfmt-rfc-style nixos/` (или `nixfmt`)
            5. Собрать без применения: `sudo nixos-rebuild build --flake ~/dotfiles/nixos`

            ## Результат

            Верни список найденных рисков и конкретные действия для исправления.
          '';

          # How to override inline:
          # - `agents.<name>` becomes `~/.config/opencode/agent/<name>.md`
          # - `skills.<name>` becomes `~/.config/opencode/skills/<name>/SKILL.md`
        };

        sops.templates."opencode-config.json" = {
          content = opencodeConfigJson;
          mode = "0400";
        };

        home.activation.ensureOpencodeToolkit = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          opencode_cfg_dir="${opencodeConfigDir}"
          git_bin="${pkgs.git}/bin/git"
          timeout_bin="${pkgs.coreutils}/bin/timeout"
          date_bin="${pkgs.coreutils}/bin/date"

          log_file="$opencode_cfg_dir/.hm-opencode.log"
          log() {
            mkdir -p "$opencode_cfg_dir"
            printf '[%s] %s\n' "$($date_bin -Is)" "$1" >>"$log_file" 2>/dev/null || true
          }

          mkdir -p "$opencode_cfg_dir"

          log "start: ensureOpencodeToolkit"

          ssh_bin="${pkgs.openssh}/bin/ssh"
          export GIT_SSH_COMMAND="$ssh_bin -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

          fetch_origin() {
            # Writes fetch output to log, returns git exit code
            GIT_TERMINAL_PROMPT=0 "$timeout_bin" 20s "$git_bin" -C "$opencode_cfg_dir" fetch origin --depth=1 2>>"$log_file"
          }

          pull_origin() {
            # Writes pull output to log, returns git exit code
            GIT_TERMINAL_PROMPT=0 "$timeout_bin" 10s "$git_bin" -C "$opencode_cfg_dir" pull --rebase 2>>"$log_file"
          }

          ensure_origin() {
            local desired_url="$1"
            origin_url="$($git_bin -C "$opencode_cfg_dir" remote get-url origin 2>/dev/null || true)"

            if [[ -z "$origin_url" ]]; then
              log "set origin=$desired_url"
              "$git_bin" -C "$opencode_cfg_dir" remote add origin "$desired_url" >/dev/null 2>&1 || true
              return
            fi

            if [[ "$origin_url" != "$desired_url" ]]; then
              log "rewrite origin: $origin_url -> $desired_url"
              "$git_bin" -C "$opencode_cfg_dir" remote set-url origin "$desired_url" >/dev/null 2>&1 || true
              return
            fi

            log "origin ok: $origin_url"
          }

          # Ensure repo exists
          if [[ ! -d "$opencode_cfg_dir/.git" ]]; then
            echo "opencode: bootstrapping llm-toolkit in $opencode_cfg_dir" >&2
            log "init repo"
            GIT_TERMINAL_PROMPT=0 "$git_bin" -C "$opencode_cfg_dir" init || true
          fi

          if [[ -d "$opencode_cfg_dir/.git" ]]; then
            ensure_origin "${toolkitRepoUrl}"

            get_remote_head() {
              head_ref="$($git_bin -C "$opencode_cfg_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
              if [[ -n "$head_ref" ]]; then
                echo "$head_ref"
                return
              fi
              if "$git_bin" -C "$opencode_cfg_dir" show-ref --verify --quiet refs/remotes/origin/main; then
                echo "origin/main"
                return
              fi
              if "$git_bin" -C "$opencode_cfg_dir" show-ref --verify --quiet refs/remotes/origin/master; then
                echo "origin/master"
                return
              fi
              echo ""
            }

            # If repo has no commits yet, fetch+checkout.
            if ! "$git_bin" -C "$opencode_cfg_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
              log "no HEAD: fetching"

              fetched="0"
              if fetch_origin; then
                log "fetch ok"
                fetched="1"
              else
                echo "opencode: llm-toolkit fetch failed (no network/auth?)" >&2
                log "fetch failed"
              fi

              if [[ "$fetched" == "1" ]]; then
                remote_head="$(get_remote_head)"
                if [[ -n "$remote_head" ]]; then
                  log "checkout main from $remote_head"
                  "$git_bin" -C "$opencode_cfg_dir" checkout -B main "$remote_head" >/dev/null 2>&1 || true
                else
                  echo "opencode: llm-toolkit fetch succeeded but remote head not found" >&2
                  log "fetch ok, remote head not found"
                fi
              fi
            fi

            # Auto-update toolkit on each rebuild, but keep local overrides
            if "$git_bin" -C "$opencode_cfg_dir" rev-parse --verify HEAD >/dev/null 2>&1; then
              dirty="$($git_bin -C "$opencode_cfg_dir" status --porcelain 2>/dev/null || true)"
              stashed="0"

            if [[ -n "$dirty" ]]; then
              log "stash push (dirty)"
              "$git_bin" -C "$opencode_cfg_dir" stash push -u -m "hm-opencode-autostash" >/dev/null 2>&1 || true
              stashed="1"
            fi

              remote_head="$(get_remote_head)"
              if [[ -n "$remote_head" ]]; then
                if ! "$git_bin" -C "$opencode_cfg_dir" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
                  "$git_bin" -C "$opencode_cfg_dir" branch --set-upstream-to="$remote_head" >/dev/null 2>&1 || true
                fi
              fi

              log "pull --rebase"
              if pull_origin; then
                log "pull ok"
              else
                echo "opencode: llm-toolkit pull failed (no network/auth?)" >&2
                log "pull failed"
              fi

              if [[ "$stashed" == "1" ]]; then
                log "stash pop"
                "$git_bin" -C "$opencode_cfg_dir" stash pop >/dev/null 2>&1 || true
              fi
            fi
          fi

          ensure_alias() {
            local preferred="$1"
            local compat="$2"

            if [[ -d "$opencode_cfg_dir/$preferred" && ! -e "$opencode_cfg_dir/$compat" ]]; then
              ln -s "$preferred" "$opencode_cfg_dir/$compat"
              return
            fi

            if [[ -d "$opencode_cfg_dir/$compat" && ! -e "$opencode_cfg_dir/$preferred" ]]; then
              ln -s "$compat" "$opencode_cfg_dir/$preferred"
              return
            fi

            if [[ ! -e "$opencode_cfg_dir/$preferred" && ! -e "$opencode_cfg_dir/$compat" ]]; then
              mkdir -p "$opencode_cfg_dir/$preferred"
              ln -s "$preferred" "$opencode_cfg_dir/$compat"
              return
            fi
          }

          ensure_alias agents agent
          ensure_alias skills skill
          ensure_alias commands command

          # Keep repo clean even if HM replaces opencode.json
          if [[ -f "$opencode_cfg_dir/opencode.json" ]]; then
            "$git_bin" -C "$opencode_cfg_dir" update-index --skip-worktree opencode.json >/dev/null 2>&1 || true
          fi
        '';

        xdg.configFile = {
          "opencode/config.json".source = mkForce (
            config.lib.file.mkOutOfStoreSymlink config.sops.templates."opencode-config.json".path
          );

          # llm-toolkit ships `opencode.json`; OpenCode prefers it.
          # Point it to the same rendered config with secrets.
          "opencode/opencode.json".source = mkForce (
            config.lib.file.mkOutOfStoreSymlink config.sops.templates."opencode-config.json".path
          );
        }
        // (lib.mapAttrs' (
          name: content:
          lib.nameValuePair "opencode/skills/${name}/SKILL.md" (
            if lib.isPath content then { source = content; } else { text = content; }
          )
        ) (cfg.skills or { }));
      };
    };
}
