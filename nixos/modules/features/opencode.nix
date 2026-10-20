# opencode: конфиг нативными опциями programs.opencode, без llm-toolkit.
# 4 секрета (litellm key, youtrack token, gitlab token, lightrag url) не
# попадают в store: в opencode.json встраиваются токены {file:<path>},
# opencode читает sops-nix-файлы при старте (packages/core/src/config/variable.ts).
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      packages.opencode = inputs.opencode.packages.${system}.opencode;
    };

  flake.homeModules.opencode =
    {
      config,
      inputs,
      osConfig,
      pkgs,
      ...
    }:
    let
      op = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system};
      thinkingVariants = [
        {
          id = "off";
          body.chat_template_kwargs.enable_thinking = false;
        }
        {
          id = "low";
          body.chat_template_kwargs = {
            enable_thinking = true;
            reasoning_effort = "low";
          };
        }
        {
          id = "medium";
          body.chat_template_kwargs = {
            enable_thinking = true;
            reasoning_effort = "medium";
          };
        }
        {
          id = "xhigh";
          body.chat_template_kwargs = {
            enable_thinking = true;
            reasoning_effort = "xhigh";
          };
        }
      ];
    in
    {
      config = {

        home.packages = [ op.opencode-desktop ];

        home.sessionVariables.ORT_DYLIB_PATH = "${pkgs.onnxruntime}/lib/libonnxruntime.so";

        programs.harness.configFiles.opencode = config.xdg.configFile."opencode/opencode.json".source;

        programs.opencode = {
          enable = true;
          package = op.opencode;

          # Формат конфигурации opencode 2.x (схема @opencode/schema/config)
          settings = {
            share = "disabled";
            update = "disable";
            model = "opencode/longcat-2.5-preview-free";
            default_agent = "build";
            # MC ведёт свою компакцию; нативную автокомпакцию выключено
            compaction = {
              auto = false;
            };

            providers = {
              Protei = {
                name = "Protei";
                package = "aisdk:@ai-sdk/openai-compatible";
                settings = {
                  baseURL = "https://agent.ai.protei.ru/api";
                  apiKey = "{file:${config.sops.secrets."work_ai/litellm_api_key".path}}";
                };
                models = {
                  Strict = {
                    name = "Protei Strict";
                    modelID = "agent_proteya";
                    limit = {
                      context = 262144;
                      output = 16000;
                    };
                    body = {
                      temperature = 0.7;
                      topP = 0.8;
                      topK = 20;
                      minP = 0.0;
                      presencePenalty = 1.5;
                      repetitionPenalty = 1.0;
                    };
                    variants = thinkingVariants;
                  };
                  Coding = {
                    name = "Protei Coding";
                    modelID = "agent_proteya";
                    limit = {
                      context = 262144;
                      output = 65536;
                    };
                    body = {
                      temperature = 1.0;
                      topP = 0.95;
                      topK = 20;
                      minP = 0.0;
                      presencePenalty = 0.0;
                      repetitionPenalty = 1.0;
                    };
                    variants = thinkingVariants;
                  };
                  title_model = {
                    name = "title_model";
                    modelID = "title_model";
                    limit = {
                      context = 8000;
                      output = 80;
                    };
                    capabilities = {
                      tools = false;
                      input = [ "text" ];
                      output = [ "text" ];
                    };
                  };
                  Small = {
                    name = "Protei Small";
                    modelID = "agent_proteya_slow";
                    limit = {
                      context = 131072;
                      output = 8192;
                    };
                    body = {
                      temperature = 1.0;
                      topP = 0.95;
                      topK = 20;
                      minP = 0.0;
                      presencePenalty = 0.0;
                      repetitionPenalty = 1.0;
                    };
                    variants = thinkingVariants;
                  };
                };
              };
              llamaCpp = {
                name = "Local llama.cpp";
                package = "aisdk:@ai-sdk/openai-compatible";
                settings = {
                  apiKey = "local";
                  baseURL = "http://localhost:8085/v1";
                };
                models."ornith-ai/Ornith-1.5-35B-A3B" = {
                  name = "Ornith 1.5 35B A3B";
                  limit = {
                    context = 65536;
                    output = 8192;
                  };
                  body = {
                    temperature = 0.6;
                    topK = 20;
                    topP = 0.95;
                  };
                  variants = [
                    {
                      id = "low";
                      body.chat_template_kwargs = {
                        enable_thinking = true;
                        reasoning_effort = "low";
                      };
                    }
                    {
                      id = "off";
                      body.chat_template_kwargs.enable_thinking = false;
                    }
                  ];
                };
              };
            };

            agents = {
              plan.model = "Protei/Strict";
              build.model = "Protei/Coding";
              title.model = "Protei/title_model";
            };

            mcp = {
              servers = {
                youtrack = {
                  type = "remote";
                  url = "https://youtrackmcp.ai.protei.ru/mcp";
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
                  environment = {
                    GITLAB_URL = "https://git.protei.ru";
                    GITLAB_TOKEN = "{file:${config.sops.secrets."git/gitlab_mcp_token".path}}";
                  };
                };
                context7 = {
                  type = "remote";
                  url = "https://mcp.context7.com/mcp";
                };
                gh_grep = {
                  type = "remote";
                  url = "https://mcp.grep.app";
                };
                searxng = {
                  type = "local";
                  command = [
                    "npx"
                    "-y"
                    "mcp-searxng"
                  ];
                  environment.SEARXNG_URL = "http://127.0.0.1:${toString osConfig.services.searx.settings.server.port}";
                };
              };
            };

            # Правила применяются last-match-wins, порядок: общее, потом специфичное
            permissions =
              let
                perms = config.programs.harness.permissions;
                shell = effect: pattern: {
                  action = "shell";
                  resource = pattern;
                  effect = effect;
                };
              in
              [
                {
                  action = "*";
                  resource = "*";
                  effect = "allow";
                }
              ]
              ++ map (p: {
                action = "read";
                resource = p;
                effect = "deny";
              }) perms.secretsPatterns
              ++ map (p: {
                action = "read";
                resource = p;
                effect = "allow";
              }) perms.secretsExceptions
              ++ map (p: {
                action = "edit";
                resource = p;
                effect = "deny";
              }) (perms.protectedWritePatterns ++ perms.secretsPatterns)
              ++ map (p: {
                action = "edit";
                resource = p;
                effect = "ask";
              }) perms.metaFilePatterns
              ++ map (p: {
                action = "edit";
                resource = p;
                effect = "allow";
              }) perms.protectedWriteExceptions
              ++ [ (shell "ask" "*") ]
              ++ map (shell "allow") perms.bashAllowPatterns
              ++ map (shell "ask") perms.bashAskPatterns
              ++ map (d: shell "deny" d.pattern) perms.bashDenyPatterns
              ++ [
                {
                  action = "external_directory";
                  resource = "*";
                  effect = "ask";
                }
                {
                  action = "external_directory";
                  resource = "~/.config/opencode/*";
                  effect = "allow";
                }
              ];

            plugins = [
              "opencode-claude-auth@3.0.0"
              "@cortexkit/aft-opencode@${config.programs.harness.aftVersion}"
              # отключает встроенные shell и patch opencode, модель использует bash и apply_patch AFT
              "-opencode.tool.shell"
              "-opencode.tool.patch"
            ];

            lsp = {
              typescript = {
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
                command = [ "rust-analyzer" ];
                extensions = [ ".rs" ];
              };
              nix = {
                command = [ "nixd" ];
                extensions = [ ".nix" ];
              };
              basedpyright = {
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
