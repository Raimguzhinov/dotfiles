# opencode: конфиг нативными опциями programs.opencode, без llm-toolkit.
# 4 секрета (litellm key, youtrack token, gitlab token, lightrag url) не
# попадают в store: в opencode.json встраиваются токены {file:<path>},
# opencode читает sops-nix-файлы при старте (packages/core/src/config/variable.ts).
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
      lib,
      osConfig,
      pkgs,
      pkgs-unstable,
      ...
    }:
    {
      config = {

        home.packages = [
          pkgs-unstable.opencode-desktop
        ];

        home.sessionVariables.ORT_DYLIB_PATH = "${pkgs.onnxruntime}/lib/libonnxruntime.so";

        programs.opencode = {
          enable = true;
          package = pkgs-unstable.opencode;

          settings = {
            share = "disabled";
            autoupdate = false;
            model = "opencode/longcat-2.5-preview-free";
            small_model = "opencode/longcat-2.5-preview-free";
            default_agent = "build";
            # MC ведёт свою компакцию; нативную автокомпакцию выключено
            compaction = {
              auto = false;
              prune = false;
            };

            provider = {
              Protei = {
                npm = "@ai-sdk/openai-compatible";
                name = "Protei";
                options = {
                  baseURL = "https://agent.ai.protei.ru/api";
                  apiKey = "{file:${config.sops.secrets."work_ai/litellm_api_key".path}}";
                };
                models = {
                  Strict = {
                    name = "Protei Strict";
                    id = "agent_proteya";
                    description = "Строгие параметры. Модель следует инструкциям. 'presence penalty' равный 1.5 помогает избегать повторений";
                    status = "active";
                    tool_call = true;
                    attachment = true;
                    reasoning = true;
                    temperature = true;
                    limit = {
                      context = 262144;
                      output = 16000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                    options = {
                      temperature = 0.7;
                      topP = 0.8;
                      topK = 20;
                      minP = 0.0;
                      presencePenalty = 1.5;
                      repetitionPenalty = 1.0;
                    };
                    variants = {
                      off.chat_template_kwargs.enable_thinking = false;
                      low = {
                        disabled = false;
                        chat_template_kwargs = {
                          enable_thinking = true;
                          reasoning_effort = "low";
                        };
                      };
                      medium = {
                        disabled = false;
                        chat_template_kwargs = {
                          enable_thinking = true;
                          reasoning_effort = "medium";
                        };
                      };
                      xhigh.chat_template_kwargs = {
                        enable_thinking = true;
                        reasoning_effort = "xhigh";
                      };
                    };
                  };
                  Coding = {
                    name = "Protei Coding";
                    id = "agent_proteya";
                    description = "Хорошо подходит для задач программирования";
                    status = "active";
                    tool_call = true;
                    attachment = true;
                    reasoning = true;
                    temperature = true;
                    limit = {
                      context = 262144;
                      output = 65536;
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
                    variants = {
                      off.chat_template_kwargs.enable_thinking = false;
                      low = {
                        disabled = false;
                        chat_template_kwargs = {
                          enable_thinking = true;
                          reasoning_effort = "low";
                        };
                      };
                      medium = {
                        disabled = false;
                        chat_template_kwargs = {
                          enable_thinking = true;
                          reasoning_effort = "medium";
                        };
                      };
                      xhigh.chat_template_kwargs = {
                        enable_thinking = true;
                        reasoning_effort = "xhigh";
                      };
                    };
                  };
                  title_model = {
                    id = "title_model";
                    name = "title_model";
                    status = "active";
                    tool_call = false;
                    attachment = false;
                    reasoning = false;
                    temperature = false;
                    limit = {
                      context = 8000;
                      output = 80;
                    };
                    modalities = {
                      input = [ "text" ];
                      output = [ "text" ];
                    };
                  };
                  Small = {
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
                    variants = {
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
                  };
                };
              };
              llamaCpp = {
                name = "Local llama.cpp";
                npm = "@ai-sdk/openai-compatible";
                options = {
                  apiKey = "local";
                  baseURL = "http://localhost:8085/v1";
                };
                models."ornith-ai/Ornith-1.5-35B-A3B" = {
                  name = "Ornith 1.5 35B A3B";
                  description = "Локальная модель для offline-кодинга";
                  limit = {
                    context = 65536;
                    output = 8192;
                  };
                  options = {
                    temperature = 0.6;
                    topK = 20;
                    topP = 0.95;
                  };
                  reasoning = true;
                  tool_call = true;
                  variants = {
                    low.chat_template_kwargs = {
                      enable_thinking = true;
                      reasoning_effort = "low";
                    };
                    off.chat_template_kwargs.enable_thinking = false;
                  };
                };
              };
            };

            agent = {
              plan.model = "Protei/Strict";
              build.model = "Protei/Coding";
              title.model = "Protei/title_model";
            };

            mcp = {
              youtrack = {
                type = "remote";
                url = "https://youtrackmcp.ai.protei.ru/mcp";
                enabled = true;
                headers."youtrack-token" = "{file:${config.sops.secrets."youtrack/token".path}}";
              };
              rag = {
                type = "local";
                command = [
                  "uvx"
                  "--from"
                  "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/lightrag-mcp.git"
                  "lightrag-mcp"
                ];
                enabled = true;
                environment = {
                  LIGHTRAG_BASE_URL = "{file:${config.sops.secrets."work_ai/lightrag_url".path}}";
                  LIGHTRAG_TIMEOUT = "60";
                  LIGHTRAG_VERIFY_SSL = "False";
                };
              };
              gitlab = {
                type = "local";
                command = [
                  "uvx"
                  "--from"
                  "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/gitlab.git"
                  "gitlab-mcp-server"
                ];
                enabled = true;
                environment = {
                  GITLAB_URL = "https://git.protei.ru";
                  GITLAB_TOKEN = "{file:${config.sops.secrets."git/gitlab_mcp_token".path}}";
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
              searxng = {
                type = "local";
                command = [
                  "npx"
                  "-y"
                  "mcp-searxng"
                ];
                enabled = true;
                environment.SEARXNG_URL = "http://127.0.0.1:${toString osConfig.services.searx.settings.server.port}";
              };
            };

            permission =
              let
                perms = config.programs.harness.permissions;
              in
              {
                "*" = "allow";
                read = {
                  "*" = "allow";
                }
                // lib.listToAttrs (
                  map (p: {
                    name = p;
                    value = "deny";
                  }) perms.secretsPatterns
                );
                edit = {
                  "*" = "allow";
                }
                // lib.listToAttrs (
                  map (p: {
                    name = p;
                    value = "deny";
                  }) (perms.protectedWritePatterns ++ perms.metaFilePatterns ++ perms.secretsPatterns)
                );
                bash = {
                  "*" = "ask";
                }
                // lib.listToAttrs (
                  map (p: {
                    name = p;
                    value = "allow";
                  }) perms.bashAllowPatterns
                )
                // lib.listToAttrs (
                  map (p: {
                    name = p;
                    value = "ask";
                  }) perms.bashAskPatterns
                )
                // lib.listToAttrs (
                  map (d: {
                    name = d.pattern;
                    value = "deny";
                  }) perms.bashDenyPatterns
                );
                external_directory = {
                  "*" = "ask";
                  "~/.config/opencode/*" = "allow";
                };
              };

            plugin = [
              "opencode-claude-auth@latest"
              "@cortexkit/aft-opencode@${config.programs.harness.aftVersion}"
            ];

            lsp = {
              typescript = {
                disabled = false;
                command = [
                  "typescript-language-server"
                  "--stdio"
                ];
                extensions = [
                  ".ts"
                  ".tsx"
                  ".js"
                  ".jsx"
                  ".mts"
                  ".cts"
                ];
              };
              rust = {
                disabled = false;
                command = [ "rust-analyzer" ];
                extensions = [ ".rs" ];
              };
              nix = {
                disabled = false;
                command = [ "nixd" ];
                extensions = [ ".nix" ];
              };
              basedpyright = {
                disabled = false;
                command = [
                  "basedpyright-langserver"
                  "--stdio"
                ];
                extensions = [
                  ".py"
                  ".pyi"
                ];
                env.PYRIGHT_PYTHON_PATH = "./.venv/bin/python";
              };
              gopls = {
                disabled = false;
                command = [ "gopls" ];
                extensions = [ ".go" ];
              };
            };
          };

          # Только Nix-специфичные
          skills = {
            nix-review-checklist = /* markdown */ ''
              # Чек\u2011лист ревью Nix

              Быстрый чек\u2011лист для самопроверки перед PR/rebuild.

              ## Шаги

              1. Проверить, что новые `.nix` файлы добавлены в git (иначе `import-tree` их не увидит)
              2. Проверить Linux-only условия: использовать `system` + `builtins.elem`, не `pkgs.stdenv.isLinux` в `perSystem`
              3. Убедиться, что секреты не попали в nix store (только `sops.placeholder`/`sops.templates`)
              4. Прогнать форматирование: `nixfmt nixos/modules/`
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
      };
    };
}
