# Общий харнесс агентов (pi, claude-code, opencode): единый store скиллов
# ~/.agents/skills и общий system prompt.
# Остальная агент-специфика остаётся в своих модулях (pi.nix, claude.nix,
# opencode.nix).
{ inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    let
      configFiles =
        lib.concatMapAttrs
          (
            host: nixos:
            lib.concatMapAttrs (
              user: hm:
              lib.mapAttrs' (name: lib.nameValuePair "${host}-${user}-${name}") (
                hm.programs.harness.configFiles or { }
              )
            ) (nixos.config.home-manager.users or { })
          )
          (
            lib.filterAttrs (
              _: nixos: nixos.pkgs.stdenv.hostPlatform.system == system
            ) inputs.self.nixosConfigurations
          );
    in
    {
      checks.harness-configs =
        pkgs.runCommand "harness-configs"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            ${lib.concatStrings (
              lib.mapAttrsToList (name: file: ''
                echo ${name}
                jq empty ${file}
              '') configFiles
            )}
            touch "$out"
          '';
    };

  flake.homeModules.harness =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      # engineering (20) + productivity (7) из mattpocock/skills. misc и
      # in-progress намеренно не ставим
      mattpocockSkills = [
        "ask-matt"
        "codebase-design"
        "code-review"
        "diagnosing-bugs"
        "domain-modeling"
        "grill-with-docs"
        "implement"
        "implement-spec"
        "improve-codebase-architecture"
        "pr"
        "prototype"
        "research"
        "retro"
        "setup-matt-pocock-skills"
        "tdd"
        "to-spec"
        "to-tickets"
        "triage"
        "wayfinder"
        "wizard"
        "grilling"
        "grill-me"
        "handoff"
        "teach"
        "to-questionnaire"
        "wait-what"
        "writing-for-agents"
      ];

      sharedAppend = /* markdown */ ''
        The user is a senior developer. Communication is plain, concise and actionable. Every answer exists to solve the problem.

        ## Language
        - Always reply in Russian. Code, identifiers, paths, commands and quoted tool output stay unchanged.
        - Never output Chinese characters, in any language context. If a Chinese word comes to mind, write the Russian or English word instead.

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
        The default is no comment. A comment is a sign that the code failed to explain itself, it costs every future reader and it rots when the code changes. You understand code without comments, so never write one for yourself or for another agent: comments exist only for a human reader.
        - Before writing a comment, make the code say it: a precise name, an extracted function, a named constant, a type, a test. Write the comment only if none of these can carry the meaning.
        - A comment may explain why, never what or how. Allowed only when a careful reader would otherwise get it wrong:
          - a workaround for a bug in a library, tool or upstream service, with the issue link if there is one
          - an order of operations, locking or concurrency rule that breaks if changed
          - a magic value imposed by a protocol, hardware or external API
          - code that looks dead, wrong or redundant but is intentional
          - a non-obvious side effect, invariant or performance trick
        - Forbidden: restating the code, names or types; doc comments on functions, types and packages (godoc, JSDoc, docstrings); commented-out code; section dividers and banners; change history, authorship or "fixed X" notes (that is what git is for); TODO without a ticket; notes about your task or your reasoning.
        - When you change code, delete the comments your change made false. Do not touch other people's correct comments and do not add new ones to code you only read.
        - Format: one short sentence in Russian, no period at the end, no dashes, no ";". Put it at the end of the code line. Only if it does not fit, put it on the line above.

        ## Commands
        If the whole user message is exactly one of these words, act as if its expansion was written instead. Inside a longer message they are ordinary words.
        - кратко: simplify and compress your previous answer, then repeat it.
        - проще: explain it as to an 18 year old, with simpler words and fewer of them.
        - суть: reduce your previous answer to the single thing that matters most.
        - пронумеруй: rewrite your previous answer with reference codes.

        ## Git
        - Switch branches with `git switch` (not `git checkout`); discard changes with `git restore`.

        ## Code intelligence
        Each tool has one job, do not use two tools for the same question.
        - Structure of a file: aft_outline. Body of a symbol: aft_zoom. Find code by name or text: aft_search, or grep for exact strings, comments, logs and config keys.
        - In Go, Nix, TypeScript, TSX, JavaScript, Rust and Python use LSP only for what aft cannot do: exact definition across files (lsp_definition), every usage of a symbol (lsp_references), its type or signature (lsp_hover), quick fixes and imports (lsp_code_actions).
        - Rename a symbol only with lsp_rename, never with edit or text replacement: it updates every reference across files.
        - After every edit of a file in these languages, run lsp_diagnostics on it. Never report a task as done while it shows errors you introduced.
        - Find files with find, list directories with ls.

        ## Workflow for code tasks
        Work autonomously until the task is done or you are blocked.
        1. Locate: find code with aft_search and files with find. Read only the line ranges you need with aft_outline, aft_zoom or read. Never guess file contents, APIs or paths.
        2. Plan: if the change touches more than one file, first write a numbered plan of at most 5 steps.
        3. Edit: make one small change at a time. Match the existing style. Do not add files, dependencies or refactors that were not asked for.
        4. Verify: run lsp_diagnostics on the changed files and fix the errors, then run the narrowest build, test or lint command. On failure, read the error, fix it and re-run. After 3 failed attempts, stop and report.
        5. Report in at most 5 lines: what changed (path:line), how it was verified, what is left.

        Rules:
        - Make independent read-only tool calls in the same turn.
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

    in
    {
      options.programs.harness.appendShared = lib.mkOption {
        type = lib.types.str;
        default = sharedAppend;
        description = "System prompt shared by all agents";
      };

      options.programs.harness.localModelUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8085";
        description = "llama.cpp server base URL for agents";
      };

      options.programs.harness.internalGitHost = lib.mkOption {
        type = lib.types.str;
        default = "git.protei.ru";
        description = "Internal git host used by agent MCP servers";
      };

      options.programs.harness.aftVersion = lib.mkOption {
        type = lib.types.str;
        default = "0.59.0";
        description = "aft version shared by pi and opencode, both write the same storage";
      };

      # LSP ownership (ADR-0002): какой сервер владеет языком в каждом агенте.
      # Ключ — aft LSP id из каталога aft v0.59.0; отсутствующий ключ агента
      # = у агента нет LSP для языка. Disabled-лист общего aft-конфига
      # генерируется из ключей: LSP обслуживают нативные экстеншены агентов,
      # не aft.
      options.programs.harness.lspOwnership = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = {
          astro = { };
          bash = { };
          biome = { };
          clangd = { };
          clojure-lsp = { };
          csharp = { };
          dart = { };
          dockerfile = { };
          elixir-ls = { };
          fsharp = { };
          gleam = { };
          go = {
            opencode = "gopls";
            pi = "pi-lsp (gopls)";
          };
          haskell-language-server = { };
          # jdtls-бинарник не установлен, java ни у кого не обслуживается
          jdtls = { };
          julials = { };
          kotlin-ls = { };
          lua-ls = { };
          nixd = {
            opencode = "nixd";
            pi = "pi-lsp (nixd)";
          };
          ocaml-lsp = { };
          oxlint = { };
          php-intelephense = { };
          prisma = { };
          python = {
            opencode = "basedpyright";
            pi = "pi-lsp (pyright)";
          };
          razor = { };
          ruby-lsp = { };
          rust = {
            opencode = "rust-analyzer";
            pi = "pi-lsp (rust-analyzer)";
          };
          sourcekit-lsp = { };
          svelte = { };
          terraform = { };
          texlab = { };
          tinymist = { };
          ty = { };
          typescript = {
            opencode = "typescript-language-server";
            pi = "pi-lsp (typescript-language-server)";
          };
          typescript-native = {
            opencode = "typescript-language-server";
            pi = "pi-lsp (typescript-language-server)";
          };
          vue = { };
          yaml = { };
          zls = { };
        };
        description = "LSP ownership (ADR-0002): aft LSP id -> owning server per agent; keys generate the shared aft config's disabled-LSP list";
      };

      options.programs.harness.codebaseMemory = lib.mkOption {
        type = lib.types.package;
        # non-UI: UI-сборка тянет graph-ui, у которого протух npmDepsHash
        default = inputs.codebase-memory-mcp.packages.${pkgs.stdenv.hostPlatform.system}.default;
        description = "codebase-memory-mcp package shared by pi, opencode and claude-code";
      };

      options.programs.harness.mcpNixos = lib.mkOption {
        type = lib.types.package;
        default = pkgs-unstable.mcp-nixos;
        description = "mcp-nixos package shared by pi, opencode and claude-code";
      };

      options.programs.harness.codebaseMemoryArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "CLI args for the codebase-memory-mcp server, shared by pi, opencode and claude-code";
      };

      options.programs.harness.codebaseMemoryAutoIndex = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Index new repositories automatically when an MCP session starts";
      };

      options.programs.harness.configFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        internal = true;
        description = "Generated agent configs that the harness-configs flake check parses as JSON";
      };

      options.programs.harness.permissions = lib.mkOption {
        type = lib.types.submodule (
          { ... }:
          {
            options.secretsPatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "*.env"
                "*.env.*"
                "~/.ssh/*"
                "~/.gnupg/*"
                "~/.aws/*"
                "*-credentials.json"
                "*.git-credentials"
                "*serviceAccount*.json"
                "*service-account*.json"
                "~/.azure/*"
                "~/.kube/*"
                "*kubeconfig*"
                "*-secret.yaml"
                "*secrets.yaml"
                "~/.docker/*"
                "*.pem"
                "*.key"
                "*.p12"
                "*.pfx"
                "*.tfstate"
                "*.tfstate.backup"
                "*/.terraform/*"
                "*/.vercel/*"
                "*/.netlify/*"
                "*/.supabase/*"
                "firebase-adminsdk*"
                "*.netrc"
                "*.npmrc"
                "*.pypirc"
                "*dump.sql"
                "*backup.sql"
                "*.dump"
              ];
              description = "Секреты: запрещены на всех инструментах и в bash, в обе стороны";
            };
            options.secretsReason = lib.mkOption {
              type = lib.types.str;
              default = "Секрет: чтение и запись через агента запрещены";
            };
            options.secretsExceptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "*.env.example" ];
              description = "Файлы, совпадающие с secretsPatterns, но не содержащие секретов по определению (.env.example): чтение разрешено (ADR-0008)";
            };
            options.protectedWritePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "/etc/*"
                "/usr/*"
                "/bin/*"
                "/sbin/*"
                "/boot/*"
                "/root/*"
                "*.bash_history"
                "*.zsh_history"
                "*.node_repl_history"
                "*.bashrc"
                "*.zshrc"
                "*.profile"
                "*.bash_profile"
                "*.lock"
                "*.lockb"
                "*go.sum"
                "*-lock.yaml"
                "*.min.js"
                "*.min.css"
                "*.bundle.js"
                "*.chunk.js"
                "*/dist/*"
                "*/build/*"
                "*/.next/*"
                "*/.nuxt/*"
                "*/.output/*"
                "*/__pycache__/*"
                "*/.venv/*"
                "*/venv/*"
                "*/target/*"
                "~/.pi/*"
                "~/.config/*"
              ];
              description = "Только-чтение: чтение разрешено, запись запрещена (декларативно управляемые файлы, артефакты, системные каталоги)";
            };
            options.protectedWriteReason = lib.mkOption {
              type = lib.types.str;
              default = "Путь под управлением (NixOS-конфиг, лок-файл или артефакт сборки): меняй декларативный конфиг, а не файл напрямую";
            };
            options.protectedWriteExceptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "~/.pi/agent/skills/*" ];
              description = "Исключения для protectedWritePatterns: запись разрешена (ADR-0008); store скиллов агента";
            };
            options.metaFilePatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "~/.claude/*"
                "*CLAUDE.md"
                "*LICENSE"
                "*LICENSE.*"
                "*COPYING"
                "*COPYING.*"
                "*NOTICE"
                "*PATENTS"
                "*README.md"
                "*README.*"
                "*CONTRIBUTING.md"
                "*CHANGELOG.md"
                "*CODE_OF_CONDUCT.md"
                "*SECURITY.md"
                "*/.git/*"
                "*.gitignore"
                "*.gitattributes"
                "*.gitmodules"
                "*/.github/*"
                "*.gitlab-ci.yml"
                "*/.circleci/*"
                "*Jenkinsfile"
                "*.travis.yml"
                "*azure-pipelines.yml"
                "*Dockerfile"
                "*Dockerfile.*"
                "*docker-compose*.yml"
                "*.dockerignore"
              ];
              description = "Мета-файлы репозитория: удаление/перезапись — ask (pi yolo: allow + review log, opencode: prompt), чтение свободно (ADR-0008)";
            };
            options.metaFileReason = lib.mkOption {
              type = lib.types.str;
              default = "Мета-файл проекта: удаление или перезапись только по явной просьбе через пользователя";
            };
            options.bashAllowPatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "cat *"
                "head *"
                "tail *"
                "ls *"
                "tree *"
                "stat *"
                "file *"
                "wc *"
                "du *"
                "df *"
                "grep *"
                "egrep *"
                "fgrep *"
                "rg *"
                "find *"
                "fd *"
                "diff *"
                "cmp *"
                "comm *"
                "md5sum *"
                "sha1sum *"
                "sha256sum *"
                "shasum *"
                "cksum *"
                "pwd"
                "whoami"
                "id"
                "hostname"
                "uname *"
                "date"
                "uptime"
                "ps *"
                "printenv *"
                "which *"
                "type *"
                "true"
                "git status"
                "git diff *"
                "git log *"
                "git show *"
                "git blame *"
                "git ls-files *"
                "git branch"
                "git branch -d *"
                "git remote -v"
                "git remote show *"
                "git fetch *"
                "git pull *"
                "git add *"
                "git commit *"
                "git switch *"
                "git rev-parse *"
                "git describe *"
                "git tag"
                "nix *"
                "nixfmt *"
                "sleep *"
              ];
              description = "Bash-команды, которые проходят без запроса (read-only и рабочий git-набор)";
            };
            options.bashAskPatterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                # sudo поднимает пол до ask: привилегированная команда всегда через пользователя
                "sudo *"
                # checkout/restore — ask; checkout -- остаётся deny (см. bashDenyPatterns)
                "git checkout *"
                "git restore *"
              ];
              description = "Явные ask-паттерны (кроме дефолта)";
            };
            options.bashDenyPatterns = lib.mkOption {
              type = lib.types.listOf (
                lib.types.submodule (
                  { ... }:
                  {
                    options.pattern = lib.mkOption { type = lib.types.str; };
                    options.reason = lib.mkOption { type = lib.types.str; };
                  }
                )
              );
              default = [
                {
                  pattern = "rm -rf *";
                  reason = "Рекурсивный rm запрещён (AGENTS.md): удаление делает пользователь";
                }
                {
                  pattern = "rm -fr *";
                  reason = "Рекурсивный rm запрещён (AGENTS.md): удаление делает пользователь";
                }
                {
                  pattern = "rm -r *";
                  reason = "Рекурсивный rm запрещён (AGENTS.md): удаление делает пользователь";
                }
                {
                  pattern = "rm -R *";
                  reason = "Рекурсивный rm запрещён (AGENTS.md): удаление делает пользователь";
                }
                {
                  pattern = "find * -delete *";
                  reason = "find -delete запрещён (AGENTS.md): удаление делает пользователь";
                }
                {
                  pattern = "git checkout -- *";
                  reason = "git checkout -- отбрасывает незакоммиченные изменения: согласуй с пользователем";
                }
                {
                  pattern = "git stash drop *";
                  reason = "Разрушительная git-операция: согласуй с пользователем";
                }
                {
                  pattern = "git stash clear *";
                  reason = "Разрушительная git-операция: согласуй с пользователем";
                }
                {
                  pattern = "git branch -D *";
                  reason = "Принудительное удаление ветки: согласуй с пользователем";
                }
                {
                  pattern = "git reset --hard *";
                  reason = "Отбрасывает изменения: согласуй с пользователем";
                }
                {
                  pattern = "git push -f *";
                  reason = "Force-push перезаписывает удалённую историю: только по явной просьбе";
                }
                {
                  pattern = "git push --force *";
                  reason = "Force-push перезаписывает удалённую историю: только по явной просьбе";
                }
                {
                  pattern = "git push * --force *";
                  reason = "Force-push перезаписывает удалённую историю: только по явной просьбе";
                }
                {
                  pattern = "git push * --delete *";
                  reason = "Удаление удалённой ветки: только по явной просьбе";
                }
                {
                  pattern = "git push * :*";
                  reason = "Удаление удалённой ветки: только по явной просьбе";
                }
                {
                  pattern = "mkfs*";
                  reason = "Форматирование файловой системы";
                }
                {
                  pattern = "dd *of=/dev/*";
                  reason = "Запись в блочное устройство";
                }
              ];
              description = "Bash-команды, которые запрещены (deny с причиной)";
            };
          }
        );
        description = "Shared operation classification (ADR-0006)";
      };

      config = {
        home.packages = [
          config.programs.harness.codebaseMemory
        ];

        # Одна команда на каждый switch: обновляет скиллы и пересоздаёт
        # симлинки. pi и opencode читают store нативно, claude-code получает
        # пер-скилловые симлинки в ~/.claude/skills
        home.activation.updateAgentSkills = /* bash */ ''
          set -euo pipefail
          log() { printf '[harness] %s\n' "$*" >&2; }
          export PATH="${
            lib.makeBinPath [
              pkgs.nodejs
              pkgs.git
              pkgs.coreutils
            ]
          }:$PATH"
          if DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 "${pkgs.coreutils}/bin/timeout" 300s \
            npx -y skills@latest add mattpocock/skills -g -a pi -a claude-code -y -s ${lib.escapeShellArgs mattpocockSkills} >/dev/null 2>&1; then
            log "Updated mattpocock/skills in ~/.agents/skills"
          else
            log "WARNING: npx skills add mattpocock/skills failed (no network?), keeping installed skills"
          fi
        '';

        # Скилл из cursor/plugins: fetch в activation, не в деривации, чтобы
        # не кэшироваться в store и всегда тянуть свежий upstream. Имя hook'а
        # алфавитно после updateAgentSkills, чтобы идти после npx skills
        home.activation.updateCursorSkill = /* bash */ ''
          set -euo pipefail
          log() { printf '[harness] %s\n' "$*" >&2; }
          export PATH="${
            lib.makeBinPath [
              pkgs.curl
              pkgs.coreutils
            ]
          }:$PATH"
          skill_dir="$HOME/.agents/skills/thermo-nuclear-code-quality-review"
          url="https://raw.githubusercontent.com/cursor/plugins/main/cursor-team-kit/skills/thermo-nuclear-code-quality-review/SKILL.md"
          tmp=$(mktemp)
          trap 'rm -f "$tmp"' EXIT
          if "${pkgs.coreutils}/bin/timeout" 60s "${pkgs.curl}/bin/curl" -fsSL "$url" -o "$tmp"; then
            if [[ -f "$skill_dir/SKILL.md" ]] && cmp -s "$tmp" "$skill_dir/SKILL.md"; then
              log "thermo-nuclear-code-quality-review skill is up to date"
            else
              mkdir -p "$skill_dir"
              mv "$tmp" "$skill_dir/SKILL.md"
              log "Updated thermo-nuclear-code-quality-review skill from cursor/plugins"
            fi
          else
            log "WARNING: could not fetch thermo-nuclear-code-quality-review skill (no network?), keeping installed"
          fi
          ln -sfn "$skill_dir" "$HOME/.claude/skills/thermo-nuclear-code-quality-review"
        '';

        # auto_index не имеет ни env, ни JSON-ключа (только SQLite _config.db),
        # ставится CLI. Конфликт с живым демоном другой версии не должен ронять activation
        home.activation.codebaseMemoryConfig = lib.mkIf config.programs.harness.codebaseMemoryAutoIndex /* bash */ ''
          set -uo pipefail
          log() { printf '[harness] %s\n' "$*" >&2; }
          if "${lib.getExe config.programs.harness.codebaseMemory}" config set auto_index true; then
            log "codebase-memory-mcp: auto_index=true"
          else
            log "WARNING: could not set codebase-memory-mcp auto_index (conflicting daemon?), will retry next activation"
          fi
        '';
      };
    };
}
