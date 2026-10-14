# pi харнесс, шпаргалка: что за чем и когда использовать
#
# Запуск
#   pi              сам агент (эта конфигурация)
#   pi-acp          ACP-адаптер
#   /plan           plan-режим: read-only (read/grep/lsp/aft + subagent-разведчики),
#                   план пишется в todo; /plan ещё раз и начинается исполнение
#
# Большая задача: пайплайн (12 фаз, человеку нужен только checkpoint)
#   triage -> localize -> reproduce -> design -> checkpoint -> plan
#   -> implement -> verify -> review -> regress -> report -> retro
#   pipeline_start "задача"        агент стартует сам или по твоей просьбе
#   pipeline_resume                новая сессия: продолжить оборванный прогон
#                                  с той же фазы (1 кандидат сам подхватывает,
#                                  несколько показывает список)
#   pipeline_start fresh: true     проигнорировать незавершённый прогон и начать заново
#   pipeline_input_triage          маршрутизация внешнего вброса, пришедшего во время прогона
#   pi-pipeline-view               веб-вью событий из ~/.pi/agent/pipeline/events.jsonl
#   Состояние живёт в jsonl сессии, после завершения фазы агент сам жмёт advance_phase
#
# Маленькая задача / фикс: просто попросить. Агент сам:
#   правит -> lsp_diagnostics -> run_gates (go build, golangci-lint, go test,
#   buf lint, nixfmt, ast-grep standards) -> кратко отчитывается
#   give_up        честная остановка, когда застрял (вместо бесконечных ретраев)
#
# Субагенты (herdr-вкладки, subagent / subagent_wait, параллельно)
#   scout         read-only разведка по коду и докам
#   reviewer      read-only ревью диффа на баги
#   critic        анти-дизайн, VERDICT PASS или BLOCK
#   tester        адверсариальный QA: сценарии, ломающие дизайн
#   rival         независимый альтернативный дизайн от задачи и кода
#   psychologist  эмуляция старейших авторов кода, их подход и стиль
#   gopnik        построчный параноидальный антагонист диффа
#
# Разведка (tools.ts)
#   why            git-история файла или диапазона строк: авторы, даты, MR
#   exemplars      2-3 существующих примера того же вида, чтобы подражать
#   bisect         первый коммит, где команда начинает падать (отдельный worktree)
#   flaky          N прогонов теста: stable или flaky
#   project_notes  личные заметки о проекте, вне репо (read/add)
#
# Оценка и статистика
#   pi-eval mine <repo> --add     добавить репо в очередь eval-задач
#   pi-eval                       нейтральная задача "найди баг в Go-репо" против агента
#   pi-stats                      статистика по сессиям
#
# MCP (mcp.json)
#   youtrack        Protei YouTrack: поиск и чтение тикетов
#   gitlab          Protei GitLab: проекты, MR, пайплайны
#   rag             база знаний Protei (LightRAG)
#   searxng         веб-поиск и чтение URL
#   postgres        локальная uc-база, read-only
#   gh_grep         поиск кода по публичным GitHub-репозиториям
#   chrome_devtools живой Chromium: страницы, консоль, сеть, скриншоты
#   codebase_memory граф знаний индексируемых репозиториев
#   uc_dev
#
# Скиллы (~/.agents/skills, вызов /skill:<имя>)
#   triage            разбор тикета: верификация, бриф, критерии приёмки
#   diagnosing-bugs   цикл диагностики сложных багов и регрессий
#   code-review <фикс-точка>  двухосное ревью: стандарты + соответствие спеке
#   codebase-design   проектирование модуля, углубление, швы
#   tdd               red-green-refactor, интеграционные тесты
#   retro             ретроспектива: что недодало агентам и харнессу
#   grilling          допрос: выжать из плана все слабые места
#   weekly-time       таблица учёта рабочего времени за неделю
#   остальные: implement, handoff, to-tickets, domain-modeling,
#   writing-for-agents, pr
#
# npm-экстеншены (источники встроенных инструментов)
#   aft-pi            aft_search / aft_outline / aft_zoom / codemode
#   pi-lsp-extension  lsp_diagnostics / lsp_hover / lsp_definition / lsp_references
#                     / lsp_rename / lsp_code_actions
#   rpiv-todo         todo (план многошаговой работы)
#   context7-pi       актуальные доки библиотек: resolve-library-id + query-docs
#   pi-add-dir, pi-fff, pi-nvim, pi-permission-system, pi-undo-redo
#
#
{ ... }:
let
  mkPiAcp =
    {
      lib,
      buildNpmPackage,
      fetchFromGitHub,
    }:
    buildNpmPackage (finalAttrs: {
      pname = "pi-acp";
      version = "0.0.34";

      src = fetchFromGitHub {
        owner = "svkozak";
        repo = "pi-acp";
        tag = "v${finalAttrs.version}";
        hash = "sha256-QRwxOtTZOY+Np3PkAoy2o2PrUzEqjItM/372sCPlSMo=";
      };
      npmDepsHash = "sha256-BvLNtFfp1cMVjzWcMRSdhTqiJrTfbFoUbWkkPW9200o=";

      meta = {
        description = "ACP adapter for pi coding agent";
        homepage = "https://github.com/svkozak/pi-acp";
        license = lib.licenses.mit;
        mainProgram = "pi-acp";
      };
    });
in
{
  perSystem =
    { pkgs, pkgs-unstable, ... }:
    {
      packages.pi = pkgs-unstable.pi-coding-agent;
      packages.pi-acp = pkgs.callPackage mkPiAcp { };
    };

  flake.nixosModules.pi =
    { ... }:
    {
      config = {
        programs.nix-ld.enable = true;
      };
    };

  flake.homeModules.pi =
    {
      config,
      osConfig,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:

    let
      inherit (lib)
        mkAfter
        ;

      piHarnessAgents = lib.splitString " " "scout reviewer critic tester rival psychologist gopnik";

      piAgentsDq = lib.concatStringsSep ", " (map (a: "\"${a}\"") piHarnessAgents);

      piAgentsJs = "[${piAgentsDq}]";

      piAgentDir = "${config.home.homeDirectory}/.pi/agent";

      agentSkillsDir = "${config.home.homeDirectory}/.agents/skills";

      mattpocockSkills = [
        "grilling"
        "grill-me"
        "grill-with-docs"
        "domain-modeling"
        "triage"
        "diagnosing-bugs"
        "tdd"
        "codebase-design"
        "to-tickets"
        "implement"
        "code-review"
        "retro"
        "pr"
        "handoff"
        "writing-for-agents"
      ];

      readSecret = name: "!cat ${config.sops.secrets.${name}.path}";

      modelsConfig =
        let
          proteiModel = id: name: {
            inherit id;
            inherit name;
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 131072;
            maxTokens = 8192;
            samplingParams = {
              temperature = 1.0;
              top_p = 0.95;
              top_k = 20;
              min_p = 0.0;
              presence_penalty = 0.0;
              repetition_penalty = 1.0;
            };
            samplingParamsByThinkingLevel.off = {
              temperature = 0.7;
              top_p = 0.8;
              presence_penalty = 1.5;
            };
            thinkingLevelMap = {
              off = "none";
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = null;
              max = null;
            };
            compat = {
              supportsDeveloperRole = false;
              thinkingFormat = "chat-template";
              # TODO: если LiteLLM/vLLM Протея отвечает 400 — первым убрать это поле
              thinkingTokenBudgetField = "thinking_token_budget";
              sendSessionAffinityHeaders = true;
              chatTemplateKwargs = {
                enable_thinking = {
                  "$var" = "thinking.enabled";
                };
                reasoning_effort = {
                  "$var" = "thinking.effort";
                  omitWhenOff = true;
                };
              };
            };
          };
          proteiProvider = models: {
            baseUrl = "https://agent.ai.protei.ru/api";
            api = "openai-completions";
            apiKey = readSecret "work_ai/litellm_api_key";
            inherit models;
          };
        in
        {
          providers.Protei = proteiProvider [
            (proteiModel "agent_proteya" "Protei Coding")
            (proteiModel "agent_proteya_slow" "Protei Small")
          ];
          providers.ProteiStrict = proteiProvider [
            (
              removeAttrs (proteiModel "agent_proteya" "Protei Strict") [ "samplingParamsByThinkingLevel" ]
              // {
                contextWindow = 131072;
                maxTokens = 16000;
                samplingParams = {
                  temperature = 0.7;
                  top_p = 0.8;
                  top_k = 20;
                  min_p = 0.0;
                  presence_penalty = 1.5;
                  repetition_penalty = 1.0;
                };
              }
            )
          ];
        };

      mcpConfig = {
        mcpServers = {
          youtrack = {
            description = "Protei YouTrack: search and read issues";
            url = "https://youtrackmcp-uat.ai.protei.ru/mcp";
            headers."youtrack-token" = readSecret "youtrack/token";
          };
          gitlab = {
            description = "Protei GitLab: projects, merge requests, pipelines";
            command = "uvx";
            args = [
              "--from"
              "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/gitlab.git"
              "gitlab-mcp-server"
            ];
            env = {
              GITLAB_URL = "https://git.protei.ru";
              GITLAB_TOKEN = readSecret "git/gitlab_mcp_token";
            };
          };
          rag = {
            description = "Protei knowledge base search (LightRAG)";
            command = "uvx";
            args = [
              "--from"
              "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/lightrag-mcp.git"
              "lightrag-mcp"
            ];
            env = {
              LIGHTRAG_BASE_URL = readSecret "work_ai/lightrag_url";
              LIGHTRAG_TIMEOUT = "60";
              LIGHTRAG_VERIFY_SSL = "False";
            };
          };
          searxng = {
            description = "Web search and URL reading through local SearXNG";
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:${toString osConfig.services.searx.settings.server.port}";
          };
          postgres = {
            description = "Read-only queries to the local uc PostgreSQL database";
            command = "npx";
            args = [
              "-y"
              "@modelcontextprotocol/server-postgres"
              "postgresql://uc:ucPassword@localhost:5432/uc?sslmode=disable&options=-csearch_path%3Dcompany_0%2Cpublic"
            ];
          };
          gh_grep = {
            description = "Search code across public GitHub repositories";
            url = "https://mcp.grep.app";
          };
          codebase_memory = {
            description = "Code knowledge graph of indexed repositories";
            command = "npx";
            args = [
              "-y"
              "codebase-memory-mcp"
            ];
            env = {
              CBM_ALLOWED_ROOT = config.home.homeDirectory;
            };
          };
          chrome-devtools = {
            description = "Chrome DevTools for the running Chromium: pages, console, network, screenshots, performance";
            command = "npx";
            args = [
              "-y"
              "chrome-devtools-mcp@1.10.1"
              "--autoConnect"
              "--userDataDir"
              "${config.xdg.configHome}/chromium"
              "--no-usage-statistics"
              "--no-performance-crux"
            ];
            env.CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS = "1";
          };
          uc-dev = {
            command = "uc-dev";
            args = [ "mcp" ];
            env.UC_DEV_CORE = "${config.home.homeDirectory}/Work/core";
          };
        };
      };

      settingsSeed = {
        defaultProvider = "Protei";
        defaultModel = "auto";
        theme = "dark";
        defaultThinkingLevel = "medium";
        defaultTools = [ "-powershell" ];
        thinkingBudgets = {
          low = 2048;
          medium = 4096;
          high = 6144;
        };
        compaction = {
          reserveTokens = 41000;
          keepRecentTokens = 20000;
        };
        extensions = [ ];
        packages = [
          "npm:@cortexkit/aft-pi"
          "npm:@juicesharp/rpiv-todo"
          "npm:@upstash/context7-pi"
          "npm:pi-add-dir"
          "npm:pi-fff"
          "npm:pi-lsp-extension"
          "npm:pi-nvim"
          "npm:pi-permission-system"
          "${piPlan}"
          "npm:pi-undo-redo"
        ];
      };

      permissionsPolicy = {
        defaultPolicy = {
          tools = "ask";
          bash = "allow";
          mcp = "allow";
          skills = "allow";
          special = "ask";
        };
        tools = {
          read = "allow";
          grep = "allow";
          find = "allow";
          ls = "allow";
          aft_outline = "allow";
          aft_zoom = "allow";
          aft_search = "allow";
          resolve-library-id = "allow";
          query-docs = "allow";
          todo = "allow";
          codemode = "allow";
          lsp_diagnostics = "allow";
          lsp_hover = "allow";
          lsp_definition = "allow";
          lsp_references = "allow";
          subagent = "allow";
          "mcp__*" = "allow";
        };
      };

      keybindingsOverrides = {
        "app.thinking.cycle" = "alt+t";
      };

      aftConfig = {
        format_on_edit = true;
        edit_mode = "default";
        bash.background = false;
        lsp = {
          auto_install = false;
          disabled = [
            "typescript"
            "typescript-native"
            "python"
            "rust"
            "go"
            "bash"
            "yaml"
            "ty"
            "clojure-lsp"
            "dart"
            "elixir-ls"
            "fsharp"
            "gleam"
            "haskell-language-server"
            "jdtls"
            "julials"
            "nixd"
            "ocaml-lsp"
            "php-intelephense"
            "ruby-lsp"
            "sourcekit-lsp"
            "csharp"
            "razor"
            "clangd"
            "lua-ls"
            "zls"
            "tinymist"
            "kotlin-ls"
            "texlab"
            "oxlint"
            "terraform"
            "vue"
            "astro"
            "prisma"
            "biome"
            "svelte"
            "dockerfile"
          ];
        };
        disabled_tools = [
          "aft_inspect"
          "aft_safety"
          "aft_import"
          "aft_conflicts"
          "ast_grep_search"
          "ast_grep_replace"
          "aft_callgraph"
          "aft_delete"
          "aft_move"
        ];
      };

      toJsonFile = (pkgs.formats.json { }).generate;

      modelsJsonFile = toJsonFile "pi-models.json" modelsConfig;
      mcpJsonFile = toJsonFile "pi-mcp.json" mcpConfig;
      settingsSeedFile = toJsonFile "pi-settings-seed.json" settingsSeed;
      permissionsPolicyFile = toJsonFile "pi-permissions.json" permissionsPolicy;
      keybindingsJsonFile = toJsonFile "pi-keybindings.json" keybindingsOverrides;
      aftJsonFile = toJsonFile "aft.jsonc" aftConfig;
      fffJsonFile = toJsonFile "pi-fff.json" {
        enabledFeatures = [ "autocomplete" ];
      };
      piVsCcExtensions =
        pkgs.runCommand "pi-vs-cc-extensions"
          {
            src = pkgs.fetchFromGitHub {
              owner = "disler";
              repo = "pi-vs-claude-code";
              rev = "0ed11f44932fdef29bd98467700019762298f50d";
              hash = "sha256-n6v27jGRg1qCPQpflumGye7b4mz1U8xU06FVnfaglYA=";
            };
            nativeBuildInputs = [ pkgs.yq-go ];
          }
          /* bash */ ''
            mkdir -p "$out"
            yq -o=json "$src/.pi/damage-control-rules.yaml" > "$out/damage-control-rules.json"
            substitute "$src/extensions/damage-control-continue.ts" "$out/damage-control.ts" \
              --replace-fail 'import { parse as yamlParse } from "yaml";' 'const yamlParse = JSON.parse;' \
              --replace-fail 'import { applyExtensionDefaults } from "./themeMap.ts";' "" \
              --replace-fail 'applyExtensionDefaults(import.meta.url, ctx);' "" \
              --replace-fail 'damage-control-rules.yaml' 'damage-control-rules.json' \
              --replace-fail 'const inputPaths: string[] = [];' 'const inputPaths: string[] = []; const deletedPaths: string[] = [];' \
              --replace-fail 'inputPaths.push(event.input.path);' 'if (typeof event.input.path === "string") inputPaths.push(event.input.path); if (typeof event.input.patch === "string") { let section: string | null = null; for (const line of event.input.patch.split("\n")) { const header = line.match(/^\[(.+)#[0-9A-Fa-f]{4}\]\s*$/); if (header) { section = header[1]; inputPaths.push(section); continue; } const mv = line.match(/^\s*MV\s+["\x27]?([^\s"\x27]+)/); if (mv) { inputPaths.push(mv[1]); if (section) deletedPaths.push(section); } else if (section && /^\s*REM\s*$/.test(line)) deletedPaths.push(section); } }' \
              --replace-fail 'for (const p of inputPaths) {' 'for (const p of deletedPaths) { const resolved = resolvePath(p, ctx.cwd); const ndp = rules.noDeletePaths.find((pattern) => isPathMatch(resolved, pattern, ctx.cwd)); if (ndp) { violationReason = `Deletion or move of protected path restricted: ''${ndp}`; break; } } for (const p of inputPaths) {'
            substitute "$src/extensions/tool-counter.ts" "$out/tool-counter.ts" \
              --replace-fail 'import { applyExtensionDefaults } from "./themeMap.ts";' "" \
              --replace-fail 'applyExtensionDefaults(import.meta.url, ctx);' "" \
              --replace-fail 'const model = ctx.model?.id || "no-model";' 'const latest = ctx.model?.api === "pi-virtual" ? ctx.sessionManager.getBranch().findLast((e) => e.type === "message" && e.message.role === "assistant" && e.message.stopReason !== "error" && e.message.stopReason !== "aborted") : undefined; const routed = latest?.type === "message" && latest.message.role === "assistant" ? latest.message : undefined; const model = (ctx.model?.id || "no-model") + (routed ? ` → ''${routed.model}` : "");' \
              --replace-fail 'let tokIn = 0;' 'let tokIn = 0; let tokCache = 0;' \
              --replace-fail 'tokIn += m.usage.input;' 'tokIn += m.usage.input; tokCache += m.usage.cacheRead ?? 0;' \
              --replace-fail 'theme.fg("dim", " in ") +' 'theme.fg("dim", " in ") + theme.fg("success", `''${fmt(tokCache)}`) + theme.fg("dim", " cached ") +' \
              --replace-fail 'return [line1, line2];' 'const statuses = [...footerData.getExtensionStatuses()].filter(([, value]) => value).map(([, value]) => value).join(theme.fg("dim", " · ")); return statuses ? [line1, line2, truncateToWidth(" " + statuses, width, "")] : [line1, line2];'
            substitute "$src/extensions/session-replay.ts" "$out/session-replay.ts" \
              --replace-fail 'import { applyExtensionDefaults } from "./themeMap.ts";' "" \
              --replace-fail 'applyExtensionDefaults(import.meta.url, ctx);' ""
          '';

      piPlanCmd = /* bash */ ''
        mkdir -p "$out"
        tar xzf "$src" -C "$out" --strip-components=1
        substituteInPlace "$out/src/safety.ts" \
          --replace-fail '  /^\s*bat\b/,' '  /^\s*bat\b/, /^\s*herdr\s+(status|(pane\s+(list|current|get|layout|process-info|neighbor|edges|read|wait-output)|tab\s+(list|get)|workspace\s+(list|get)|agent\s+(list|get|read|wait|explain))\b)/,'
        substituteInPlace "$out/extensions/plan/index.ts" \
          --replace-fail 'const NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write"];' "" \
          --replace-fail 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls"];' 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls", "todo", "lsp_definition", "lsp_references", "lsp_hover", "lsp_diagnostics", "aft_outline", "aft_zoom", "aft_search", "query-docs", "resolve-library-id"];' \
           --replace-fail '- You can only use: read, bash, grep, find, ls' '- You can only use: read, bash, grep, find, ls, todo, lsp_definition, lsp_references, lsp_hover, lsp_diagnostics, aft_outline, aft_zoom, aft_search, query-docs, resolve-library-id, subagent with the ${lib.concatStringsSep ", " (lib.init piHarnessAgents)} or ${lib.last piHarnessAgents} agent, subagent_wait' \
          --replace-fail 'pi.setActiveTools(PLAN_MODE_TOOLS);' "" \
          --replace-fail 'pi.setActiveTools(NORMAL_MODE_TOOLS);' 'if (!pi.getActiveTools().includes("edit")) pi.setActiveTools(pi.getAllTools().filter((t) => !t.exposure || t.exposure === "direct" || t.exposure === "model-only").map((t) => t.name));' \
          --replace-fail 'if (event.toolName === "write" || event.toolName === "edit") {' 'if (!PLAN_MODE_TOOLS.includes(event.toolName) && event.toolName !== "mcp" && event.toolName !== "subagent_wait" && !event.toolName.startsWith("mcp__") && !(event.toolName === "subagent" && ((event.input as { tasks?: { agent?: string }[] }).tasks ?? []).every((t) => [${piAgentsDq}].includes(t.agent ?? "scout")))) {' \
          --replace-fail '"Plan mode active. File modifications blocked. Use /plan to disable."' '`Plan mode active. Only ''${PLAN_MODE_TOOLS.join(", ")} are allowed, file modifications are blocked. Use /plan to disable.`' \
          --replace-fail 'ctx.ui.theme.muted(' 'ctx.ui.theme.fg("muted", ' \
          --replace-fail 'pi.sendUserMessage(refinement.trim());' 'pi.sendUserMessage(refinement.trim(), { deliverAs: "followUp" });' \
          --replace-fail 'import { extractPlanSteps } from' 'import { cleanStepText, extractPlanSteps } from' \
          --replace-fail 'markCompletedSteps,' "" \
          --replace-fail 'function persistState(): void {' 'function syncFromTodo(ctx: ExtensionContext, extra: unknown[] = []): boolean { type Todo = { id?: unknown; subject?: unknown; status?: unknown }; type Result = { role?: string; toolName?: string; details?: { action?: unknown; tasks?: Todo[] } }; const results = (messages: unknown[]) => (messages as Array<Result | undefined>).filter((m): m is Result & { details: { tasks: Todo[] } } => m?.role === "toolResult" && m.toolName === "todo" && Array.isArray(m.details?.tasks)); const branch = ctx.sessionManager.getBranch() as Array<{ type: string; customType?: string; data?: PlanState; message?: unknown }>; const start = branch.findLastIndex((e) => e.type === "custom" && e.customType === "pi-plan" && e.data?.mode !== "execute"); let ignored = new Set(results(branch.slice(0, start + 1).map((e) => e.message)).at(-1)?.details.tasks.map((t) => t.id)); let tasks: Todo[] | undefined; for (const m of results([...branch.slice(start + 1).map((e) => e.message), ...extra])) { if (m.details.action === "clear") ignored = new Set(); tasks = m.details.tasks; } if (!tasks) return false; const norm = (s: string) => cleanStepText(s.replace(/^\s*\d+\.(?!\d)\s*/, "")).toLowerCase(); let changed = false; for (const s of steps) { const task = tasks.findLast((t) => !ignored.has(t.id) && t.status !== "deleted" && typeof t.subject === "string" && (t.subject.match(/^\s*(\d+)\.(?!\d)/)?.[1] === String(s.step) || norm(t.subject) === s.text.toLowerCase())); const done = task?.status === "completed"; if (s.completed !== done) { s.completed = done; changed = true; } } return changed; } function persistState(): void {' \
          --replace-fail 'ctx.ui.setWidget("pi-plan-todos", lines);' 'ctx.ui.setWidget("pi-plan-todos", undefined);' \
          --replace-fail 'messages: event.messages.filter((m) => {' 'messages: event.messages.filter((m, i, all) => {' \
          --replace-fail 'if (msg.customType === "pi-plan-context") return false;' 'if (msg.customType === "pi-plan-context") return planMode === "execute" && i === all.findLastIndex((x) => (x as { customType?: string }).customType === "pi-plan-context" && String((x as { content?: unknown }).content).startsWith("[EXECUTING PLAN"));' \
          --replace-fail 'After completing a step, include a [DONE:n] tag in your response.' 'Track progress with the todo tool: keep one task per step with subject "N. <step text>", set it to in_progress when you start the step and to completed right after it is done. If the todo list has no tasks for these steps, create them first.' \
          --replace-fail 'if (markCompletedSteps(text, steps) > 0) {' 'if (syncFromTodo(ctx, event.toolResults)) {' \
          --replace-fail 'const { allDone } = getCompletionStats(steps);' 'if (syncFromTodo(ctx)) { updateUI(ctx); persistState(); } const { allDone } = getCompletionStats(steps);' \
          --replace-fail 'markCompletedSteps(allText, steps);' 'syncFromTodo(ctx);' \
          --replace-fail '`Execute the plan. Start with: ''${steps[0].text}`' '`Execute the plan. Track it with the todo tool: create one task per plan step with subject "N. <step text>":\n''${steps.map((s) => `''${s.step}. ''${s.text}`).join("\n")}\nSet a task to in_progress when you start the step and to completed right after it is done. Start with: ''${steps[0].text}`'
      '';

      piPlan = pkgs.runCommand "pi-plan" {
        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/pi-plan/-/pi-plan-0.1.1.tgz";
          hash = "sha256-aLu4Q64abvDSsa0w/041DG40eHuuuJH/eE9/CAwcT2o=";
        };
        passthru.command = piPlanCmd;
      } piPlanCmd;

      researchFile = pkgs.writeText "research.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

        const RESEARCH_TOOLS = ["read", "bash", "grep", "find", "ls", "lsp_definition", "lsp_references", "lsp_hover", "lsp_diagnostics", "aft_outline", "aft_zoom", "aft_search", "resolve-library-id", "query-docs", "codemode", "todo"];

        const researchPrompt = (topic: string) => `Research the question below. Do not modify anything. Do not decide what to change, where to change it or what to deliver: that comes later.

        Topic: ''${topic}

        1. Turn the topic into 1-3 concrete questions the research must answer.
        2. Pick the sources the questions need: library and API docs, RFCs and specs, the team knowledge base, GitLab merge requests and issues, the web, this codebase. Use only the ones that matter.
        3. In the codebase, study how the mechanism works today and why it was built that way (git history, merge request discussions), not where to edit it.
        4. Libraries and APIs: check the current docs with context7. Web, GitLab, knowledge base and issues: use the matching MCP tools you have.
        5. Prefer primary sources. Cross-check every claim an answer depends on. Mark what you could not confirm.

        Reply with a "## Research" report of at most 60 lines:
        - Questions
        - Answers, each with its source (path:line, commit or URL)
        - Constraints the sources impose: protocols, RFC requirements, compatibility, conventions
        - Options and trade-offs, if the sources show a choice
        - Open questions
        Do not list files to change, do not pick a deliverable and do not plan.`;

        const planPrompt = (topic: string) => `Using the research report above, plan: ''${topic}

        Pick the deliverable that fits the task: a code change, tests, a report, an OpenAPI/Swagger spec, a diagram, a table, an ADR or another artifact.
        Tests go into the plan only when the behavior can be tested, tests fit the task and the user confirmed they want them. If tests would fit, ask the user one question about it before you finish the plan. Without that confirmation, plan another way to verify the result.
        For each step say how it will be verified and which skills from your system prompt and which MCP tools it will use.`;

        const DELIVERABLE =
          "[Deliverable] Produce exactly the deliverable agreed in the plan. " +
          "Before writing a test or an artifact, check the skills listed in your system prompt and the MCP tools, and use the ones that match the format and the topic. " +
          "Write tests only if the user confirmed them in this session: write each test first, run it and confirm it fails for the expected reason, write the minimal code that makes it pass, and never weaken a test to make it pass. " +
          "For any other artifact, base every claim on the research and keep its sources.";

        type Entry = { type: string; customType?: string; data?: { mode?: string } };

        const planEntries = (ctx: ExtensionContext) =>
          (ctx.sessionManager.getBranch() as Entry[]).filter(
            (e) => e.type === "custom" && (e.customType === "pi-plan" || e.customType === "research"),
          );

        const planMode = (ctx: ExtensionContext) =>
          planEntries(ctx).findLast((e) => e.customType === "pi-plan")?.data?.mode ?? "normal";

        const researched = (ctx: ExtensionContext) => {
          for (const e of planEntries(ctx).reverse()) {
            if (e.customType === "research") return true;
            if (e.data?.mode === "normal") return false;
          }
          return false;
        };

        export default function (pi: ExtensionAPI) {
          let topic: string | undefined;
          let inPlan = false;
          let restricted = false;
          let ok = false;

          pi.registerCommand("research", {
            description: "Research any topic in code, docs and the web, then plan it in /plan with a fitting deliverable",
            handler: async (args, ctx) => {
              const text = args.trim();
              if (!text) return ctx.ui.notify("Usage: /research <topic>", "warning");
              if (!ctx.isIdle()) return ctx.ui.notify("Wait for the agent to finish", "warning");
              const mode = planMode(ctx);
              if (mode === "execute") return ctx.ui.notify("A plan is executing", "warning");
              topic = text;
              inPlan = mode === "plan";
              pi.appendEntry("research", { topic });
              restricted = !inPlan;
              const allowed = restricted ? `\n\nUntil the report is done only these tools and MCP tools are allowed, others are blocked: ''${RESEARCH_TOOLS.join(", ")}.` : "";
              pi.sendUserMessage(researchPrompt(text) + allowed);
            },
          });

          pi.on("tool_call", (event) => {
            if (!restricted || RESEARCH_TOOLS.includes(event.toolName) || event.toolName === "mcp" || event.toolName.startsWith("mcp__")) return;
            return { block: true, reason: `Research mode: only ''${RESEARCH_TOOLS.join(", ")} and MCP tools are allowed until the research report is done.` };
          });

          pi.on("agent_end", (event) => {
            if (!topic) return;
            const last = event.messages.findLast((m) => m.role === "assistant") as { stopReason?: string } | undefined;
            ok = !!last && last.stopReason !== "aborted" && last.stopReason !== "error";
          });

          pi.on("agent_settled", () => {
            if (!topic) return;
            const t = topic;
            topic = undefined;
            restricted = false;
            if (!ok) return;
            if (!inPlan) pi.sendUserMessage("/plan", { expandPromptTemplates: true });
            pi.sendUserMessage(planPrompt(t));
          });

          pi.on("context", (event, ctx) => {
            if (planMode(ctx) !== "execute" || !researched(ctx)) return;
            const i = event.messages.findLastIndex((m) => (m as { customType?: string }).customType === "pi-plan-execute");
            if (i < 0) return;
            const messages = [...event.messages];
            messages.splice(i + 1, 0, { ...messages[i], customType: "research-deliverable", content: DELIVERABLE } as (typeof messages)[number]);
            return { messages };
          });
        }
      '';

      proteiAutoFile = pkgs.writeText "protei-auto.ts" /* typescript */ ''
        import type { Api, Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
        import type { ExtensionAPI, ExtensionContext, ModelRouteRequest } from "@earendil-works/pi-coding-agent";
        import { calculateContextTokens, estimateTokens } from "@earendil-works/pi-coding-agent";
        import { readFileSync, writeFileSync, mkdirSync, renameSync, unlinkSync } from "node:fs";
        import { homedir } from "node:os";
        import { dirname, join } from "node:path";

        const CFG = {
          alpha: 0.3,
          alphaDown: 0.6,
          fastGap: 3,
          slowWallMs: 30_000,
          prefillTps: 1200,
          minTokens: 64,
          minSpanMs: 1000,
          stableSamples: 2,
          freshMs: 15 * 60_000,
          manualMs: 60 * 60_000,
          downBelow: [6, 25, 50],
          upAtLeast: [8, 30, 60],
          slowBelow: 8,
          smallFactor: 1.5,
          backAtLeast: 15,
          swapBelow: 40_000,
          swapFactor: 2,
          dwellMs: 30 * 60_000,
          headroom: 16_384,
        };
        const LEVELS = ["off", "low", "medium", "high"] as const;
        const FILE = join(homedir(), ".pi", "agent", "protei-auto.json");
        const VIRTUAL = { provider: "Protei", id: "auto" };
        const MAIN = "agent_proteya";
        const SMALL = "agent_proteya_slow";
        const TARGETS = {
          main: { provider: "Protei", id: MAIN },
          strict: { provider: "ProteiStrict", id: MAIN },
          small: { provider: "Protei", id: SMALL },
        };
        const BACKENDS = new Set(["Protei", "ProteiStrict"]);

        type Target = keyof typeof TARGETS;
        type Shared = Record<string, { ewma: number; at: number }>;
        type Entry = { type: string; customType?: string; data?: { mode?: string; active?: boolean } };

        const capFor = (v: number) => CFG.downBelow.filter((t) => v >= t).length;
        const upFor = (v: number) => CFG.upAtLeast.filter((t) => v >= t).length;
        const levelIndex = (l: string) => LEVELS.indexOf(l as (typeof LEVELS)[number]);

        const readAll = (): Shared => {
          try {
            const j = JSON.parse(readFileSync(FILE, "utf8"));
            if (j && typeof j === "object" && !Array.isArray(j)) return j as Shared;
          } catch {}
          return {};
        };

        const ewmaOf = (id: string, now = Date.now()) => {
          const e = readAll()[id];
          return e && Number.isFinite(e.ewma) && Number.isFinite(e.at) && e.at <= now && now - e.at < CFG.freshMs ? e.ewma : undefined;
        };

        const writeEwma = (id: string, ewma: number) => {
          const tmp = `''${FILE}.''${process.pid}.''${Math.random().toString(36).slice(2)}.tmp`;
          try {
            mkdirSync(dirname(FILE), { recursive: true });
            writeFileSync(tmp, JSON.stringify({ ...readAll(), [id]: { ewma, at: Date.now() } }));
            renameSync(tmp, FILE);
          } catch {
            try {
              unlinkSync(tmp);
            } catch {}
          }
        };

        const contextTokens = (messages: ModelRouteRequest["messages"]) => {
          const i = messages.findLastIndex((m) => m.role === "assistant" && m.stopReason !== "error" && m.stopReason !== "aborted");
          const last = i >= 0 ? messages[i] : undefined;
          const base = last?.role === "assistant" ? calculateContextTokens(last.usage) : 0;
          return messages.slice(i + 1).reduce((sum, m) => sum + estimateTokens(m), base);
        };

        const planMode = (ctx: ExtensionContext) =>
          (ctx.sessionManager.getBranch() as Entry[]).findLast((e) => e.type === "custom" && e.customType === "pi-plan")?.data?.mode ?? "normal";

        const reviewActive = (ctx: ExtensionContext, messages: ModelRouteRequest["messages"]) => {
          const state = (ctx.sessionManager.getBranch() as Entry[]).findLast((e) => e.type === "custom" && e.customType === "review-session");
          if (state?.data?.active) return true;
          const user = messages.findLast((m) => m.role === "user");
          if (user?.role !== "user") return false;
          const text = typeof user.content === "string" ? user.content : user.content.find((c) => c.type === "text")?.text;
          return text?.startsWith("# Review Guidelines") ?? false;
        };

        const E2E = (id: string) => `''${id}:e2e`;

        const isVirtual = (m: { provider: string; id: string } | undefined) => m?.provider === VIRTUAL.provider && m.id === VIRTUAL.id;

        export default function (pi: ExtensionAPI) {
          let pool: "main" | "small" = "main";
          let since = 0;
          let probe = false;
          let routed: Target = "main";
          let auto: number | undefined;
          let selected: string | undefined;
          let manual: { level: number; at: number } | undefined;
          let upTarget = -1;
          let upCount = 0;
          let first = 0;
          let last = 0;
          let chars = 0;
          let review = false;
          let lastMain = Date.now();
          let usage: { ctx: number; hit: number } | undefined;

          const backend = () => TARGETS[routed].id;

          const manualLeft = (now = Date.now()) => {
            if (manual && now - manual.at >= CFG.manualMs) {
              auto = manual.level;
              manual = undefined;
            }
            return manual ? Math.ceil((CFG.manualMs - (now - manual.at)) / 60_000) : 0;
          };

          const target = (v: number, cur: number) => {
            const cap = capFor(v);
            const up = upFor(v);
            return cap < cur ? cap : up > cur ? up : cur;
          };

          const level = (now = Date.now()) => (manual && manualLeft(now) ? manual.level : (auto ?? 1));

          const show = (ctx: ExtensionContext) => {
            if (!ctx.hasUI) return;
            if (!isVirtual(ctx.model)) return ctx.ui.setStatus("protei-auto", undefined);
            const v = ewmaOf(backend());
            const lvl = LEVELS[level()];
            const left = manualLeft();
            const mode = review ? "review" : left ? `manual ''${left}m` : "auto";
            const e2e = ewmaOf(E2E(backend()));
            const speed = v === undefined ? "" : ` ''${Math.round(v)} tok/s''${e2e === undefined ? "" : ` (e2e ''${Math.round(e2e)})`}`;
            const load = usage ? ` · ctx ''${Math.round(usage.ctx / 1000)}k cache ''${Math.round(usage.hit * 100)}%` : "";
            ctx.ui.setStatus("protei-auto", `''${routed}''${probe ? " probe" : ""}''${speed} · ''${review ? "high" : lvl} ''${mode}''${load}`);
          };

          const reset = () => {
            pool = "main";
            since = 0;
            probe = false;
            routed = "main";
            auto = undefined;
            manual = undefined;
            upTarget = -1;
            upCount = 0;
            review = false;
            lastMain = Date.now();
            usage = undefined;
          };

          const choosePool = (now: number) => {
            const main = ewmaOf(E2E(MAIN), now);
            const small = ewmaOf(E2E(SMALL), now);
            const dwelt = now - since >= CFG.dwellMs;
            if (probe) return;
            if (pool === "main") {
              const slow = main !== undefined && main < CFG.slowBelow && (small === undefined || small >= CFG.smallFactor * main);
              const silent = main === undefined && small !== undefined && small >= CFG.upAtLeast[0] && now - lastMain > CFG.freshMs;
              const urgent = main !== undefined && small !== undefined && (main < CFG.slowBelow / 2 || small >= CFG.fastGap * main);
              if ((dwelt || urgent) && (slow || silent)) {
                pool = "small";
                since = now;
              }
              return;
            }
            if (!dwelt) return;
            if (main !== undefined && main >= CFG.backAtLeast) {
              pool = "main";
              since = now;
            } else if (main === undefined) {
              pool = "main";
              since = now;
              probe = true;
            }
          };

          const retarget = (next: Target) => {
            const prev = TARGETS[routed].id;
            routed = next;
            if (TARGETS[next].id === prev || auto === undefined) return;
            const v = ewmaOf(TARGETS[next].id);
            if (v !== undefined) auto = target(v, auto);
            upTarget = -1;
            upCount = 0;
          };

          const poolSample = (id: string, speed: number) => {
            const base = ewmaOf(E2E(id));
            const a = base !== undefined && speed < base ? CFG.alphaDown : CFG.alpha;
            const ewma = base === undefined ? speed : a * speed + (1 - a) * base;
            writeEwma(E2E(id), ewma);
            if (id === MAIN) lastMain = Date.now();
            if (id === MAIN && probe) {
              probe = false;
              if (ewma < CFG.slowBelow) {
                pool = "small";
                since = Date.now();
              }
            }
          };

          const sample = (id: string, speed: number) => {
            const base = ewmaOf(id);
            const ewma = base === undefined ? speed : CFG.alpha * speed + (1 - CFG.alpha) * base;
            writeEwma(id, ewma);
            if (id !== backend() || auto === undefined) return;
            if (manual && manualLeft()) {
              if (capFor(ewma) <= manual.level - 2) {
                manual = undefined;
                auto = capFor(ewma);
              }
              upCount = 0;
              return;
            }
            const t = target(ewma, auto);
            if (t > auto) {
              upCount = t === upTarget ? upCount + 1 : 1;
              upTarget = t;
              if (upCount >= CFG.stableSamples) {
                auto = t;
                upCount = 0;
              }
            } else {
              upCount = 0;
              auto = t;
            }
          };

          pi.registerVirtualModel({
            provider: VIRTUAL.provider,
            id: VIRTUAL.id,
            name: "Protei auto",
            thinkingLevels: [...LEVELS],
            contextWindow: 131072,
            maxTokens: 8192,
            route(request, ctx) {
              const now = Date.now();
              const find = (t: Target) => {
                const m = ctx.modelRegistry.find(TARGETS[t].provider, TARGETS[t].id);
                if (!m) throw new Error(`Model ''${TARGETS[t].provider}/''${TARGETS[t].id} is not in the catalog`);
                return m;
              };
              const keyOf = (m: { provider: string; id: string }) =>
                (Object.keys(TARGETS) as Target[]).find((t) => TARGETS[t].provider === m.provider && TARGETS[t].id === m.id);
              if (request.reason === "direct") {
                const big = contextTokens(request.messages) > Math.min(find("main").contextWindow, find("small").contextWindow) - CFG.headroom;
                const key = request.previous && keyOf(request.previous.model);
                const next: Target = key ? (big && key !== "strict" ? "strict" : key) : big || planMode(ctx) === "plan" ? "strict" : pool;
                return { model: find(next), thinkingLevel: request.thinkingLevel };
              }
              review = reviewActive(ctx, request.messages);
              const sticky = request.reason === "retry" ? request.failed : request.reason === "user" ? undefined : request.previous;
              const stickyKey = sticky && keyOf(sticky.model);
              const stickyLevel = sticky?.thinkingLevel;
              const forced: ModelThinkingLevel = "high";
              const limit = Math.min(find("main").contextWindow, find("small").contextWindow) - CFG.headroom;
              const big = contextTokens(request.messages) > limit;
              if (sticky && stickyKey && stickyLevel && levelIndex(stickyLevel) >= 0) {
                const continuation = request.reason === "continuation";
                const forceStrict = continuation && stickyKey !== "strict" && big;
                const leavePlan = continuation && stickyKey === "strict" && !big && planMode(ctx) !== "plan";
                const other = stickyKey === "main" ? SMALL : MAIN;
                const cur = ewmaOf(E2E(TARGETS[stickyKey].id), now);
                const alt = ewmaOf(E2E(other), now);
                const slowNow = cur !== undefined && cur < CFG.slowBelow && (alt === undefined || alt >= CFG.smallFactor * cur);
                const worth = contextTokens(request.messages) < CFG.swapBelow || slowNow || (cur !== undefined && alt !== undefined && alt >= CFG.swapFactor * cur);
                const swap = continuation && stickyKey !== "strict" && worth;
                if (!forceStrict && (swap || leavePlan)) choosePool(now);
                retarget(forceStrict ? "strict" : leavePlan || swap ? pool : stickyKey);
                show(ctx);
                return { model: find(routed), thinkingLevel: review ? forced : stickyLevel };
              }
              if (!review) {
                if (selected !== undefined && request.thinkingLevel !== selected && levelIndex(request.thinkingLevel) >= 0) {
                  manual = { level: levelIndex(request.thinkingLevel), at: now };
                  upCount = 0;
                }
                selected = request.thinkingLevel;
                if (auto === undefined) auto = Math.max(0, levelIndex(request.thinkingLevel));
              }
              const strict = big || planMode(ctx) === "plan";
              if (!strict) choosePool(now);
              retarget(strict ? "strict" : pool);
              const model: Model<Api> = find(routed);
              const thinkingLevel: ModelThinkingLevel = review ? forced : LEVELS[level(now)];
              show(ctx);
              return { model, thinkingLevel };
            },
          });

          pi.on("session_start", async (_e, ctx) => {
            reset();
            selected = isVirtual(ctx.model) ? pi.getThinkingLevel() : undefined;
            show(ctx);
          });

          pi.on("model_select", async (e, ctx) => {
            selected = isVirtual(e.model) ? pi.getThinkingLevel() : undefined;
            show(ctx);
          });

          pi.on("thinking_level_select", async (e, ctx) => {
            if (!isVirtual(ctx.model) || selected === undefined || e.level === selected) return;
            selected = e.level;
            const l = levelIndex(e.level);
            if (l >= 0) manual = { level: l, at: Date.now() };
            upCount = 0;
            show(ctx);
          });

          pi.on("message_start", async () => {
            first = 0;
            last = 0;
            chars = 0;
          });

          pi.on("message_update", async (e) => {
            const ev = e.assistantMessageEvent;
            if (ev.type !== "thinking_delta" && ev.type !== "text_delta" && ev.type !== "toolcall_delta") return;
            const now = Date.now();
            if (!first) first = now;
            last = now;
            chars += ev.delta.length;
          });

          pi.on("message_end", async (e, ctx) => {
            if (e.message.role !== "assistant" || !first) return;
            const msg = e.message;
            const tokens = msg.usage?.output || chars / 4;
            const span = last - first;
            const wall = Date.now() - msg.timestamp;
            const seen = (msg.usage?.input ?? 0) + (msg.usage?.cacheRead ?? 0);
            if (seen > 0) usage = { ctx: seen, hit: (msg.usage?.cacheRead ?? 0) / seen };
            first = 0;
            const failed = msg.stopReason === "error" && !/terminated/i.test(msg.errorMessage ?? "");
            if (!BACKENDS.has(msg.provider) || msg.stopReason === "aborted" || failed) return;
            const busy = Math.max(wall - ((msg.usage?.input ?? 0) / CFG.prefillTps) * 1000, wall * 0.2);
            if (wall > 0 && (tokens >= CFG.minTokens || wall >= CFG.slowWallMs)) poolSample(msg.model, tokens / (busy / 1000));
            if (msg.stopReason === "error") return show(ctx);
            if (tokens >= CFG.minTokens && span >= CFG.minSpanMs) sample(msg.model, tokens / (span / 1000));
            show(ctx);
          });

          pi.on("turn_end", async (_e, ctx) => show(ctx));
        }
      '';

      piReview = pkgs.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi-review";
        rev = "f1de050504936046c0f85b21fec0e0a93ef394eb";
        hash = "sha256-bvdJjLudTd9YQF8ip30jIvi6MY3MAcw5GXVONx1DLuQ=";
      };

      nvimFile = pkgs.writeText "nvim.ts" /* typescript */ ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
        import { writeFileSync } from "node:fs";

        export default function (pi: ExtensionAPI) {
          pi.registerCommand("nvim", {
            description: "Закрыть pi и продолжить текущую сессию в Neovim. Аргументы — файлы, которые нужно открыть",
            handler: async (args, ctx) => {
              if (process.env.NVIM) {
                ctx.ui.notify("pi уже запущен внутри Neovim — используй <leader>At, а не /nvim", "warning");
                return;
              }
              const handoff = process.env.PI_NVIM_HANDOFF;
              if (!handoff) {
                ctx.ui.notify("Передача сессии недоступна: pi запущен не через обёртку из dotfiles", "warning");
                return;
              }
              const files = args
                .split(/\s+/)
                .filter(Boolean)
                .map((file) => file.replace(/^@/, ""));
              writeFileSync(handoff, JSON.stringify({ session: ctx.sessionManager.getSessionFile() ?? null, files }));
              ctx.shutdown();
            },
          });
        }
      '';

      piStats = pkgs.writeShellScriptBin "pi-stats" ''
        exec ${pkgs.python3}/bin/python3 ${
          pkgs.writeText "pi-stats.py" /* python */ ''
            import json
            import statistics
            import sys
            import time
            from collections import defaultdict
            from datetime import datetime
            from pathlib import Path

            days = int(sys.argv[1]) if len(sys.argv) > 1 else 7
            since = time.time() - days * 86400
            root = Path.home() / ".pi/agent/sessions"
            last_cut = {}
            rows = defaultdict(lambda: {"req": 0, "speed": [], "inp": 0, "hit": 0, "ctx": [], "small": 0, "strict": 0, "cut": 0, "err": 0, "tools": 0, "terr": 0, "blocked": 0, "comp": 0, "mask": 0})


            def day(ts):
                return time.strftime("%m-%d", time.localtime(ts))


            for f in root.glob("*/*.jsonl"):
                if f.stat().st_mtime < since:
                    continue
                for line in f.open():
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    ts = datetime.fromisoformat(e.get("timestamp", "1970-01-01T00:00:00+00:00").replace("Z", "+00:00")).timestamp()
                    if ts < since:
                        continue
                    r = rows[day(ts)]
                    if e.get("type") == "compaction":
                        r["comp"] += 1
                    if e.get("type") == "custom" and e.get("customType") == "context-keeper":
                        cutoff = (e.get("data") or {}).get("cutoff")
                        r["mask"] += cutoff is not None and cutoff != last_cut.get(f)
                        last_cut[f] = cutoff
                    m = e.get("message") or {}
                    if e.get("type") != "message":
                        continue
                    if m.get("role") == "toolResult":
                        r["tools"] += 1
                        r["terr"] += bool(m.get("isError"))
                        text = json.dumps(m.get("content"))
                        first = ((m.get("content") or [{}])[0] or {}).get("text", "") if isinstance(m.get("content"), list) else str(m.get("content"))
                        r["blocked"] += bool(m.get("isError")) and first.startswith(("Blocked: this", "Skipped: you already ran"))
                    if m.get("role") != "assistant" or "Protei" not in str(m.get("provider")):
                        continue
                    u = m.get("usage") or {}
                    seen = (u.get("input") or 0) + (u.get("cacheRead") or 0)
                    r["req"] += 1
                    r["inp"] += seen
                    r["hit"] += u.get("cacheRead") or 0
                    if seen:
                        r["ctx"].append(seen)
                    r["small"] += m.get("model") == "agent_proteya_slow"
                    r["strict"] += m.get("provider") == "ProteiStrict"
                    r["err"] += m.get("stopReason") == "error"
                    r["cut"] += "terminated" in str(m.get("errorMessage", ""))
                    wall = ts - (m.get("timestamp") or 0) / 1000
                    if 0 < wall < 3600 and (u.get("output") or 0) > 0:
                        r["speed"].append(u["output"] / wall)

            print(f"{'day':5} {'req':>5} {'e2e/s':>6} {'cache':>6} {'ctx p50':>8} {'small':>6} {'strict':>6} {'err':>4} {'cut':>4} {'tool err':>8} {'blocked':>7} {'comp':>5} {'mask':>5}")
            for d in sorted(rows):
                r = rows[d]
                if not r["req"]:
                    continue
                speed = statistics.median(r["speed"]) if r["speed"] else 0
                hit = r["hit"] / r["inp"] if r["inp"] else 0
                ctx = statistics.median(r["ctx"]) / 1000
                terr = r["terr"] / r["tools"] if r["tools"] else 0
                print(f"{d:5} {r['req']:5} {speed:6.1f} {hit:6.0%} {ctx:7.0f}k {r['small'] / r['req']:6.0%} {r['strict'] / r['req']:6.0%} {r['err']:4} {r['cut']:4} {terr:8.0%} {r['blocked']:7} {r['comp']:5} {r['mask']:5}")
          ''
        } "$@"
      '';

      piPipelineView = pkgs.writeShellScriptBin "pi-pipeline-view" ''
        exec ${pkgs.python3}/bin/python3 ${
          pkgs.writeText "pi-pipeline-view.py" /* python */ ''
            import json
            import os
            import queue
            import threading
            import time
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
            from pathlib import Path

            EVENTS = Path(os.environ.get("PI_PIPELINE_EVENTS") or Path.home() / ".pi/agent/pipeline/events.jsonl")
            SESSIONS = Path.home() / ".pi/agent/sessions"
            PORT = int(os.environ.get("PI_PIPELINE_PORT", "8517"))

            nodes = {}
            clients = set()
            lock = threading.Lock()


            def ingest(line):
                try:
                    e = json.loads(line)
                except ValueError:
                    return None
                if not isinstance(e, dict) or not e.get("id"):
                    return None
                e["parents"] = [p for p in (e.get("parents") or []) if isinstance(p, str)]
                old = nodes.get(e["id"])
                if old:
                    e = {**old, **e, "start": old.get("start", old.get("ts"))}
                else:
                    e["start"] = e.get("ts")
                nodes[e["id"]] = e
                return e


            def tail():
                pos = 0
                buf = b""
                while True:
                    try:
                        size = EVENTS.stat().st_size
                    except OSError:
                        time.sleep(0.5)
                        continue
                    if size < pos:
                        pos = 0
                        buf = b""
                        with lock:
                            nodes.clear()
                        push({"reset": True})
                    if size > pos:
                        with EVENTS.open("rb") as f:
                            f.seek(pos)
                            chunk = f.read()
                        pos += len(chunk)
                        buf += chunk
                        *lines, buf = buf.split(b"\n")
                        batch = []
                        with lock:
                            for raw in lines:
                                e = ingest(raw.decode("utf-8", "replace"))
                                if e:
                                    batch.append(e)
                        if batch:
                            push({"nodes": list({n["id"]: n for n in batch}.values())})
                    time.sleep(0.4)


            def push(payload):
                data = json.dumps(payload)
                with lock:
                    for q in list(clients):
                        q.put(data)


            def find_session(sid):
                if not sid or not all(c.isalnum() or c in "-_" for c in sid):
                    return None
                for f in SESSIONS.glob(f"**/*{sid}*.jsonl"):
                    return f
                for f in SESSIONS.glob("**/*.jsonl"):
                    try:
                        with f.open() as fh:
                            if json.loads(fh.readline()).get("id") == sid:
                                return f
                    except (ValueError, OSError):
                        continue
                return None


            def text_of(content):
                if isinstance(content, str):
                    return content
                out = []
                for b in content or []:
                    if isinstance(b, dict):
                        if b.get("type") == "text":
                            out.append(b.get("text", ""))
                        elif b.get("type") == "toolCall":
                            out.append(f"[tool {b.get('name')}]")
                return " ".join(out)


            def session_tail(sid):
                f = find_session(sid)
                if not f:
                    return None
                msgs = []
                for line in f.open():
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    m = e.get("message")
                    if e.get("type") == "message" and isinstance(m, dict):
                        msgs.append({"role": m.get("role"), "text": text_of(m.get("content"))[:300]})
                return msgs[-40:]


            PAGE = r"""<!doctype html>
            <html><head><meta charset="utf-8"><title>pi pipeline</title>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
            :root{--bg:#fafafa;--fg:#1d2024;--mut:#6b7280;--card:#fff;--bd:#d8dce2;--run:#2563eb;--ok:#16a34a;--fail:#dc2626;--skip:#9ca3af}
            @media(prefers-color-scheme:dark){:root{--bg:#14161a;--fg:#e5e7eb;--mut:#9aa1ac;--card:#1d2026;--bd:#333943;--run:#60a5fa;--ok:#4ade80;--fail:#f87171;--skip:#6b7280}}
            *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:13px system-ui,sans-serif;display:flex;height:100vh}
            #runs{width:260px;border-right:1px solid var(--bd);overflow:auto}
            #runs div{padding:8px 10px;border-bottom:1px solid var(--bd);cursor:pointer}
            #runs div.sel{background:var(--card)}#runs small{color:var(--mut);display:block}
            .dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:6px}
            #main{flex:1;overflow:auto;position:relative}#side{width:340px;border-left:1px solid var(--bd);overflow:auto;padding:10px;background:var(--card)}
            #side pre{white-space:pre-wrap;word-break:break-word;margin:4px 0;padding:6px;border:1px solid var(--bd);border-radius:4px;font-size:12px}
            #side h3{margin:0 0 6px}#side dt{color:var(--mut);margin-top:6px}#side dd{margin:0;word-break:break-all}
            svg text{fill:var(--fg);font:11px system-ui,sans-serif}svg .lane{fill:none;stroke:var(--bd);stroke-dasharray:4 4}
            svg .edge{fill:none;stroke:var(--mut);stroke-width:1.3}svg .nd{fill:var(--card);stroke-width:2;cursor:pointer}
            svg .nd.sel{stroke-width:4}svg .lt{fill:var(--mut)}
            .run{stroke:var(--run)}.ok{stroke:var(--ok)}.fail{stroke:var(--fail)}.skipped{stroke:var(--skip)}
            .b-run{background:var(--run)}.b-ok{background:var(--ok)}.b-fail{background:var(--fail)}.b-skipped{background:var(--skip)}
            #empty{padding:20px;color:var(--mut)}
            </style></head><body>
            <div id="runs"></div><div id="main"><div id="empty">waiting for events</div></div><div id="side"><div style="color:var(--mut)">click a node</div></div>
            <script>
            const nodes = new Map();
            let sel = null, selNode = null, dirty = false;
            const NS = 'http://www.w3.org/2000/svg';
            const $ = id => document.getElementById(id);
            const base = p => (p || ''').split('/').filter(Boolean).pop() || '/';
            const cls = s => s === 'running' ? 'run' : s;
            const fmt = t => t ? new Date(t).toLocaleTimeString() : ''';

            function runs() {
              const m = new Map();
              for (const n of nodes.values()) {
                const r = m.get(n.run) || {run: n.run, ts: 0, cwd: n.cwd, st: 'ok', count: 0};
                r.ts = Math.max(r.ts, n.ts || 0); r.count++;
                if (n.status === 'running') r.st = 'running';
                else if (n.status === 'fail' && r.st !== 'running') r.st = 'fail';
                if (n.kind === 'run') r.cwd = n.cwd;
                m.set(n.run, r);
              }
              return [...m.values()].sort((a, b) => b.ts - a.ts);
            }

            function drawRuns() {
              const box = $('runs'); box.textContent = ''';
              for (const r of runs()) {
                const d = document.createElement('div');
                if (r.run === sel) d.className = 'sel';
                const dot = document.createElement('span'); dot.className = 'dot b-' + cls(r.st);
                d.append(dot, document.createTextNode(r.run.slice(0, 24)));
                const s = document.createElement('small'); s.textContent = base(r.cwd) + ' / ' + r.count + ' nodes / ' + fmt(r.ts);
                d.append(s); d.onclick = () => { sel = r.run; selNode = null; dirty = true; };
                box.append(d);
              }
            }

            function layout(list) {
              const byId = new Map(list.map(n => [n.id, n]));
              const depth = new Map();
              const visit = (n, seen) => {
                if (depth.has(n.id)) return depth.get(n.id);
                if (seen.has(n.id)) return 0;
                seen.add(n.id);
                let d = 0;
                for (const p of n.parents) if (byId.has(p)) d = Math.max(d, visit(byId.get(p), seen) + 1);
                depth.set(n.id, d); seen.delete(n.id);
                return d;
              };
              for (const n of list) visit(n, new Set());
              const lanes = [...new Set(list.map(n => n.cwd || '''))].sort();
              const pos = new Map(); const rows = {};
              const order = [...list].sort((a, b) => depth.get(a.id) - depth.get(b.id) || (a.start || 0) - (b.start || 0));
              const laneTop = []; let y = 30;
              for (const l of lanes) {
                const mine = order.filter(n => (n.cwd || ''') === l);
                const used = new Map();
                let maxRow = 0;
                for (const n of mine) {
                  const d = depth.get(n.id), k = used.get(d) || 0; used.set(d, k + 1);
                  maxRow = Math.max(maxRow, k);
                  pos.set(n.id, {x: 40 + d * 190, row: k});
                }
                laneTop.push({l, y, h: (maxRow + 1) * 56 + 14});
                for (const n of mine) { const p = pos.get(n.id); p.y = y + 24 + p.row * 56; }
                y += (maxRow + 1) * 56 + 30;
              }
              let w = 0; for (const p of pos.values()) w = Math.max(w, p.x + 170);
              return {pos, laneTop, w, h: y};
            }

            function el(tag, attrs, text) {
              const e = document.createElementNS(NS, tag);
              for (const k in attrs) e.setAttribute(k, attrs[k]);
              if (text != null) e.textContent = text;
              return e;
            }

            function shape(n, p) {
              const c = 'nd ' + cls(n.status) + (n.id === selNode ? ' sel' : ''');
              const x = p.x, y = p.y;
              if (n.kind === 'gate') return el('polygon', {class: c, points: `''${x + 70},''${y - 20} ''${x + 140},''${y} ''${x + 70},''${y + 20} ''${x},''${y}`});
              if (n.kind === 'join') return el('polygon', {class: c, points: `''${x + 14},''${y - 18} ''${x + 126},''${y - 18} ''${x + 140},''${y} ''${x + 126},''${y + 18} ''${x + 14},''${y + 18} ''${x},''${y}`});
              if (n.kind === 'agent') return el('rect', {class: c, x, y: y - 18, width: 140, height: 36, rx: 18});
              if (n.kind === 'phase') return el('rect', {class: c, x, y: y - 18, width: 140, height: 36, rx: 2});
              if (n.kind === 'run') return el('rect', {class: c, x, y: y - 18, width: 140, height: 36, rx: 8});
              return el('rect', {class: c, x, y: y - 18, width: 140, height: 36, rx: 6});
            }

            function drawGraph() {
              const box = $('main'); box.textContent = ''';
              const list = [...nodes.values()].filter(n => n.run === sel);
              if (!list.length) { const e = document.createElement('div'); e.id = 'empty'; e.textContent = 'no run selected'; box.append(e); return; }
              const {pos, laneTop, w, h} = layout(list);
              const svg = el('svg', {width: Math.max(w, 400), height: h + 20});
              for (const t of laneTop) {
                svg.append(el('rect', {class: 'lane', x: 4, y: t.y, width: Math.max(w, 400) - 8, height: t.h, rx: 6}));
                svg.append(el('text', {class: 'lt', x: 10, y: t.y + 12}, base(t.l) + (t.l ? '  ' + t.l : ''')));
              }
              for (const n of list) for (const par of n.parents) {
                const a = pos.get(par), b = pos.get(n.id);
                if (!a || !b) continue;
                const x1 = a.x + 140, x2 = b.x, mx = (x1 + x2) / 2;
                svg.append(el('path', {class: 'edge', d: `M''${x1},''${a.y} C''${mx},''${a.y} ''${mx},''${b.y} ''${x2},''${b.y}`}));
              }
              for (const n of list) {
                const p = pos.get(n.id);
                const g = el('g', {});
                g.append(shape(n, p));
                g.append(el('text', {x: p.x + 8, y: p.y - 3}, (n.label || n.id).slice(0, 22)));
                g.append(el('text', {class: 'lt', x: p.x + 8, y: p.y + 10}, n.kind + (n.phase ? ' / ' + n.phase : ''')));
                g.onclick = () => { selNode = n.id; dirty = true; showNode(n); };
                svg.append(g);
              }
              box.append(svg);
            }

            async function showNode(n) {
              const s = $('side'); s.textContent = ''';
              const h = document.createElement('h3'); h.textContent = n.label || n.id; s.append(h);
              const dl = document.createElement('dl');
              const row = (k, v) => { if (v == null || v === ''') return; const t = document.createElement('dt'); t.textContent = k; const d = document.createElement('dd'); d.textContent = v; dl.append(t, d); };
              row('kind', n.kind); row('status', n.status); row('phase', n.phase); row('detail', n.detail);
              row('cwd', n.cwd); row('sessionId', n.sessionId); row('id', n.id); row('parents', n.parents.join(', '));
              row('started', n.start ? new Date(n.start).toLocaleString() : '''); row('updated', n.ts ? new Date(n.ts).toLocaleString() : ''');
              if (n.start && n.ts) row('duration', ((n.ts - n.start) / 1000).toFixed(1) + 's');
              s.append(dl);
              if (!n.sessionId) return;
              try {
                const r = await fetch('/session/' + encodeURIComponent(n.sessionId));
                if (!r.ok) { const p = document.createElement('pre'); p.textContent = 'session not found'; s.append(p); return; }
                for (const m of await r.json()) { const p = document.createElement('pre'); p.textContent = m.role + ': ' + m.text; s.append(p); }
              } catch (e) {}
            }

            function render() {
              if (!dirty) return;
              dirty = false;
              if (!sel) { const r = runs(); if (r.length) sel = r[0].run; }
              drawRuns(); drawGraph();
              if (selNode && nodes.has(selNode)) { const n = nodes.get(selNode); if (n.status === 'running') showNode(n); }
            }
            setInterval(render, 250);

            const es = new EventSource('/events');
            es.onmessage = ev => {
              const d = JSON.parse(ev.data);
              if (d.reset) nodes.clear();
              for (const n of d.nodes || []) nodes.set(n.id, n);
              dirty = true;
            };
            </script></body></html>
            """


            class Handler(BaseHTTPRequestHandler):
                def log_message(self, *a):
                    pass

                def send(self, code, ctype, body):
                    self.send_response(code)
                    self.send_header("Content-Type", ctype)
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def do_GET(self):
                    path = self.path.split("?")[0]
                    if path == "/":
                        self.send(200, "text/html; charset=utf-8", PAGE.encode())
                    elif path == "/events":
                        self.stream()
                    elif path.startswith("/session/"):
                        msgs = session_tail(path[len("/session/"):])
                        if msgs is None:
                            self.send(404, "application/json", b'{"error":"session not found"}')
                        else:
                            self.send(200, "application/json", json.dumps(msgs).encode())
                    else:
                        self.send(404, "text/plain", b"not found")

                def stream(self):
                    q = queue.Queue()
                    with lock:
                        snap = list(nodes.values())
                        clients.add(q)
                    self.send_response(200)
                    self.send_header("Content-Type", "text/event-stream")
                    self.send_header("Cache-Control", "no-cache")
                    self.end_headers()
                    try:
                        self.wfile.write(b"data: " + json.dumps({"reset": True, "nodes": snap}).encode() + b"\n\n")
                        self.wfile.flush()
                        while True:
                            try:
                                data = q.get(timeout=15)
                                self.wfile.write(b"data: " + data.encode() + b"\n\n")
                            except queue.Empty:
                                self.wfile.write(b": ping\n\n")
                            self.wfile.flush()
                    except OSError:
                        pass
                    finally:
                        with lock:
                            clients.discard(q)


            if __name__ == "__main__":
                threading.Thread(target=tail, daemon=True).start()
                srv = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
                srv.daemon_threads = True
                print(f"pi-pipeline-view: http://127.0.0.1:{PORT}")
                try:
                    srv.serve_forever()
                except KeyboardInterrupt:
                    pass
          ''
        } "$@"
      '';

      piEval = pkgs.writeShellScriptBin "pi-eval" ''
        exec ${pkgs.python3}/bin/python3 ${
          pkgs.writeText "pi-eval.py" /* python */ ''
            import argparse
            import hashlib
            import json
            import os
            import shutil
            import statistics
            import subprocess
            import sys
            import tarfile
            import time
            import io
            from collections import defaultdict
            from pathlib import Path

            HOME = Path.home()
            TASKS = HOME / ".pi/eval/tasks.jsonl"
            RESULTS = HOME / ".pi/eval/results.jsonl"
            TREES = HOME / ".pi/worktrees"


            def git(repo, *args, check=True, env=None):
                r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True, env=env)
                if check and r.returncode:
                    raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
                return r.stdout


            def task_id(repo, commit):
                return hashlib.sha1(f"{repo}:{commit}".encode()).hexdigest()[:8]


            def load_tasks():
                if not TASKS.exists():
                    return []
                out = []
                for line in TASKS.open():
                    try:
                        out.append(json.loads(line))
                    except ValueError:
                        continue
                return out


            def mine(args):
                repo = Path(args.repo).expanduser().resolve()
                commits = git(repo, "log", "--no-merges", "--format=%H", "-n", str(args.scan)).split()
                found = []
                for c in commits:
                    stat = git(repo, "show", "--numstat", "--format=", c).splitlines()
                    files = []
                    lines = 0
                    for s in stat:
                        parts = s.split("\t")
                        if len(parts) != 3:
                            continue
                        add, rem, name = parts
                        if add == "-":
                            continue
                        lines += int(add) + int(rem)
                        files.append(name)
                    go = [f for f in files if f.endswith(".go")]
                    tests = [f for f in go if f.endswith("_test.go")]
                    if not tests or len(go) == len(tests) or lines >= 300:
                        continue
                    pkgs = sorted({"./" + str(Path(t).parent) if str(Path(t).parent) != "." else "." for t in tests})
                    subject = git(repo, "show", "-s", "--format=%s", c).strip()
                    found.append({"repo": str(repo), "commit": c, "subject": subject, "tests": tests, "pkgs": pkgs})
                    if len(found) >= args.n:
                        break
                for t in found:
                    print(json.dumps(t, ensure_ascii=False))
                if args.add:
                    have = {(t["repo"], t["commit"]) for t in load_tasks()}
                    TASKS.parent.mkdir(parents=True, exist_ok=True)
                    with TASKS.open("a") as f:
                        for t in found:
                            if (t["repo"], t["commit"]) not in have:
                                t["id"] = task_id(t["repo"], t["commit"])
                                f.write(json.dumps(t, ensure_ascii=False) + "\n")


            def extract(repo, rev, dest, paths=None):
                cmd = ["git", "-C", str(repo), "archive", "--format=tar", rev]
                if paths:
                    cmd += ["--", *paths]
                data = subprocess.run(cmd, capture_output=True, check=True).stdout
                with tarfile.open(fileobj=io.BytesIO(data)) as t:
                    t.extractall(dest, filter="data")


            def parse_events(out):
                tokens = 0
                calls = 0
                for line in out.splitlines():
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    if e.get("type") == "tool_execution_start":
                        calls += 1
                    if e.get("type") == "message_end":
                        m = e.get("message") or {}
                        if m.get("role") == "assistant":
                            u = m.get("usage") or {}
                            tokens += u.get("totalTokens") or ((u.get("input") or 0) + (u.get("output") or 0) + (u.get("cacheRead") or 0))
                return tokens, calls


            def run_task(t, timeout, label):
                repo = Path(t["repo"])
                tid = t["id"]
                tree = TREES / f"eval-{tid}"
                if tree.exists():
                    shutil.rmtree(tree)
                tree.mkdir(parents=True)
                res = {"id": tid, "label": label, "repo": t["repo"], "commit": t["commit"], "ts": time.time()}
                try:
                    extract(repo, t["commit"] + "^", tree)
                    env = {**os.environ, "GIT_AUTHOR_NAME": "eval", "GIT_AUTHOR_EMAIL": "eval@localhost", "GIT_COMMITTER_NAME": "eval", "GIT_COMMITTER_EMAIL": "eval@localhost"}
                    git(tree, "init", "-q")
                    git(tree, "add", "-A")
                    git(tree, "-c", "commit.gpgsign=false", "commit", "-q", "-m", "baseline", env=env)
                    body = "В этом Go-репозитории есть баг. Найди его и исправь."
                    start = time.time()
                    timed_out = False
                    try:
                        p = subprocess.run(["pi", "-p", "--mode", "json", "--no-session", body], cwd=tree, capture_output=True, text=True, timeout=timeout)
                        out = p.stdout
                    except subprocess.TimeoutExpired as e:
                        timed_out = True
                        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
                    res["wall"] = round(time.time() - start, 1)
                    res["timeout"] = timed_out
                    res["tokens"], res["tool_calls"] = parse_events(out)
                    res["diff_lines"] = sum(
                        int(x) for l in git(tree, "diff", "--numstat", "HEAD").splitlines() for x in l.split("\t")[:2] if x.isdigit()
                    )
                    extract(repo, t["commit"], tree, t["tests"])
                    g = subprocess.run(["go", "test", "-count=1", *t["pkgs"]], cwd=tree, capture_output=True, text=True, timeout=1800)
                    res["pass"] = g.returncode == 0 and not timed_out
                    res["test_tail"] = (g.stdout + g.stderr)[-500:]
                except Exception as e:
                    res["pass"] = False
                    res["error"] = str(e)[:300]
                finally:
                    shutil.rmtree(tree, ignore_errors=True)
                return res


            def run(args):
                tasks = load_tasks()
                if args.only:
                    tasks = [t for t in tasks if t.get("id") == args.only]
                if not tasks:
                    sys.exit("no tasks: use `pi-eval mine <repo> --add` first")
                label = os.environ.get("PI_EVAL_LABEL") or default_label()
                RESULTS.parent.mkdir(parents=True, exist_ok=True)
                for t in tasks:
                    t.setdefault("id", task_id(t["repo"], t["commit"]))
                    r = run_task(t, args.timeout, label)
                    with RESULTS.open("a") as f:
                        f.write(json.dumps(r, ensure_ascii=False) + "\n")
                    print(f"{r['id']} {'PASS' if r['pass'] else 'FAIL'} {r.get('wall', 0)}s tokens={r.get('tokens', 0)} calls={r.get('tool_calls', 0)}", flush=True)


            def default_label():
                r = subprocess.run(["git", "-C", str(HOME / "dotfiles"), "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
                return r.stdout.strip() or "unknown"


            def report(args):
                if not RESULTS.exists():
                    sys.exit("no results")
                rows = defaultdict(list)
                for line in RESULTS.open():
                    try:
                        r = json.loads(line)
                    except ValueError:
                        continue
                    rows[r.get("label", "?")].append(r)
                print(f"{'label':14} {'runs':>4} {'pass':>6} {'time p50':>9} {'tokens p50':>11} {'calls p50':>9}")
                for label, rs in rows.items():
                    passed = sum(1 for r in rs if r.get("pass")) / len(rs)
                    med = lambda k: statistics.median([r.get(k) or 0 for r in rs])
                    print(f"{label[:14]:14} {len(rs):4} {passed:6.0%} {med('wall'):8.0f}s {med('tokens') / 1000:10.0f}k {med('tool_calls'):9.0f}")


            def main():
                ap = argparse.ArgumentParser(prog="pi-eval")
                sub = ap.add_subparsers(dest="cmd", required=True)
                m = sub.add_parser("mine")
                m.add_argument("repo")
                m.add_argument("-n", type=int, default=20)
                m.add_argument("--scan", type=int, default=500)
                m.add_argument("--add", action="store_true")
                m.set_defaults(fn=mine)
                r = sub.add_parser("run")
                r.add_argument("--only")
                r.add_argument("--timeout", type=int, default=3600)
                r.set_defaults(fn=run)
                p = sub.add_parser("report")
                p.set_defaults(fn=report)
                args = ap.parse_args()
                args.fn(args)


            main()
          ''
        } "$@"
      '';

      piNvimLauncher =
        pkgs.writeShellScriptBin "pi" # bash
          ''
            set -u

            real="${pkgs-unstable.pi-coding-agent}/bin/pi"
            case "''${1-}" in
              install | uninstall | remove | update | list | config | mcp) ;;
              *) set -- --exclude-tools lsp_completions,lsp_symbols,code_overview,ast_search,code_rewrite "$@" ;;
            esac

            if [ -n "''${NVIM-}" ] || [ ! -t 0 ] || [ ! -t 1 ]; then
              exec "$real" "$@"
            fi

            state="''${XDG_RUNTIME_DIR:-/tmp}/pi-nvim-handoff.$$"
            rm -f "$state"
            PI_NVIM_HANDOFF="$state" "$real" "$@"
            status=$?

            if [ ! -e "$state" ]; then
              exit $status
            fi

            session=$(${lib.getExe pkgs.jq} -r '.session // empty' "$state")
            mapfile -t files < <(${lib.getExe pkgs.jq} -r '.files[]' "$state")
            rm -f "$state"

            if ! command -v nvim > /dev/null; then
              echo "pi: nvim не найден в PATH, передача сессии невозможна." >&2
              exit 1
            fi

            if [ -n "$session" ]; then
              export PI_NVIM_SESSION="$session"
            else
              export PI_NVIM_CONTINUE=1
            fi
            exec nvim "''${files[@]}"
          '';

      piNvimWrapped = pkgs.symlinkJoin {
        name = "pi-nvim-${pkgs-unstable.pi-coding-agent.version}";
        inherit (pkgs-unstable.pi-coding-agent) meta;
        inherit (pkgs-unstable.pi-coding-agent) version;
        paths = [ pkgs-unstable.pi-coding-agent ];
        postBuild = ''
          rm -f "$out/bin/pi"
          ln -s ${piNvimLauncher}/bin/pi "$out/bin/pi"
        '';
      };

      todoReminderFile = pkgs.writeText "todo-reminder.ts" /* typescript */ ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

        type Task = { id: number; subject: string; status: string };
        type Entry = { type?: string; message?: { role?: string; toolName?: string; details?: { tasks?: Task[]; nextId?: number } } };

        const STALE_AFTER = 8;

        export default function (pi: ExtensionAPI) {
          pi.on("context", (event, ctx) => {
            if (!pi.getActiveTools().includes("todo")) return;
            let tasks: Task[] = [];
            let since = 0;
            for (const entry of ctx.sessionManager.getBranch() as Entry[]) {
              const msg = entry.type === "message" ? entry.message : undefined;
              if (msg?.role !== "toolResult") continue;
              if (msg.toolName === "todo" && Array.isArray(msg.details?.tasks) && typeof msg.details?.nextId === "number") {
                tasks = msg.details.tasks;
                since = 0;
              } else {
                since++;
              }
            }
            const open = tasks.filter((t) => t.status === "pending" || t.status === "in_progress");
            if (open.length === 0 || since < STALE_AFTER) return;
            const list = open.map((t) => `#''${t.id} [''${t.status}] ''${t.subject}`).join("\n");
            const stale = `\nThe list was last updated ''${since} tool calls ago. Update it now if it is out of date.`;
            const content =
              `[Todo] Open tasks:\n''${list}\n` +
              "Keep this list current with the todo tool: set a task to in_progress when you start it, to completed right after it is done, add tasks you discover and delete tasks that no longer apply." +
              stale;
            const reminder = { role: "custom", customType: "todo-reminder", content, display: false, timestamp: Date.now() };
            return { messages: [...event.messages, reminder as (typeof event.messages)[number]] };
          });
        }
      '';

      contextKeeperFile = pkgs.writeText "context-keeper.ts" /* typescript */ ''
        import type { Api, Model } from "@earendil-works/pi-ai";
        import type { ExtensionAPI, ExtensionContext, SessionEntry } from "@earendil-works/pi-coding-agent";
        import { buildSessionContext, convertToLlm, estimateTokens, generateSummaryWithUsage } from "@earendil-works/pi-coding-agent";

        type Msg = Parameters<typeof estimateTokens>[0];
        type Level = NonNullable<ExtensionContext["thinkingLevel"]>;
        type Call = { type: string; text?: string; id?: string; name?: string; arguments?: Record<string, unknown> };
        type Task = { id: number; subject: string; status: string };
        type Manifest = {
          users: string[];
          todos: Task[];
          bash: { cmd: string; exit: string }[];
          errors: { tool: string; args: string; text: string }[];
          test?: { cmd: string; exit: string; tail: string };
        };
        type Details = { readFiles?: string[]; modifiedFiles?: string[]; contextKeeper?: Manifest };
        type State = { cutoff?: string; mark?: number };
        type Runtime = {
          resolveModel(model: Model<Api>, messages: ReturnType<typeof convertToLlm>, options: { reason: "direct"; thinkingLevel: Level; signal?: AbortSignal }): Promise<{ model: Model<Api>; thinkingLevel: Level }>;
          getAuth(model: Model<Api>, options: { signal?: AbortSignal }): Promise<{ auth: { apiKey?: string; headers?: Record<string, string | null>; baseUrl?: string }; env?: Record<string, string> } | undefined>;
          streamSimple: ExtensionContext["modelRegistry"]["streamSimple"];
        };
        type StreamFn = NonNullable<Parameters<typeof generateSummaryWithUsage>[9]>;

        const STATE = "context-keeper";
        const MASK_AT = 64_000;
        const MASK_STEP = 16_000;
        const KEEP_ROUNDS = 10;
        const SMALL_RESULT = 600;
        const LOOP_WINDOW = 10;
        const LOOP_REPEATS = 2;
        const READ_LIKE = new Set(["read", "aft_zoom", "aft_outline"]);
        const CODE_FILE = /\.(go|ts|tsx|js|jsx|mjs|cjs|rs|py|nix|sh|bash|zsh|lua|java|kt|c|h|cc|cpp|hpp|cs|rb|php|swift|sql|zig|proto)$/;
        const COMMENT = /^\s*(\/\/|\/\*|\*\/|\*\s|#(?!!)|--\s)|\s(\/\/|#|--)\s/;
        const CUT_HINT =
          "[Harness] Your previous response was cut off by a proxy timeout before it finished. Keep thinking short and split large changes: write or edit at most about 60 lines per tool call.";
        const USER_CHARS = 2000;
        const USER_BUDGET = 24_000;
        const BASH_KEEP = 15;
        const ERROR_KEEP = 5;
        const TAIL_LINES = 30;
        const MARK = "\n\n---\n## Manifest";
        const TEST_CMD = /(^|[;&|(\n])\s*(?:\S+=\S+\s+|timeout\s+\S+\s+|time\s+|env\s+|nix develop\s+(?:\S+\s+)?-c\s+|uv run\s+)*(make|cargo|go (?:test|build|vet)|golangci-lint|nix (?:build|flake check)|npm (?:run|test)|pnpm|yarn|pytest|tsc)\b/;
        const MUTATING = /edit|write|patch|rename|code_actions|codemode|subagent/;
        const POLLING = new Set(["bash", "bash_status", "bash_watch", "lsp_diagnostics", "todo"]);
        const SCHEMA = [
          "Ignore the section list above. Use exactly these markdown sections, in this order:",
          "## Goal",
          "## Decisions (each with its reason)",
          "## Rejected hypotheses (what was tried or suspected and ruled out, and why)",
          "## Discoveries (facts about the code: exact paths, functions, behaviour)",
          "## Current step",
          "## Next action",
          "Write \"none\" under a section that has nothing. If a previous summary is given, merge the new information into it section by section instead of rewriting it: keep every item that is still valid, move finished work out of Current step, drop only what is proven wrong.",
          "Do not list user messages, todo tasks, files, bash commands or tool errors: the harness appends them verbatim.",
        ].join("\n");

        const clip = (s: string, n: number) => (s.length > n ? `''${s.slice(0, n)}…` : s);
        const oneLine = (s: string) => s.replace(/\s+/g, " ").trim();
        const textOf = (content: unknown) =>
          typeof content === "string" ? content : Array.isArray(content) ? (content as Call[]).map((c) => (c?.type === "text" ? (c.text ?? "") : "")).join("\n") : "";
        const sizeOf = (content: unknown) =>
          typeof content === "string" ? content.length : Array.isArray(content) ? (content as Call[]).reduce((n, c) => n + (c?.type === "text" ? (c.text?.length ?? 0) : 4800), 0) : 0;
        const stable = (v: unknown): string =>
          Array.isArray(v)
            ? `[''${v.map(stable).join(",")}]`
            : v && typeof v === "object"
              ? `{''${Object.keys(v).sort().map((k) => `''${JSON.stringify(k)}:''${stable((v as Record<string, unknown>)[k])}`).join(",")}}`
              : (JSON.stringify(v) ?? "null");
        const shortArgs = (args: Record<string, unknown> | undefined) => {
          if (!args) return "";
          for (const k of ["path", "file_path", "command", "pattern", "query", "target", "url"]) {
            if (typeof args[k] === "string") return clip(oneLine(args[k] as string), 120);
          }
          return clip(JSON.stringify(args), 120);
        };
        const callsOf = (m: Msg): Call[] => (m.role === "assistant" && Array.isArray(m.content) ? (m.content as Call[]).filter((c) => c?.type === "toolCall") : []);
        const messagesOf = (entries: SessionEntry[]) => entries.flatMap((e) => (e.type === "message" ? [e.message as Msg] : []));
        const sinceCompaction = (entries: SessionEntry[]) => entries.slice(entries.findLastIndex((e) => e.type === "compaction") + 1);
        const resultIndex = (messages: Msg[], id: string | undefined) => (id ? messages.findIndex((m) => m.role === "toolResult" && m.toolCallId === id) : -1);

        const mask = (messages: Msg[], cutoff: string | undefined) => {
          const end = resultIndex(messages, cutoff);
          if (end < 0) return { messages, saved: 0 };
          const calls = new Map(messages.slice(0, end + 1).flatMap(callsOf).map((c) => [c.id, c] as const));
          let saved = 0;
          const out = messages.map((m, i) => {
            if (i > end || m.role !== "toolResult" || m.toolName === "todo" || sizeOf(m.content) < SMALL_RESULT) return m;
            const what = [m.toolName, shortArgs(calls.get(m.toolCallId)?.arguments)].filter(Boolean).join(" ");
            const next = { ...m, content: [{ type: "text" as const, text: `[''${m.toolName} result hidden to save context: ''${what}. Run it again if you need it.]` }] };
            saved += estimateTokens(m) - estimateTokens(next);
            return next;
          });
          return { messages: out, saved };
        };

        const pickCutoff = (messages: Msg[]) => {
          const rounds = messages.flatMap((m, i) => (callsOf(m).length ? [i] : []));
          if (rounds.length <= KEEP_ROUNDS) return -1;
          for (let i = rounds[rounds.length - KEEP_ROUNDS] - 1; i >= 0; i--) if (messages[i].role === "toolResult") return i;
          return -1;
        };

        const collect = (entries: SessionEntry[], prev: Manifest): Manifest => {
          const m: Manifest = { users: [...prev.users], todos: prev.todos, bash: [...prev.bash], errors: [...prev.errors], test: prev.test };
          const calls = new Map<string | undefined, Call>();
          for (const msg of messagesOf(entries)) {
            if (msg.role === "user") {
              const text = textOf(msg.content).trim();
              if (text) m.users.push(clip(text, USER_CHARS));
            }
            for (const c of callsOf(msg)) calls.set(c.id, c);
            if (msg.role !== "toolResult") continue;
            const call = calls.get(msg.toolCallId);
            const text = textOf(msg.content);
            const details = msg.details as { tasks?: Task[]; nextId?: number; exit_code?: number } | undefined;
            if (msg.toolName === "todo" && Array.isArray(details?.tasks) && typeof details?.nextId === "number") {
              m.todos = details.tasks.filter((t) => t.status === "pending" || t.status === "in_progress");
            }
            if (msg.isError) m.errors.push({ tool: msg.toolName, args: shortArgs(call?.arguments), text: clip(oneLine(text), 300) });
            const cmd = msg.toolName === "bash" ? call?.arguments?.command : undefined;
            if (typeof cmd !== "string") continue;
            const code = typeof details?.exit_code === "number" ? String(details.exit_code) : (/\[exit code: (-?\d+)\]/.exec(text)?.[1] ?? (msg.isError ? "error" : "0"));
            m.bash.push({ cmd: clip(oneLine(cmd), 300), exit: code });
            if (TEST_CMD.test(cmd)) m.test = { cmd: clip(oneLine(cmd), 300), exit: code, tail: text.trimEnd().split("\n").slice(-TAIL_LINES).map((l) => clip(l, 300)).join("\n") };
          }
          const users: string[] = [];
          let total = 0;
          for (const u of [...m.users].reverse()) {
            if ((total += u.length) > USER_BUDGET && users.length) break;
            users.unshift(u);
          }
          return { ...m, users, bash: m.bash.slice(-BASH_KEEP), errors: m.errors.slice(-ERROR_KEEP) };
        };

        const section = (title: string, lines: string[]) => `### ''${title}\n''${lines.length ? lines.join("\n") : "none"}`;
        const render = (m: Manifest, read: string[], modified: string[]) =>
          [
            "## Manifest (recorded by the harness from the session log, exact)",
            section("User messages, verbatim, oldest first", m.users.map((u, i) => `''${i + 1}. ''${u.replace(/\n/g, "\n   ")}`)),
            section("Open todo tasks", m.todos.map((t) => `- #''${t.id} [''${t.status}] ''${t.subject}`)),
            section("Files read", read.map((f) => `- ''${f}`)),
            section("Files modified", modified.map((f) => `- ''${f}`)),
            section("Last bash commands, oldest first", m.bash.map((b) => `- [exit ''${b.exit}] ''${b.cmd}`)),
            section("Last tool errors", m.errors.map((e) => `- ''${[e.tool, e.args].filter(Boolean).join(" ")}: ''${e.text}`)),
            m.test ? `### Last test/build output: ''${m.test.cmd} (exit ''${m.test.exit})\n\`\`\`\n''${m.test.tail}\n\`\`\`` : section("Last test/build output", []),
          ].join("\n\n");

        export default function (pi: ExtensionAPI) {
          const readState = (ctx: ExtensionContext): State => {
            const e = sinceCompaction(ctx.sessionManager.getBranch()).findLast((x) => x.type === "custom" && x.customType === STATE);
            return (e?.type === "custom" ? (e.data as State | undefined) : undefined) ?? {};
          };

          pi.on("context", (event, ctx) => {
            const state = readState(ctx);
            let { messages, saved } = mask(event.messages, state.cutoff);
            const size = (list: Msg[]) => Math.ceil(ctx.getSystemPrompt().length / 4) + list.reduce((n, m) => n + estimateTokens(m), 0);
            const tokens = size(messages);
            if (tokens >= MASK_AT && (state.mark === undefined || tokens >= state.mark + MASK_STEP)) {
              const next = pickCutoff(event.messages);
              const at = next > resultIndex(event.messages, state.cutoff) ? next : -1;
              const cutoff = at >= 0 ? (event.messages[at] as Extract<Msg, { role: "toolResult" }>).toolCallId : state.cutoff;
              ({ messages, saved } = mask(event.messages, cutoff));
              pi.appendEntry<State>(STATE, { cutoff, mark: size(messages) });
            }
            if (ctx.hasUI) ctx.ui.setStatus(STATE, saved > 0 ? `masked ''${Math.round(saved / 1000)}k` : undefined);
            if (cut) messages = [...messages, { role: "custom", customType: "context-keeper-cut", content: CUT_HINT, display: false, timestamp: Date.now() } as Msg];
            return messages === event.messages ? undefined : { messages };
          });

          let cut = false;

          pi.on("message_end", (event) => {
            const m = event.message;
            if (m.role !== "assistant") return;
            cut = m.stopReason === "error" && /terminated/i.test(m.errorMessage ?? "");
          });

          pi.on("session_start", () => {
            cut = false;
          });

          pi.on("tool_result", (event) => {
            if (event.isError || (event.toolName !== "edit" && event.toolName !== "write")) return;
            const input = event.input as { path?: unknown; content?: unknown; appendContent?: unknown; edits?: { oldString?: unknown; newString?: unknown; content?: unknown }[] };
            if (typeof input.path !== "string" || !CODE_FILE.test(input.path)) return;
            const str = (v: unknown) => (typeof v === "string" ? v : "");
            const pairs = [
              ["", str(input.content)],
              ["", str(input.appendContent)],
              ...(Array.isArray(input.edits) ? input.edits.map((e) => [str(e.oldString), str(e.newString) || str(e.content)]) : []),
            ];
            const added = pairs.flatMap(([before, after]) => {
              const old = new Set(before.split("\n").map((l) => l.trim()));
              return after.split("\n").filter((l) => COMMENT.test(l) && !old.has(l.trim())).map((l) => l.trim());
            });
            if (added.length === 0) return;
            const list = added.slice(0, 10).map((l) => `  ''${clip(l, 160)}`).join("\n");
            const text = `[Harness] This edit added ''${added.length} comment line(s):\n''${list}\nCheck each against the Code comments rules. Keep one only if it explains a non-obvious why that the code cannot show. Remove the others with your next edit.`;
            return { content: [...event.content, { type: "text" as const, text }], structuredContent: event.structuredContent };
          });

          pi.on("session_compact", (_event, ctx) => {
            if (ctx.hasUI) ctx.ui.setStatus(STATE, undefined);
          });

          pi.on("tool_call", (event, ctx) => {
            if (event.parentToolCallId || POLLING.has(event.toolName)) return;
            const msgs = messagesOf(sinceCompaction(ctx.sessionManager.getBranch()));
            const calls = msgs.slice(msgs.findLastIndex((m) => m.role === "user") + 1).flatMap(callsOf);
            const at = calls.findIndex((c) => c.id === event.toolCallId);
            const hidden = resultIndex(msgs, readState(ctx).cutoff);
            const visible = (id: string | undefined) => {
              const i = resultIndex(msgs, id);
              const r = msgs[i];
              return i > hidden && r?.role === "toolResult" && !r.isError;
            };
            const self = at >= 0 ? calls[at] : { name: event.toolName, arguments: event.input as Record<string, unknown> };
            const key = `''${self.name}:''${stable(self.arguments ?? {})}`;
            let repeats = 0;
            for (const c of (at >= 0 ? calls.slice(0, at) : calls).slice(-LOOP_WINDOW).reverse()) {
              const k = `''${c.name}:''${stable(c.arguments ?? {})}`;
              if (k === key) {
                if (visible(c.id)) repeats++;
              }
              else if (c.name && (MUTATING.test(c.name) || c.name === "bash")) break;
            }
            if (repeats < (READ_LIKE.has(event.toolName) ? 1 : LOOP_REPEATS)) return;
            return {
              block: true,
              reason: READ_LIKE.has(event.toolName) && repeats === 1
                ? `Skipped: you already ran this exact ''${event.toolName} in this turn and nothing was modified since. The content is in the earlier result above, use it.`
                : `Blocked: this ''${event.toolName} call repeats an identical earlier call (same tool, same arguments) with no edit, write or other command since, so the result has not changed. Use the earlier result or change approach.`,
            };
          });

          pi.on("session_before_compact", async (event, ctx) => {
            const { preparation: prep, branchEntries, signal } = event;
            const model = ctx.model;
            const runtime = (ctx.modelRegistry as unknown as { runtime?: Runtime }).runtime;
            if (!model || typeof runtime?.resolveModel !== "function" || typeof runtime.getAuth !== "function" || typeof runtime.streamSimple !== "function") return;

            const last = branchEntries.findLast((e) => e.type === "compaction");
            const prev = (last?.type === "compaction" ? (last.details as Details | undefined) : undefined) ?? {};
            const manifest = collect(sinceCompaction(branchEntries), prev.contextKeeper ?? { users: [], todos: [], bash: [], errors: [] });
            const modified = new Set([...(prev.modifiedFiles ?? []), ...prep.fileOps.edited, ...prep.fileOps.written]);
            const readFiles = [...new Set([...(prev.readFiles ?? []), ...prep.fileOps.read])].filter((f) => !modified.has(f)).sort();
            const modifiedFiles = [...modified].sort();

            let request: { model: Model<Api>; thinkingLevel: Level; apiKey?: string; headers?: Record<string, string>; env?: Record<string, string> };
            try {
              const level = ctx.thinkingLevel ?? pi.getThinkingLevel();
              const llm = convertToLlm(buildSessionContext(branchEntries, branchEntries.at(-1)?.id ?? null).messages);
              request = model.api === "pi-virtual" ? await runtime.resolveModel(model, llm, { reason: "direct", thinkingLevel: level, signal }) : { model, thinkingLevel: level };
              try {
                const auth = await runtime.getAuth(request.model, { signal });
                if (auth) {
                  request = {
                    model: auth.auth.baseUrl ? { ...request.model, baseUrl: auth.auth.baseUrl } : request.model,
                    thinkingLevel: request.thinkingLevel,
                    apiKey: auth.auth.apiKey,
                    headers: auth.auth.headers ? Object.fromEntries(Object.entries(auth.auth.headers).filter((h): h is [string, string] => h[1] !== null)) : undefined,
                    env: auth.env,
                  };
                }
              } catch (error) {
                if (signal.aborted) throw error;
              }
            } catch (error) {
              if (signal.aborted) return { cancel: true };
              ctx.ui.notify(`context-keeper: model routing failed, using default compaction: ''${error instanceof Error ? error.message : String(error)}`, "warning");
              return;
            }

            const s = pi.getSettings();
            const idle = s.httpIdleTimeoutMs ?? 300_000;
            const transport = {
              timeoutMs: s.retry?.provider?.timeoutMs ?? (idle === 0 ? 2147483647 : idle),
              websocketConnectTimeoutMs: s.websocketConnectTimeoutMs,
              maxRetries: s.retry?.provider?.maxRetries,
              maxRetryDelayMs: s.retry?.provider?.maxRetryDelayMs ?? 60_000,
            };
            const streamFn = ((m, c, o) => runtime.streamSimple(m, c, { ...o, ...transport })) as StreamFn;
            const retry = {
              enabled: s.retry?.enabled ?? true,
              maxRetries: s.retry?.maxRetries ?? 3,
              baseDelayMs: s.retry?.baseDelayMs ?? 2000,
              maxAgentDelayMs: s.retry?.maxAgentDelayMs ?? 60_000,
            };
            const instructions = [SCHEMA, event.customInstructions].filter(Boolean).join("\n\n");
            const list = [...prep.messagesToSummarize, ...prep.turnPrefixMessages] as Msg[];
            const cutoff = readState(ctx).cutoff;
            const tail = list.findLast((m) => m.role === "toolResult");
            const summarized = mask(list, cutoff && resultIndex(list, cutoff) < 0 && tail?.role === "toolResult" ? tail.toolCallId : cutoff).messages;

            try {
              const result = await generateSummaryWithUsage(
                summarized,
                request.model,
                prep.settings.reserveTokens,
                request.apiKey,
                request.headers,
                signal,
                instructions,
                prep.previousSummary?.split(MARK)[0],
                request.thinkingLevel,
                streamFn,
                request.env,
                retry,
              );
              return {
                compaction: {
                  summary: `''${result.text.trim()}\n\n---\n''${render(manifest, readFiles, modifiedFiles)}`,
                  firstKeptEntryId: prep.firstKeptEntryId,
                  tokensBefore: prep.tokensBefore,
                  usage: result.usage,
                  details: { readFiles, modifiedFiles, contextKeeper: manifest } satisfies Details,
                },
              };
            } catch (error) {
              if (signal.aborted) return { cancel: true };
              ctx.ui.notify(`context-keeper: compaction failed, using default compaction: ''${error instanceof Error ? error.message : String(error)}`, "warning");
              return;
            }
          });
        }
      '';

      subagentFile = pkgs.writeText "subagent.ts" /* typescript */ ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
        import { Type } from "typebox";
        import { execFile, spawn } from "node:child_process";
        import { randomUUID } from "node:crypto";
        import { appendFileSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { homedir, tmpdir } from "node:os";
        import { basename, dirname, join, resolve } from "node:path";
        import { checkCommand } from "${piPlan}/src/safety.ts";
        ${pipelineCommon}
        type Agent = { name: string; description: string; tools?: string; model?: string; thinking?: string; body: string };
        type Answer = { answer: string; stopReason?: string; usage?: unknown };
        type Herdr = { ok: true; result: any } | { ok: false; code: string; message: string };
        type Pipe = { run: string; parent: string; phase?: string };
        type Job = {
          id: string;
          nodeId?: string;
          pipe?: Pipe;
          agent: string;
          task: string;
          cwd: string;
          run: string;
          sessionId: string;
          status: string;
          progress?: string;
          ok?: boolean;
          answer?: string;
          error?: string;
          stopReason?: string;
          usage?: unknown;
          tab?: string;
          pane?: string;
          readonly?: boolean;
        };

        const DIR = join(process.env.XDG_RUNTIME_DIR || tmpdir(), "pi-herdr");
        const AGENTS = join(process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent"), "agents");
        const TICK_MS = 5000;
        const CAP = 4000;
        const LIMIT = Math.max(1, Number(process.env.PI_SUBAGENT_CONCURRENCY) || 2);

        type Background = { job: Job; ctrl: AbortController; done: Promise<unknown>; owner: string };
        const background = new Map<string, Background>();
        const waiters: (() => void)[] = [];
        let busy = 0;

        const acquire = (signal: AbortSignal) =>
          new Promise<boolean>((done) => {
            if (signal.aborted) return done(false);
            if (busy < LIMIT) return (busy++, done(true));
            const go = () => {
              signal.removeEventListener("abort", drop);
              busy++;
              done(true);
            };
            const drop = () => {
              const i = waiters.indexOf(go);
              if (i >= 0) waiters.splice(i, 1);
              done(false);
            };
            waiters.push(go);
            signal.addEventListener("abort", drop, { once: true });
          });

        const release = () => {
          busy--;
          waiters.shift()?.();
        };

        const finished = (j: Job) => j.status === "done" || j.status === "failed";

        const head = (s: string, n = 30) => {
          const t = s.replace(/\s+/g, " ").trim();
          return t.length > n ? t.slice(0, n - 1) + "…" : t;
        };

        const file = (run: string, ext: string) => join(DIR, run + ext);

        const emitAgent = (job: Job) =>
          job.nodeId &&
          job.pipe &&
          emitEvent({
            id: job.nodeId,
            parents: [job.pipe.parent],
            kind: "agent",
            label: `''${job.agent}: ''${head(job.task, 40)}`,
            run: job.pipe.run,
            ...(job.pipe.phase ? { phase: job.pipe.phase } : {}),
            cwd: job.cwd,
            sessionId: job.sessionId,
            status: finished(job) ? (job.ok ? "ok" : "fail") : "running",
            ...(job.error ? { detail: head(job.error, 200) } : {}),
          });

        const emitJoin = (jobs: Job[]) => {
          const nodes = jobs.filter((j) => j.nodeId && j.pipe && finished(j));
          if (nodes.length < 2) return;
          const pipe = nodes[0].pipe!;
          emitEvent({
            id: `join-''${randomUUID()}`,
            parents: nodes.map((j) => j.nodeId),
            kind: "join",
            label: `join: ''${nodes.map((j) => j.agent).join(", ")}`,
            run: pipe.run,
            ...(pipe.phase ? { phase: pipe.phase } : {}),
            cwd: nodes[0].cwd,
            status: nodes.every((j) => j.ok) ? "ok" : "fail",
          });
        };

        const expertsFile = (path: string) => {
          const p = resolve(path.startsWith("~/") ? join(homedir(), path.slice(2)) : path);
          return basename(p) === "experts.md" && dirname(dirname(p)) === join(homedir(), ".pi", "projects");
        };

        const readText = (path: string) => {
          try {
            return readFileSync(path, "utf8");
          } catch {
            return undefined;
          }
        };

        const writeAtomic = (path: string, data: string) => {
          try {
            mkdirSync(DIR, { recursive: true });
            const tmp = `''${path}.''${process.pid}.tmp`;
            writeFileSync(tmp, data);
            renameSync(tmp, path);
          } catch {}
        };

        const readAnswer = (run: string): Answer | undefined => {
          const raw = readText(file(run, ".json"));
          if (!raw) return undefined;
          try {
            return JSON.parse(raw) as Answer;
          } catch {
            return undefined;
          }
        };

        const fromMessage = (m: any): Answer | undefined => {
          if (!m || m.role !== "assistant") return undefined;
          const parts = Array.isArray(m.content) ? m.content : [{ type: "text", text: String(m.content ?? "") }];
          const answer = parts
            .filter((c: any) => c?.type === "text")
            .map((c: any) => c.text)
            .join("\n")
            .trim();
          return { answer, stopReason: m.stopReason, usage: m.usage };
        };

        const loadAgents = () => {
          const out = new Map<string, Agent>();
          let names: string[] = [];
          try {
            names = readdirSync(AGENTS).filter((f) => f.endsWith(".md"));
          } catch {
            return out;
          }
          for (const f of names) {
            const raw = readText(join(AGENTS, f)) ?? "";
            const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
            const meta: Record<string, string> = {};
            for (const line of (m?.[1] ?? "").split(/\r?\n/)) {
              const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.+)$/);
              if (kv) meta[kv[1]] = kv[2].trim().replace(/^["']|["']$/g, "");
            }
            const name = meta.name || f.slice(0, -3);
            out.set(name, { name, description: meta.description ?? "", tools: meta.tools, model: meta.model, thinking: meta.thinking, body: (m ? m[2] : raw).trim() });
          }
          return out;
        };

        const herdr = (args: string[], signal?: AbortSignal): Promise<Herdr> =>
          new Promise((done) => {
            execFile("herdr", args, { signal, maxBuffer: 16 << 20 }, (err, stdout, stderr) => {
              const parse = (s: string) => {
                try {
                  return JSON.parse(s);
                } catch {
                  return undefined;
                }
              };
              if (!err) return done({ ok: true, result: parse(stdout)?.result ?? {} });
              const e = parse(String(stderr))?.error;
              done({ ok: false, code: e?.code ?? (signal?.aborted ? "aborted" : "exec"), message: e?.message ?? (String(stderr).trim() || err.message) });
            });
          });

        const sleep = (ms: number, signal: AbortSignal) =>
          new Promise<void>((done) => {
            const t = setTimeout(done, ms);
            signal.addEventListener("abort", () => (clearTimeout(t), done()), { once: true });
          });

        function childMode(pi: ExtensionAPI) {
          if (process.env.PI_READONLY)
            pi.on("tool_call", (event) => {
              if (event.toolName === "write" && expertsFile(String((event.input as { path?: unknown }).path ?? ""))) return;
              if (event.toolName === "edit" || event.toolName === "write") return { block: true, reason: "Read-only: the calling agent is in plan mode." };
              if (event.toolName !== "bash") return;
              const check = checkCommand(String((event.input as { command?: unknown }).command ?? ""));
              return check.safe ? undefined : { block: true, reason: check.reason ?? "Read-only: the calling agent is in plan mode." };
            });
          const run = process.env.PI_HERDR_RUN;
          if (!run) return;
          pi.on("agent_end", (event) => {
            if ((event as { willRetry?: boolean }).willRetry) return;
            const last = fromMessage(event.messages.findLast((m) => m.role === "assistant"));
            writeAtomic(file(run, ".json"), JSON.stringify({ answer: last?.answer ?? "", stopReason: last?.stopReason, usage: last?.usage }));
          });
          pi.on("tool_execution_start", (event) => writeAtomic(file(run, ".progress"), event.toolName));
          pi.on("ui_prompt_start", (event) => pi.events.emit("herdr:blocked", { active: true, label: event.title ?? event.kind }));
          pi.on("ui_prompt_end", (event) => pi.events.emit("herdr:blocked", { active: false, label: event.title ?? event.kind }));
        }

        const childArgs = (agent: Agent, job: Job) => {
          const prompt = file(job.run, ".md");
          writeAtomic(prompt, `<active_agent name="''${agent.name}" />\n\n''${agent.body}\n`);
          const args = ["--session-id", job.sessionId, "--name", `''${agent.name}: ''${head(job.task)}`];
          if (agent.model) args.push("--model", agent.model);
          if (agent.thinking) args.push("--thinking", agent.thinking);
          const tools = agent.tools?.split(",").map((t) => t.trim()).filter(Boolean);
          if (tools?.length) args.push("--tools", tools.join(","));
          else args.push("--exclude-tools", "subagent");
          args.push("--append-system-prompt", prompt);
          return args;
        };

        const childEnv = (job: Job) => ({
          PI_HERDR_DEPTH: "1",
          PI_HERDR_RUN: job.run,
          ...(job.readonly ? { PI_READONLY: "1" } : {}),
          ...(job.nodeId && job.pipe ? { PI_PIPELINE_RUN: job.pipe.run, PI_PIPELINE_NODE: job.nodeId } : {}),
        });

        async function viaHerdr(job: Job, args: string[], ws: string, outer: AbortSignal, timeoutMs: number, notify: (msg: string) => void) {
          const deadline = Date.now() + timeoutMs;
          const sig = AbortSignal.any([outer, AbortSignal.timeout(timeoutMs)]);
          const left = () => Math.max(1000, deadline - Date.now());
          const slice = () => String(Math.min(15000, left()));
          const name = `sub-''${job.agent.toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 14) || "agent"}-''${job.run.slice(0, 8)}`;
          const task = job.task.replace(/\s+/g, " ").trim();
          const label = `''${job.agent}: ''${task.length > 12 ? task.slice(0, 12) + "…" : task}`;
          const env = Object.entries(childEnv(job)).flatMap(([k, v]) => ["--env", `''${k}=''${v}`]);
          const tab = await herdr(["tab", "create", "--workspace", ws, "--cwd", job.cwd, "--label", label, "--no-focus", ...env], sig);
          if (!tab.ok) return Object.assign(job, { ok: false, error: `tab create failed: ''${tab.message}` });
          const tabId: string = tab.result.tab?.tab_id;
          job.tab = label;
          job.pane = tab.result.root_pane?.pane_id;
          const keep = (error: string) => Object.assign(job, { ok: false, error });
          const stop = async () => {
            await herdr(["agent", "send-keys", name, "esc"]);
            await herdr(["tab", "close", tabId]);
            return Object.assign(job, { ok: false, error: outer.aborted ? "aborted" : "timed out", tab: undefined, pane: undefined });
          };
          job.status = "starting";
          const start = await herdr(["agent", "start", name, "--kind", "pi", "--pane", String(job.pane), "--timeout", String(Math.min(120000, left())), "--", ...args], sig);
          if (sig.aborted) return stop();
          if (!start.ok && start.code !== "agent_not_ready") return keep(`agent start failed: ''${start.message}`);
          let sent = false;
          let notified = false;
          while (true) {
            if (sig.aborted) return stop();
            const answer = readAnswer(job.run);
            if (answer) {
              await herdr(["tab", "close", tabId]);
              return Object.assign(job, { ok: !!answer.answer, ...answer, error: answer.answer ? undefined : `empty answer (''${answer.stopReason})`, tab: undefined, pane: undefined });
            }
            const got = await herdr(["agent", "get", name], sig);
            if (sig.aborted) return stop();
            if (!got.ok) return keep(`agent get failed: ''${got.message}`);
            job.status = got.result.agent?.agent_status ?? "unknown";
            if (job.status === "blocked") {
              if (!notified) notify(`subagent ''${job.agent} waits for approval in tab ''${label}`);
              notified = true;
              await herdr(["agent", "wait", name, "--until", "idle", "--until", "done", "--timeout", slice()], sig);
              continue;
            }
            notified = false;
            if (!sent) {
              const p = await herdr(["agent", "prompt", name, job.task, "--wait", "--until", "idle", "--until", "done", "--until", "blocked", "--timeout", String(left())], sig);
              if (p.ok || p.code === "agent_prompt_stalled" || p.code === "timeout") sent = true;
              else if (p.code !== "agent_blocked" && !sig.aborted) return keep(`agent prompt failed: ''${p.message}`);
              continue;
            }
            if (job.status === "idle" || job.status === "done") {
              for (let i = 0; i < 6 && !readAnswer(job.run) && !sig.aborted; i++) await sleep(500, sig);
              if (readAnswer(job.run) || sig.aborted) continue;
              return keep("agent finished without an answer");
            }
            await herdr(["agent", "wait", name, "--timeout", slice()], sig);
          }
        }

        function viaPrint(job: Job, args: string[], outer: AbortSignal, timeoutMs: number) {
          return new Promise<Job>((done) => {
            const sig = AbortSignal.any([outer, AbortSignal.timeout(timeoutMs)]);
            job.status = "running";
            const child = spawn("pi", ["-p", "--mode", "json", ...args, "--", job.task], { cwd: job.cwd, env: { ...process.env, ...childEnv(job) }, stdio: ["ignore", "pipe", "pipe"] });
            let buf = "";
            let err = "";
            let last: Answer | undefined;
            child.stdout.setEncoding("utf8");
            child.stdout.on("data", (chunk: string) => {
              buf += chunk;
              for (let i = buf.indexOf("\n"); i >= 0; i = buf.indexOf("\n")) {
                const line = buf.slice(0, i).replace(/\r$/, "");
                buf = buf.slice(i + 1);
                let ev: any;
                try {
                  ev = JSON.parse(line);
                } catch {
                  continue;
                }
                if (ev.type === "tool_execution_start") job.progress = ev.toolName;
                if (ev.type === "message_end" && ev.message?.role === "assistant") last = fromMessage(ev.message);
              }
            });
            child.stderr.on("data", (chunk) => (err = (err + chunk).slice(-2000)));
            const kill = () => {
              child.kill("SIGINT");
              setTimeout(() => child.kill("SIGKILL"), 5000).unref();
            };
            sig.addEventListener("abort", kill, { once: true });
            const finish = (error?: string) => {
              sig.removeEventListener("abort", kill);
              if (sig.aborted) return done(Object.assign(job, { ok: false, error: outer.aborted ? "aborted" : "timed out" }));
              if (last?.answer) return done(Object.assign(job, { ok: true, ...last }));
              done(Object.assign(job, { ok: false, ...last, error: error ?? `pi gave no answer (''${last?.stopReason ?? "no message"}): ''${err.trim().slice(-500)}` }));
            };
            child.on("error", (e) => finish(`pi failed to start: ''${e.message}`));
            child.on("close", () => finish());
          });
        }

        const describe = (agents: Map<string, Agent>) =>
          "Run tasks in child pi agents (fresh context, each in its own background herdr tab) and return each final answer. " +
          "Tasks run in parallel. For a chain, call again with the previous result. " +
          "Delegate only independent, substantial read-only work. Each task must be self-contained. You do the edits yourself. " +
          "With background: true the call returns job ids at once; keep working and collect the answers with subagent_wait. " +
          `Agents: ''${[...agents.values()].map((a) => (a.description ? `''${a.name} (''${a.description})` : a.name)).join(", ") || "none"}.`;

        async function runOne(job: Job, agent: Agent | undefined, ws: string | undefined, signal: AbortSignal, timeoutMs: number, notify: (msg: string) => void) {
          if (!agent) return Object.assign(job, { ok: false, status: "failed", nodeId: undefined, error: `unknown agent, available: ''${[...loadAgents().keys()].join(", ") || "none"}` });
          emitAgent(job);
          let held = false;
          try {
            held = await acquire(signal);
            if (!held) return Object.assign(job, { ok: false, error: "aborted" });
            const args = childArgs(agent, job);
            job.progress = undefined;
            if (ws) await viaHerdr(job, args, ws, signal, timeoutMs, notify);
            else await viaPrint(job, args, signal, timeoutMs);
          } catch (e) {
            Object.assign(job, { ok: false, error: String(e) });
          } finally {
            if (held) release();
            job.status = job.ok ? "done" : "failed";
            for (const ext of [".json", ".progress", ".md"]) rmSync(file(job.run, ext), { force: true });
            emitAgent(job);
          }
          return job;
        }

        const render = (jobs: Job[]) =>
          jobs
            .map((j) => {
              const body = !finished(j)
                ? `Still running [''${j.status}''${j.progress ? `, ''${j.progress}` : ""}]. Call subagent_wait again to collect it.`
                : j.ok
                  ? (j.answer ?? "").length > CAP
                    ? `''${j.answer!.slice(0, CAP)}\n[answer truncated at ''${CAP} chars]`
                    : j.answer
                  : `No answer: ''${j.error}.''${j.tab ? ` Tab "''${j.tab}" (pane ''${j.pane}) is kept open.` : ""}`;
              return `### ''${j.agent} ''${j.id}: ''${head(j.task)}\n''${body}\nsession: ''${j.sessionId}`;
            })
            .join("\n\n");

        const ticker = (jobs: Job[], onUpdate: ((u: { content: { type: "text"; text: string }[]; details: { jobs: Job[] } }) => void) | undefined) =>
          setInterval(() => {
            for (const j of jobs) if (!finished(j)) j.progress = readText(file(j.run, ".progress")) ?? j.progress;
            const text = jobs.map((j) => `''${j.agent} ''${j.id}: ''${head(j.task)} [''${j.status}''${j.progress ? `, ''${j.progress}` : ""}]`).join("\n");
            onUpdate?.({ content: [{ type: "text", text }], details: { jobs } });
          }, TICK_MS);

        const aborted = (signal: AbortSignal) => new Promise<void>((done) => (signal.aborted ? done() : signal.addEventListener("abort", () => done(), { once: true })));

        export default function (pi: ExtensionAPI) {
          if (process.env.PI_HERDR_DEPTH) return childMode(pi);
          const agents = loadAgents();
          let phase: { run: string; phase?: string; nodeId: string } | undefined;
          pi.events.on("pipeline:phase", (data) => {
            const p = data as typeof phase | null;
            phase = p?.nodeId ? p : undefined;
          });
          const pipeOf = () => currentNode(phase);

          pi.registerTool({
            name: "subagent",
            label: "Subagent",
            description: describe(agents),
            parameters: Type.Object({
              tasks: Type.Array(
                Type.Object({
                  task: Type.String({ description: "Complete instructions and expected answer format" }),
                  agent: Type.Optional(Type.String({ description: "Agent name, default scout" })),
                  cwd: Type.Optional(Type.String({ description: "Working directory, default current" })),
                }),
                { minItems: 1, maxItems: 4 },
              ),
              timeoutMin: Type.Optional(Type.Integer({ description: "Per-task limit in minutes, default 30" })),
              background: Type.Optional(Type.Boolean({ description: "Return job ids at once, collect answers later with subagent_wait" })),
            }),
            async execute(_id, params, signal, onUpdate, ctx) {
              const outer = signal ?? new AbortController().signal;
              const timeoutMs = Math.max(1, params.timeoutMin ?? 30) * 60000;
              let ws = process.env.HERDR_ENV === "1" ? process.env.HERDR_WORKSPACE_ID : undefined;
              if (process.env.HERDR_ENV === "1" && !ws && process.env.HERDR_PANE_ID) {
                const p = await herdr(["pane", "get", process.env.HERDR_PANE_ID], outer);
                if (p.ok) ws = p.result.pane?.workspace_id;
              }
              type PlanEntry = { type: string; customType?: string; data?: { mode?: string } };
              const inPlan = (ctx.sessionManager.getBranch() as PlanEntry[]).findLast((e) => e.type === "custom" && e.customType === "pi-plan")?.data?.mode === "plan";
              const pipe = pipeOf();
              const jobs: Job[] = params.tasks.map((t) => {
                const run = randomUUID();
                const sessionId = randomUUID();
                return {
                  id: run.slice(0, 8),
                  ...(pipe ? { nodeId: sessionId, pipe } : {}),
                  agent: t.agent || "scout",
                  task: t.task,
                  cwd: resolve(ctx.cwd, t.cwd || "."),
                  run,
                  sessionId,
                  status: "queued",
                  readonly: inPlan,
                };
              });
              const warn = (msg: string) => {
                try {
                  if (ctx.hasUI) ctx.ui.notify(msg, "warning");
                } catch {}
              };
              if (params.background) {
                const owner = ctx.sessionManager.getSessionId();
                for (const job of jobs) {
                  const ctrl = new AbortController();
                  background.set(job.id, { job, ctrl, owner, done: runOne(job, agents.get(job.agent), ws, ctrl.signal, timeoutMs, warn) });
                }
                const text = `Started in background: ''${jobs.map((j) => `''${j.id} (''${j.agent})`).join(", ")}. Keep working, then call subagent_wait to collect the answers.`;
                return { content: [{ type: "text", text }], details: { jobs: jobs.map((j) => ({ id: j.id, agent: j.agent, sessionId: j.sessionId, nodeId: j.nodeId, status: j.status })) } };
              }
              const notify = (msg: string) => {
                warn(msg);
                onUpdate?.({ content: [{ type: "text", text: msg }], details: { jobs } });
              };
              const timer = ticker(jobs, onUpdate);
              try {
                await Promise.all(jobs.map((job) => runOne(job, agents.get(job.agent), ws, outer, timeoutMs, notify)));
              } finally {
                clearInterval(timer);
              }
              emitJoin(jobs);
              return { content: [{ type: "text", text: render(jobs) }], details: { jobs }, isError: jobs.every((j) => !j.ok) };
            },
          });

          pi.registerTool({
            name: "subagent_wait",
            label: "Subagent wait",
            description: "Wait for background subagent jobs and return their answers. Without ids it waits for every uncollected job of this session.",
            parameters: Type.Object({
              ids: Type.Optional(Type.Array(Type.String(), { description: "Job ids from the subagent call, default all" })),
              timeoutMin: Type.Optional(Type.Integer({ description: "Wait limit in minutes, default 30. Jobs keep running after it." })),
            }),
            async execute(_id, params, signal, onUpdate, ctx) {
              const owner = ctx.sessionManager.getSessionId();
              const mine = [...background.values()].filter((b) => b.owner === owner);
              const ids = (params.ids ?? []).map((s) => s.trim()).filter(Boolean);
              const unknown = ids.filter((id) => !mine.some((b) => b.job.id === id));
              const picked = ids.length ? mine.filter((b) => ids.includes(b.job.id)) : mine;
              if (unknown.length || !picked.length) {
                const known = mine.map((b) => b.job.id).join(", ") || "none";
                const text = unknown.length
                  ? `Unknown or already collected job ids: ''${unknown.join(", ")}. Uncollected jobs: ''${known}.`
                  : "No background subagent jobs to wait for. Start them with subagent and background: true.";
                return { content: [{ type: "text", text }], details: { jobs: [] }, isError: true };
              }
              const jobs = picked.map((b) => b.job);
              const stop = AbortSignal.any([signal ?? new AbortController().signal, AbortSignal.timeout(Math.max(1, params.timeoutMin ?? 30) * 60000)]);
              const timer = ticker(jobs, onUpdate);
              try {
                await Promise.race([Promise.all(picked.map((b) => b.done)), aborted(stop)]);
              } finally {
                clearInterval(timer);
              }
              for (const j of jobs) if (finished(j)) background.delete(j.id);
              emitJoin(jobs);
              return { content: [{ type: "text", text: render(jobs) }], details: { jobs }, isError: jobs.every((j) => finished(j) && !j.ok) };
            },
          });

          pi.on("context", (event, ctx) => {
            const owner = ctx.sessionManager.getSessionId();
            const ready = [...background.values()].filter((b) => b.owner === owner && finished(b.job)).map((b) => b.job.id);
            if (ready.length === 0) return;
            const note = { role: "custom", customType: "subagent-done", content: `[Subagents] done: ''${ready.join(", ")}, call subagent_wait to read`, display: false, timestamp: Date.now() };
            return { messages: [...event.messages, note as (typeof event.messages)[number]] };
          });

          pi.on("session_shutdown", async (_event, ctx) => {
            const owner = ctx.sessionManager.getSessionId();
            const mine = [...background.values()].filter((b) => b.owner === owner);
            for (const b of mine) {
              b.ctrl.abort();
              background.delete(b.job.id);
            }
            if (mine.length) await Promise.race([Promise.allSettled(mine.map((b) => b.done)), new Promise((done) => setTimeout(done, 10000).unref())]);
          });
        }
      '';

      subagentReadOnly = ''
        tools: read, grep, find, ls, lsp_definition, lsp_references, lsp_hover, aft_outline, aft_zoom, aft_search, query-docs, resolve-library-id, bash
        permission:
          tools:
            read: allow
            grep: allow
            find: allow
            ls: allow
            lsp_definition: allow
            lsp_references: allow
            lsp_hover: allow
            aft_outline: allow
            aft_zoom: allow
            aft_search: allow
            query-docs: allow
            resolve-library-id: allow
            bash: allow
            edit: deny
            write: deny
      '';

      gatesFile = pkgs.writeText "gates.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
        import { Type } from "typebox";
        import { createHash } from "node:crypto";
        import { appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
        import { homedir } from "node:os";
        import { dirname, isAbsolute, join, relative, resolve } from "node:path";
        ${pipelineCommon}
        type Phase = { run: string; phase: string; nodeId: string } | null;
        type Result = { name: string; ok: boolean; output: string };
        type Finding = { ruleId: string; severity: string; message: string; file: string; range: { start: { line: number } } };
        type Node = { id: string; parents: string[]; kind: "gate"; label: string; run: string; phase?: string; cwd: string; sessionId?: string; status: "running" | "ok" | "fail" | "skipped"; ts: number; pid: number; detail?: string };

        const MUTATORS = new Set(["edit", "write", "apply_patch", "ast_grep_replace", "aft_move", "aft_delete", "aft_import"]);
        const PATH_KEYS = ["path", "file_path", "filePath", "destination", "from", "to"];
        const PATCH_FILE = /^\*\*\* (?:(?:Add|Update|Delete) File|Move to): (.+)$/gm;
        const TEST_FILE = /(_test\.go$|\.golden$|(^|\/)testdata\/)/;
        const QUICK_MS = 5000;
        const QUICK_LINES = 30;
        const REPORT_LINES = 40;
        const MAX_FAILS = 3;
        const SNAPSHOT_CAP = 5000;
        const INTERESTING = /^(--- FAIL|FAIL\b|panic:|ok\s)|\.(go|proto|nix):\d+(:\d+)?|error|undefined:|cannot |expected |unexpected /i;
        const RULES = join(homedir(), ".pi", "rules");
        const GOLANGCI = join(RULES, "go", "golangci.yml");
        const MAX_FINDINGS = 20;

        const clip = (s: string, n: number) => (s.length > n ? `''${s.slice(0, n)}…` : s);
        const prune = (out: string, max: number) => {
          const lines = out.split("\n").map((l) => l.trimEnd()).filter(Boolean);
          const hits = lines.filter((l) => INTERESTING.test(l) && !/^ok\s/.test(l));
          const pick = (hits.length ? hits : lines).slice(0, max).map((l) => clip(l, 240));
          const more = (hits.length ? hits : lines).length - pick.length;
          return pick.join("\n") + (more > 0 ? `\n… ''${more} more lines` : "");
        };
        const sha = (f: string) => {
          try {
            return createHash("sha256").update(readFileSync(f)).digest("hex");
          } catch {
            return "missing";
          }
        };
        const ymls = (dir: string) => {
          try {
            return readdirSync(dir).filter((n) => /\.ya?ml$/.test(n) && n !== "golangci.yml").map((n) => join(dir, n));
          } catch {
            return [];
          }
        };
        const ruleFiles = (top: string) => {
          let langs: string[] = [];
          try {
            langs = readdirSync(RULES);
          } catch {}
          return [...langs.flatMap((l) => ymls(join(RULES, l))), ...ymls(join(homedir(), ".pi", "projects", top.replace(/\//g, "-"), "rules"))];
        };
        const upFind = (dir: string, stop: string, names: string[]) => {
          for (let d = dir; ; d = dirname(d)) {
            if (names.some((n) => existsSync(join(d, n)))) return d;
            if (d === stop || d === dirname(d)) return undefined;
          }
        };
        export default function (pi: ExtensionAPI) {
          let phase: Phase = null;
          let fails = 0;
          let gaveUp = false;
          const changed = new Set<string>();
          const tops = new Map<string, string>();
          const bins = new Map<string, boolean>();
          const snapshots = new Map<string, Map<string, string>>();
          const timeoutMs = () => (Number(process.env.PI_GATES_TIMEOUT_S) || 300) * 1000;

          const run = async (cmd: string, args: string[], cwd: string, timeout: number, signal?: AbortSignal) => {
            try {
              const r = await pi.exec(cmd, args, { cwd, timeout, signal });
              return { code: r.code, out: `''${r.stdout}\n''${r.stderr}`.trim(), stdout: r.stdout, killed: r.killed };
            } catch (e) {
              return { code: -1, out: e instanceof Error ? e.message : String(e), stdout: "", killed: false };
            }
          };
          const has = async (bin: string) => {
            if (!bins.has(bin)) bins.set(bin, (await run("sh", ["-c", `command -v ''${bin}`], homedir(), 3000)).code === 0);
            return bins.get(bin) === true;
          };
          const toplevel = async (dir: string) => {
            if (!tops.has(dir)) {
              const r = await run("git", ["rev-parse", "--show-toplevel"], existsSync(dir) ? dir : homedir(), 5000);
              tops.set(dir, r.code === 0 && existsSync(dir) ? r.out.split("\n")[0] : dir);
            }
            return tops.get(dir) as string;
          };
          const listTests = async (top: string) => {
            const r = await run("git", ["ls-files", "--cached", "--others", "--exclude-standard"], top, 10_000);
            return r.code === 0 ? r.out.split("\n").filter((f) => f && TEST_FILE.test(f)).slice(0, SNAPSHOT_CAP) : [];
          };
          const snapshot = async (cwd: string) => {
            const top = await toplevel(cwd);
            if (!existsSync(join(top, ".git"))) return;
            snapshots.set(top, new Map((await listTests(top)).map((f) => [f, sha(join(top, f))])));
          };

          const pathsOf = (input: Record<string, unknown>, cwd: string) => {
            const out = new Set<string>();
            const add = (v: unknown) => {
              if (typeof v === "string" && v.trim()) out.add(isAbsolute(v) ? v : resolve(cwd, v));
            };
            for (const k of PATH_KEYS) add(input[k]);
            if (Array.isArray(input.files)) for (const f of input.files) add(typeof f === "string" ? f : (f as { path?: unknown })?.path);
            for (const v of Object.values(input)) if (typeof v === "string") for (const m of v.matchAll(PATCH_FILE)) add(m[1].trim());
            return [...out];
          };

          const label = (p: { run: string; parent: string; phase?: string }, text: string, status: Node["status"], ctx: ExtensionContext, id: string, detail?: string) =>
            emitEvent({ id, parents: [p.parent], kind: "gate", label: text, run: p.run, phase: p.phase, cwd: ctx.cwd, sessionId: ctx.sessionManager.getSessionId(), status, detail });
          const parentPhase = () => currentNode(phase);

          pi.events.on("pipeline:phase", (data) => {
            const prev = phase;
            phase = data && typeof data === "object" && typeof (data as { nodeId?: unknown }).nodeId === "string" ? (data as Exclude<Phase, null>) : null;
            if (prev?.phase === "reproduce" && phase?.phase !== "reproduce") for (const top of snapshots.keys()) void snapshot(top);
          });

          pi.on("input", () => {
            fails = 0;
            gaveUp = false;
            return { action: "continue" as const };
          });

          pi.on("agent_start", (_event, ctx) => {
            void snapshot(ctx.cwd);
          });

          pi.on("tool_call", (event, ctx) => {
            if (!phase || !MUTATORS.has(event.toolName)) return;
            const files = pathsOf(event.input as Record<string, unknown>, ctx.cwd);
            if (phase.phase === "reproduce") {
              const code = files.filter((f) => !TEST_FILE.test(f));
              if (code.length === 0) return;
              return { block: true, reason: `Blocked: in phase "reproduce" only test files (*_test.go, testdata/, *.golden) may change, not ''${code.map((f) => relative(ctx.cwd, f)).join(", ")}. Write a test that fails because of the bug and leave the fix for the next phase.` };
            }
            const tests = files.filter((f) => TEST_FILE.test(f));
            if (tests.length === 0) return;
            return { block: true, reason: `Blocked: in phase "''${phase.phase}" test files are read-only (''${tests.map((f) => relative(ctx.cwd, f)).join(", ")}). Change the code under test so the existing tests pass. If a test itself is wrong, call give_up and explain why.` };
          });

          pi.on("tool_result", async (event, ctx) => {
            if (event.isError || !MUTATORS.has(event.toolName)) return;
            const files = pathsOf(event.input, ctx.cwd);
            for (const f of files) changed.add(f);
            let syntax = false;
            const notes = (
              await Promise.all(
                files.filter((f) => /\.(go|nix)$/.test(f) && existsSync(f)).map(async (f) => {
                  const dir = dirname(f);
                  const name = relative(ctx.cwd, f) || f;
                  if (f.endsWith(".nix")) {
                    if (!(await has("nixfmt"))) return "";
                    const r = await run("nixfmt", ["--check", f], dir, QUICK_MS);
                    if (r.code === 0 || r.killed) return "";
                    if (/not formatted/.test(r.out)) return `''${name}: not formatted, run nixfmt on it`;
                    syntax = true;
                    return `''${name}: syntax error\n''${r.out}`;
                  }
                  const fmt = await run("gofmt", ["-l", "-e", f], dir, QUICK_MS);
                  if (fmt.killed) return "";
                  if (fmt.code !== 0) {
                    syntax = true;
                    return `''${name}: syntax error\n''${fmt.out}`;
                  }
                  const lines = fmt.out ? [`''${name}: not gofmt-formatted, run gofmt -w on it`] : [];
                  if (await has("gopls")) {
                    const r = await run("gopls", ["check", f], dir, QUICK_MS);
                    const own = r.killed || !r.out ? undefined : (await addedLines(await toplevel(dir), [f])).get(f);
                    const hits = own ? r.out.split("\n").filter((l) => {
                      const n = Number(/^.+?\.go:(\d+)(?::\d+)?(?:-\S+)?:\s/.exec(l)?.[1] ?? NaN);
                      return own === "all" || own.has(n);
                    }) : [];
                    if (hits.length) lines.push(hits.join("\n"));
                  }
                  return lines.join("\n");
                }),
              )
            ).filter(Boolean);
            if (notes.length === 0) return;
            const text = `[Gates] Diagnostics after this change:\n''${prune(notes.join("\n"), QUICK_LINES)}\n''${syntax ? "Fix the syntax error before anything else." : "Fix these before you finish."}`;
            return { content: [...event.content, { type: "text" as const, text }], structuredContent: event.structuredContent, ...(syntax ? { isError: true } : {}) };
          });

          const testDrift = async (): Promise<Result[]> => {
            if (!phase || phase.phase === "reproduce") return [];
            const out: Result[] = [];
            for (const [top, snap] of snapshots) {
              const now = await listTests(top);
              const names = new Set([...snap.keys(), ...now]);
              const moved = [...names].filter((f) => (snap.get(f) ?? "missing") !== sha(join(top, f)));
              if (moved.length) out.push({ name: `test files unchanged (''${top})`, ok: false, output: `Test files changed outside phase "reproduce", probably through bash:\n''${moved.slice(0, 20).join("\n")}\nRestore them with git checkout -- <file> (or delete new ones) and fix the code instead.` });
            }
            return out;
          };

          const addedLines = async (top: string, files: string[]) => {
            const lines = new Map<string, Set<number> | "all">();
            const diff = await run("git", ["diff", "-U0", "--no-color", "--no-ext-diff", "HEAD", "--", ...files], top, 15_000);
            let cur: Set<number> | undefined;
            for (const l of diff.code === 0 ? diff.out.split("\n") : []) {
              const file = /^\+\+\+ b\/(.+)$/.exec(l);
              if (file) lines.set(resolve(top, file[1]), (cur = new Set()));
              const hunk = /^@@ -\S+ \+(\d+)(?:,(\d+))? @@/.exec(l);
              if (hunk && cur) for (let i = 0, n = hunk[2] === undefined ? 1 : Number(hunk[2]); i < n; i++) cur.add(Number(hunk[1]) + i);
            }
            const tracked = await run("git", ["ls-files", "--", ...files], top, 15_000);
            const known = new Set(tracked.code === 0 ? tracked.out.split("\n").filter(Boolean).map((f) => resolve(top, f)) : []);
            for (const f of files) if (!lines.has(f) && (!known.has(f) || diff.code !== 0)) lines.set(f, "all");
            return lines;
          };

          const standards = async (byTop: Map<string, string[]>, signal?: AbortSignal): Promise<Result | undefined> => {
            const jobs = [...byTop].map(([top, files]) => ({ top, files: files.filter((f) => existsSync(f)), rules: ruleFiles(top) })).filter((j) => j.files.length && j.rules.length);
            if (jobs.length === 0) return undefined;
            if (!(await has("ast-grep"))) return { name: "standards", ok: true, output: "ast-grep is not on PATH, standards rules were skipped." };
            const found: string[] = [];
            let errors = 0;
            for (const { top, files, rules } of jobs) {
              if (signal?.aborted) return undefined;
              const inline = rules.map((f) => readFileSync(f, "utf8").trim()).join("\n---\n");
              const r = await run("ast-grep", ["scan", "--inline-rules", inline, "--json=compact", ...files.map((f) => relative(top, f))], top, timeoutMs(), signal);
              let hits: Finding[] = [];
              try {
                hits = JSON.parse(r.stdout) as Finding[];
              } catch {
                found.push(`ast-grep failed in ''${top}: ''${prune(r.out, 5)}`);
                continue;
              }
              const added = await addedLines(top, files);
              for (const h of hits) {
                const lines = added.get(resolve(top, h.file));
                const line = h.range.start.line + 1;
                if (!lines || (lines !== "all" && !lines.has(line))) continue;
                if (h.severity === "error") errors++;
                found.push(`''${h.severity} ''${h.ruleId} ''${h.file}:''${line}: ''${clip(h.message, 200)}`);
              }
            }
            const shown = found.slice(0, MAX_FINDINGS).join("\n") + (found.length > MAX_FINDINGS ? `\n… ''${found.length - MAX_FINDINGS} more findings` : "");
            return { name: "standards", ok: errors === 0, output: found.length ? `''${shown}''${errors ? "\nFix every error finding on the lines you changed. Warnings and hints are advice." : ""}` : "" };
          };

          const gate = async (cwd: string, signal?: AbortSignal): Promise<Result[]> => {
            const results: Result[] = await testDrift();
            const limit = timeoutMs();
            const step = async (name: string, cmd: string, args: string[], dir: string) => {
              if (signal?.aborted) return;
              const r = await run(cmd, args, dir, limit, signal);
              const ok = r.code === 0 && !r.killed;
              results.push({ name, ok, output: ok ? "" : r.killed ? `timed out after ''${limit / 1000}s or aborted\n''${prune(r.out, 10)}` : prune(r.out, REPORT_LINES) });
            };
            const byTop = new Map<string, string[]>();
            for (const f of changed) {
              const top = await toplevel(existsSync(dirname(f)) ? dirname(f) : cwd);
              byTop.set(top, [...(byTop.get(top) ?? []), f]);
            }
            for (const [top, files] of byTop) {
              const goMods = new Map<string, Set<string>>();
              for (const f of files.filter((x) => x.endsWith(".go") && existsSync(dirname(x)))) {
                const mod = upFind(dirname(f), top, ["go.mod"]);
                if (!mod) continue;
                const rel = relative(mod, dirname(f));
                goMods.set(mod, (goMods.get(mod) ?? new Set()).add(rel ? `./''${rel}` : "."));
              }
              for (const [mod, set] of goMods) {
                const pkgs = [...set];
                const where = relative(top, mod) || ".";
                const buildable = pkgs.filter((p) => readdirSync(join(mod, p)).some((n) => n.endsWith(".go") && !n.endsWith("_test.go")));
                if (buildable.length) {
                  await step(`go build ''${where}`, "go", ["build", ...buildable], mod);
                  if (results.at(-1)?.ok === false) continue;
                }
                const lintCfg = [mod, top].some((d) => [".golangci.yml", ".golangci.yaml", ".golangci.toml"].some((n) => existsSync(join(d, n))));
                const lintArgs = lintCfg ? [] : existsSync(GOLANGCI) ? ["--config", GOLANGCI] : undefined;
                if (lintArgs && (await has("golangci-lint"))) await step(`golangci-lint ''${where}`, "golangci-lint", ["run", "--new-from-rev=HEAD", ...lintArgs, ...pkgs], mod);
                await step(`go test ''${where}`, "go", ["test", "-count=1", "-shuffle=on", ...(process.env.PI_GATES_RACE === "1" ? ["-race"] : []), ...pkgs], mod);
              }
              const bufDirs = new Set(files.filter((f) => f.endsWith(".proto") && existsSync(dirname(f))).map((f) => upFind(dirname(f), top, ["buf.yaml"])).filter((d): d is string => !!d));
              if (bufDirs.size && (await has("buf"))) for (const d of bufDirs) await step(`buf lint ''${relative(top, d) || "."}`, "buf", ["lint"], d);
              const nix = files.filter((f) => f.endsWith(".nix") && existsSync(f));
              if (nix.length && (await has("nixfmt"))) await step(`nixfmt --check ''${top}`, "nixfmt", ["--check", ...nix], top);
            }
            const std = await standards(byTop, signal);
            if (std) results.push(std);
            return results;
          };

          const report = (results: Result[]) =>
            results
              .filter((r) => !r.ok || r.output)
              .map((r) => `### ''${r.name}''${r.ok ? " (advice)" : ""}\n''${r.output}`)
              .join("\n\n");

          const runTracked = async (ctx: ExtensionContext, signal?: AbortSignal) => {
            const p = parentPhase();
            const id = `gate-''${process.pid}-''${Date.now()}`;
            if (p) label(p, "gates", "running", ctx, id);
            const results = await gate(ctx.cwd, signal);
            const ok = results.every((r) => r.ok);
            if (signal?.aborted) {
              if (p) label(p, "gates", "skipped", ctx, id, "aborted");
              return undefined;
            }
            if (p) label(p, "gates", ok ? "ok" : "fail", ctx, id, results.filter((r) => !r.ok).map((r) => r.name).join(", ") || undefined);
            if (ok) changed.clear();
            return { ok, results };
          };

          pi.on("agent_before_settle", async (event, ctx) => {
            if (event.outcome !== "completed" || gaveUp || fails >= MAX_FAILS || !event.context.canContinue) return;
            if (changed.size === 0 && !(phase && phase.phase !== "reproduce" && snapshots.size)) return;
            const res = await runTracked(ctx, ctx.signal);
            if (!res || ctx.signal?.aborted) return;
            if (res.ok) {
              fails = 0;
              return;
            }
            fails++;
            const tail =
              fails >= MAX_FAILS
                ? `Verification still fails after ''${MAX_FAILS} attempts. Stop editing now. Tell the user honestly that the change is not verified: list the failing checks above, what you tried and what you suspect. Do not claim success.`
                : `Fix the cause in the code (not in the tests), then finish again. Attempt ''${fails} of ''${MAX_FAILS}. If you are blocked, call give_up with the reason.`;
            return {
              entries: [{ type: "custom_message" as const, customType: "gates-report", content: `[Gates] Verification failed after your changes:\n\n''${report(res.results)}\n\n''${tail}`, display: true, details: res }],
              continue: true,
            };
          });

          pi.registerTool({
            name: "run_gates",
            label: "run gates",
            description: "Build, lint and test the packages changed in this run (go build, golangci-lint, go test, buf lint, nixfmt --check). Returns which checks failed with the first error lines. No parameters.",
            parameters: Type.Object({}),
            async execute(_id, _params, signal, _onUpdate, ctx) {
              if (changed.size === 0 && (await testDrift()).length === 0) {
                return { content: [{ type: "text" as const, text: "No files changed since the last green gate. Nothing to check." }], details: { ok: true, results: [] as Result[] } };
              }
              const res = await runTracked(ctx, signal);
              if (!res) return { content: [{ type: "text" as const, text: "Gates aborted." }], details: { ok: false, results: [] as Result[] }, isError: true };
              const summary = res.results.map((r) => `''${r.ok ? "ok  " : "FAIL"} ''${r.name}`).join("\n");
              const text = res.ok ? `All gates passed:\n''${summary}''${report(res.results) ? `\n\n''${report(res.results)}` : ""}` : `Gates failed:\n''${summary}\n\n''${report(res.results)}\nFix the cause in the code, not in the tests, then run run_gates again.`;
              return { content: [{ type: "text" as const, text }], details: res };
            },
          });

          pi.registerTool({
            name: "give_up",
            label: "give up",
            description: "Stop working on the task honestly when you cannot make it pass or are blocked. Give the reason in one or two sentences.",
            parameters: Type.Object({ reason: Type.String({ description: "What blocks you and what you tried" }) }),
            async execute(_id, params, _signal, _onUpdate, ctx) {
              gaveUp = true;
              pi.appendEntry("gates-give-up", { reason: params.reason, changed: [...changed] });
              const p = parentPhase();
              if (p) label(p, "give up", "skipped", ctx, `giveup-''${process.pid}-''${Date.now()}`, clip(params.reason, 300));
              return {
                content: [{ type: "text" as const, text: "Recorded. Do not edit any more files. Now explain to the user what blocked you, what you tried, which checks still fail and what state the files are in, then stop." }],
                details: { reason: params.reason },
              };
            },
          });
        }
      '';

      harnessToolsFile = pkgs.writeText "tools.ts" /* typescript */ ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
        import { Type } from "typebox";
        import { randomUUID } from "node:crypto";
        import { appendFileSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
        import { homedir, tmpdir } from "node:os";
        import { basename, dirname, join, resolve } from "node:path";
        ${pipelineCommon}
        const HOME = process.env.HOME || homedir();
        const MAX_LINES = 60;
        const SAMPLE_LINES = 40;
        const MAX_NOTES = 60;

        const cap = (lines: string[], n = MAX_LINES) => (lines.length > n ? [...lines.slice(0, n - 1), `… ''${lines.length - n + 1} more lines cut`] : lines).join("\n");
        const clip = (s: string, n: number) => (s.length > n ? s.slice(0, n - 1) + "…" : s);
        const ok = (text: string, details: unknown = {}) => ({ content: [{ type: "text" as const, text }], details });
        const fail = (text: string) => ({ content: [{ type: "text" as const, text: "Error: " + text }], details: { error: true } });

        const stripGoComments = (src: string) => {
          let out = "";
          let i = 0;
          while (i < src.length) {
            const c = src[i];
            const d = src[i + 1];
            if (c === "/" && d === "/") {
              while (i < src.length && src[i] !== "\n") i++;
            } else if (c === "/" && d === "*") {
              const end = src.indexOf("*/", i + 2);
              const body = end < 0 ? src.slice(i) : src.slice(i, end + 2);
              out += body.includes("\n") ? "\n" : " ";
              i = end < 0 ? src.length : end + 2;
            } else if (c === '"' || c === "'" || c === "`") {
              let j = i + 1;
              while (j < src.length && src[j] !== c) {
                if (src[j] === "\\" && c !== "`") j++;
                if (c !== "`" && src[j] === "\n") break;
                j++;
              }
              out += src.slice(i, j + 1);
              i = j + 1;
            } else {
              out += c;
              i++;
            }
          }
          return out.split("\n").map((l) => l.replace(/\s+$/, "")).join("\n").replace(/\n{3,}/g, "\n\n");
        };

        type Decl = { name: string; kind: string; text: string };

        const goDecls = (src: string): Decl[] => {
          const lines = stripGoComments(src).split("\n");
          const out: Decl[] = [];
          let i = 0;
          while (i < lines.length) {
            const m = lines[i].match(/^(func|type)\s+(?:\([^)]*\)\s*)?([A-Za-z_]\w*)/);
            if (!m) {
              i++;
              continue;
            }
            let j = i;
            if (/[{(]\s*$/.test(lines[i])) {
              j = i + 1;
              while (j < lines.length && !/^[})]/.test(lines[j])) j++;
            }
            out.push({ name: m[2], kind: m[1] === "func" && /^func\s*\(/.test(lines[i]) ? "method" : m[1], text: lines.slice(i, j + 1).join("\n") });
            i = j + 1;
          }
          return out;
        };

        const tokens = (s: string) => new Set(s.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean));

        export default function (pi: ExtensionAPI) {
          const git = (cwd: string, args: string[], signal?: AbortSignal, timeout = 60000) => pi.exec("git", args, { cwd, signal, timeout });

          const slugOf = async (cwd: string) => {
            const r = await git(cwd, ["rev-parse", "--show-toplevel"]);
            const top = r.code === 0 ? r.stdout.trim() : cwd;
            return { top, slug: top.replace(/\//g, "-") };
          };

          pi.registerTool({
            name: "why",
            label: "Why",
            description: "Show the git history of a file or line range: commits, authors, dates, messages, MR/issue refs and the changed lines. Use before changing code whose purpose is unclear.",
            parameters: Type.Object({
              path: Type.String({ description: "File path relative to the repository" }),
              lines: Type.Optional(Type.String({ description: 'Line range like "40-80"; omit for whole-file history' })),
            }),
            async execute(_id, params, signal, _u, ctx) {
              const { top } = await slugOf(ctx.cwd);
              const file = resolve(ctx.cwd, params.path);
              if (!existsSync(file)) return fail(`file not found: ''${params.path}. Pass a path relative to the repo root.`);
              const rel = file.startsWith(top + "/") ? file.slice(top.length + 1) : params.path;
              const fmt = "--format=@@@%h%x1f%as%x1f%an%x1f%s%x1f%b%x1e";
              let args: string[];
              if (params.lines) {
                const m = params.lines.match(/^(\d+)(?:-(\d+))?$/);
                if (!m) return fail('lines must look like "40-80"');
                args = ["log", "-n", "6", `-L''${m[1]},''${m[2] ?? m[1]}:''${rel}`, fmt];
              } else {
                args = ["log", "--follow", "-n", "8", fmt, "--", rel];
              }
              const r = await git(top, args, signal);
              if (r.code !== 0) return fail(clip(r.stderr.trim() || "git log failed", 300) + ". Is the file tracked and the range inside it?");
              const commits = r.stdout.split("@@@").slice(1);
              if (!commits.length) return ok("No history: file is new or untracked.");
              const refs = new Set<string>();
              const out: string[] = [];
              for (const c of commits) {
                const [meta, rest = ""] = c.split("\x1e");
                const [hash, date, author, subject, body = ""] = meta.split("\x1f");
                out.push(`''${hash} ''${date} ''${author}: ''${clip(subject, 100)}`);
                for (const l of body.split("\n").filter((x) => x.trim()).slice(0, 2)) out.push("    " + clip(l.trim(), 110));
                for (const x of (subject + "\n" + body).match(/![0-9]+|#\d+|\b[A-Z][A-Z0-9]+-\d+\b/g) ?? []) refs.add(x);
                if (params.lines) {
                  const changed = rest.split("\n").filter((l) => /^[+-]/.test(l) && !/^(\+\+\+|---)/.test(l));
                  for (const l of changed.slice(0, 6)) out.push("    " + clip(l, 110));
                  if (changed.length > 6) out.push(`    … ''${changed.length - 6} more changed lines`);
                }
              }
              if (refs.size) out.push(`Refs: ''${[...refs].join(", ")}`);
              return ok(cap(out), { commits: commits.length });
            },
          });

          pi.registerTool({
            name: "exemplars",
            label: "Exemplars",
            description: "Find 2-3 existing code samples of the same kind (comments stripped) to imitate before writing new code. Pass an existing or planned file path (e.g. internal/user/user_repo.go) or a kind hint (e.g. handler, _repo.go).",
            parameters: Type.Object({ target: Type.String({ description: "File path or kind hint" }) }),
            async execute(_id, params, signal, _u, ctx) {
              const { top } = await slugOf(ctx.cwd);
              const ls = await git(top, ["ls-files", "*.go"], signal);
              if (ls.code !== 0) return fail("not a git repository with Go files.");
              const files = ls.stdout.split("\n").filter(Boolean);
              const abs = resolve(ctx.cwd, params.target);
              const isPath = /\.go$/.test(params.target);
              const rel = isPath ? (abs.startsWith(top + "/") ? abs.slice(top.length + 1) : params.target) : "";
              const name = isPath ? basename(rel) : params.target;
              const suffix = isPath ? (name.includes("_") ? name.slice(name.lastIndexOf("_")) : name) : params.target.endsWith(".go") ? params.target : `''${params.target.replace(/^_/, "")}`;
              const matches = (f: string) => (isPath || params.target.endsWith(".go") ? basename(f).endsWith(suffix) : basename(f).includes(suffix));
              const dir = isPath ? dirname(rel) : ".";
              const hist = await git(top, ["log", "--name-only", "--format=@%ct", "-n", "400", "--", "*.go"], signal);
              const recency = new Map<string, number>();
              let ts = 0;
              for (const l of hist.stdout.split("\n")) {
                if (l.startsWith("@")) ts = Number(l.slice(1));
                else if (l && !recency.has(l)) recency.set(l, ts);
              }
              let pool = files.filter((f) => f !== rel && matches(f) && (isPath || !/_test\.go$/.test(f) || suffix.includes("test")));
              if (!pool.length && isPath) pool = files.filter((f) => f !== rel && dirname(f) === dir && !/_test\.go$/.test(f));
              if (!pool.length) return fail(`no files matching "''${suffix}". Try a broader hint like "handler" or "service".`);
              const score = (f: string) => (dirname(f) === dir ? 1e12 : 0) + (recency.get(f) ?? 0);
              const picked = pool.sort((a, b) => score(b) - score(a)).slice(0, 3);
              const want = new Set<string>();
              if (existsSync(abs) && isPath) for (const d of goDecls(readFileSync(abs, "utf8"))) tokens(d.name).forEach((t) => want.add(t));
              for (const t of tokens(basename(name, ".go"))) want.add(t);
              const out: string[] = [];
              for (const f of picked) {
                let decls: Decl[] = [];
                try {
                  decls = goDecls(readFileSync(join(top, f), "utf8"));
                } catch {}
                if (!decls.length) continue;
                const sim = (d: Decl) => [...tokens(d.name)].filter((t) => want.has(t)).length * 100 + (/^[A-Z]/.test(d.name) ? 10 : 0) + Math.min(d.text.split("\n").length, 30);
                const best = decls.sort((a, b) => sim(b) - sim(a))[0];
                const body = best.text.split("\n");
                out.push(`--- ''${f} (''${best.kind} ''${best.name})`);
                out.push(...body.slice(0, SAMPLE_LINES));
                if (body.length > SAMPLE_LINES) out.push(`… ''${body.length - SAMPLE_LINES} more lines`);
              }
              return ok(out.length ? cap(out, 130) : "Matching files have no top-level func/type.", { files: picked });
            },
          });

          pi.registerTool({
            name: "project_notes",
            label: "Project notes",
            description: "Personal notes about this project, kept outside the repo. Use action read to recall build/test quirks, add to save a short durable learning (one line).",
            parameters: Type.Object({
              action: Type.Union([Type.Literal("read"), Type.Literal("add")]),
              text: Type.Optional(Type.String({ description: "One-line note, required for add" })),
            }),
            async execute(_id, params, _s, _u, ctx) {
              const { slug } = await slugOf(ctx.cwd);
              const dir = join(HOME, ".pi", "projects", slug);
              const file = join(dir, "notes.md");
              let lines: string[] = [];
              try {
                lines = readFileSync(file, "utf8").split("\n").filter((l) => l.startsWith("- "));
              } catch {}
              if (params.action === "read") return ok(lines.length ? cap(lines) : "No notes yet.");
              const text = (params.text ?? "").replace(/\s+/g, " ").trim();
              if (!text) return fail('add needs "text" with one short line.');
              const body = text.length > 300 ? text.slice(0, 299) + "…" : text;
              if (lines.some((l) => l.replace(/^- \S+ /, "") === body)) return ok("Already noted.");
              lines.push(`- ''${new Date().toISOString().slice(0, 10)} ''${body}`);
              lines = lines.slice(-MAX_NOTES);
              mkdirSync(dir, { recursive: true });
              writeFileSync(file, lines.join("\n") + "\n");
              return ok(`Saved (''${lines.length}/''${MAX_NOTES} notes).`);
            },
          });

          pi.registerTool({
            name: "bisect",
            label: "Bisect",
            description: "Find the first commit where a test command starts failing. Runs in a temporary git worktree; your working tree is untouched. Build failures are skipped, each step is retried to filter flaky tests.",
            parameters: Type.Object({
              good: Type.String({ description: "Known good ref (tag, branch or hash)" }),
              command: Type.String({ description: "Shell command, exit 0 means good, e.g. go test ./pkg -run TestX" }),
              bad: Type.Optional(Type.String({ description: "Known bad ref, default HEAD" })),
            }),
            async execute(_id, params, signal, onUpdate, ctx) {
              const { top, slug } = await slugOf(ctx.cwd);
              const bad = params.bad || "HEAD";
              for (const ref of [params.good, bad]) {
                const v = await git(top, ["rev-parse", "--verify", "--quiet", ref + "^{commit}"]);
                if (v.code !== 0) return fail(`unknown ref "''${ref}". Use a tag, branch or commit hash from git log.`);
              }
              const root = join(HOME, ".pi", "worktrees");
              mkdirSync(root, { recursive: true });
              const id = `''${slug}-bisect-''${randomUUID().slice(0, 8)}`;
              const wt = join(root, id);
              const cmdFile = wt + ".cmd.sh";
              const runFile = wt + ".run.sh";
              const logFile = wt + ".out";
              const node = id;
              const run = process.env.PI_PIPELINE_RUN || id;
              const parents = process.env.PI_PIPELINE_NODE ? [process.env.PI_PIPELINE_NODE] : [];
              const ev = (status: string, detail?: string) => emitEvent({ id: node, parents, kind: "step", label: "bisect " + clip(params.command, 40), run, cwd: top, status, detail });
              const timeoutS = Number(process.env.PI_BISECT_TIMEOUT_S) || 1800;
              ev("running");
              onUpdate?.({ content: [{ type: "text", text: "bisect started in " + wt }], details: {} });
              let verdict = "";
              try {
                const add = await git(top, ["worktree", "add", "--detach", wt, bad]);
                if (add.code !== 0) throw new Error("worktree add failed: " + clip(add.stderr.trim(), 200));
                writeFileSync(cmdFile, params.command + "\n");
                writeFileSync(
                  runFile,
                  [
                    "for i in 1 2 3; do",
                    `  sh ''${cmdFile} > ''${logFile} 2>&1; rc=$?`,
                    "  [ $rc -eq 0 ] && exit 0",
                    "done",
                    `grep -Eq '\\[build failed\\]|\\[setup failed\\]|^# [A-Za-z./]|build failed|cannot find package' ''${logFile} && exit 125`,
                    "exit 1",
                    "",
                  ].join("\n"),
                );
                const start = await git(wt, ["bisect", "start", bad, params.good]);
                if (start.code !== 0) throw new Error(clip((start.stderr || start.stdout).trim(), 300) + " Good ref must be an ancestor of bad.");
                const res = await pi.exec("git", ["bisect", "run", "sh", runFile], { cwd: wt, signal, timeout: timeoutS * 1000 });
                if (res.killed) throw new Error(`timed out or aborted after ''${timeoutS}s (PI_BISECT_TIMEOUT_S)`);
                const m = res.stdout.match(/([0-9a-f]{7,40}) is the first bad commit/);
                if (!m) {
                  const tail = res.stdout.trim().split("\n").slice(-6).join("\n");
                  throw new Error("no culprit found. The command may fail on both refs or only by build errors.\n" + tail);
                }
                const show = await git(wt, ["show", "--stat", "--format=%h %as %an%n%s%n%b", m[1]]);
                verdict = "First bad commit:\n" + cap(show.stdout.trim().split("\n"), 30);
                ev("ok", m[1].slice(0, 12));
              } catch (e: any) {
                ev("fail", clip(String(e?.message ?? e), 200));
                verdict = "Error: " + String(e?.message ?? e);
              } finally {
                await git(top, ["worktree", "remove", "--force", wt]);
                rmSync(wt, { recursive: true, force: true });
                await git(top, ["worktree", "prune"]);
                for (const f of [cmdFile, runFile, logFile]) rmSync(f, { force: true });
              }
              return ok(verdict, { error: verdict.startsWith("Error") });
            },
          });

          pi.registerTool({
            name: "flaky",
            label: "Flaky",
            description: "Run a Go test many times with shuffle and report whether each test is stable-pass, stable-fail or flaky.",
            parameters: Type.Object({
              package: Type.String({ description: "Go package, e.g. ./internal/user" }),
              test: Type.String({ description: "Test name regex, e.g. TestCreate" }),
              count: Type.Optional(Type.Integer({ description: "Runs, default 10", minimum: 2, maximum: 100 })),
            }),
            async execute(_id, params, signal, _u, ctx) {
              const n = Math.min(100, Math.max(2, params.count ?? 10));
              const goArgs = ["test", "-count=" + n, "-shuffle=on", "-run", params.test, ...(process.env.PI_GATES_RACE === "1" ? ["-race"] : []), params.package];
              const have = await pi.exec("sh", ["-c", "command -v gotestsum"], { cwd: ctx.cwd });
              let raw: string;
              let res;
              if (have.code === 0) {
                const jf = join(tmpdir(), `flaky-''${randomUUID()}.jsonl`);
                res = await pi.exec("gotestsum", ["--jsonfile", jf, "--format", "dots", "--", ...goArgs.slice(1)], { cwd: ctx.cwd, signal, timeout: 1200000 });
                try {
                  raw = readFileSync(jf, "utf8");
                } catch {
                  raw = "";
                }
                rmSync(jf, { force: true });
              } else {
                res = await pi.exec("go", [goArgs[0], "-json", ...goArgs.slice(1)], { cwd: ctx.cwd, signal, timeout: 1200000 });
                raw = res.stdout;
              }
              if (res.killed) return fail("go test timed out or was aborted. Lower count or narrow the test regex.");
              const stats = new Map<string, { pass: number; fail: number }>();
              const outputs: string[] = [];
              for (const l of raw.split("\n")) {
                if (!l.startsWith("{")) continue;
                let e: any;
                try {
                  e = JSON.parse(l);
                } catch {
                  continue;
                }
                if (e.Action === "output" && !e.Test && /build failed|\[setup failed\]|^#|\.go:\d+/.test(e.Output)) outputs.push(e.Output.trimEnd());
                if (!e.Test || (e.Action !== "pass" && e.Action !== "fail")) continue;
                const s = stats.get(e.Test) ?? { pass: 0, fail: 0 };
                s[e.Action as "pass" | "fail"]++;
                stats.set(e.Test, s);
              }
              if (!stats.size) {
                const why = outputs.length ? outputs : (res.stderr || res.stdout).trim().split("\n");
                return fail("no tests ran (build error or wrong package/regex):\n" + cap(why.slice(0, 15), 15));
              }
              const rows = [...stats].map(([name, s]) => ({ name, ...s, kind: s.fail === 0 ? "stable-pass" : s.pass === 0 ? "stable-fail" : "flaky" }));
              rows.sort((a, b) => ({ flaky: 0, "stable-fail": 1, "stable-pass": 2 })[a.kind as "flaky"] - ({ flaky: 0, "stable-fail": 1, "stable-pass": 2 })[b.kind as "flaky"]);
              const out = [`''${params.package} -run ''${params.test} x''${n}''${process.env.PI_GATES_RACE === "1" ? " -race" : ""}`];
              for (const r of rows) out.push(`''${r.kind.padEnd(11)} pass=''${r.pass} fail=''${r.fail}  ''${r.name}`);
              if (rows.some((r) => r.kind === "flaky")) out.push("Flaky: likely shared state, ordering, time or goroutine race; rerun with PI_GATES_RACE=1.");
              return ok(cap(out), { results: rows });
            },
          });
        }
      '';

      pipelineFile = pkgs.writeText "pipeline.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext, ExtensionToolContext } from "@earendil-works/pi-coding-agent";
        import { Type } from "typebox";
        import { createHash, randomUUID } from "node:crypto";
        import { appendFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
        import { homedir } from "node:os";
        import { basename, dirname, isAbsolute, join, resolve } from "node:path";
        import { checkCommand } from "${piPlan}/src/safety.ts";
        ${pipelineCommon}
        const PHASES = ["triage", "localize", "reproduce", "design", "checkpoint", "plan", "implement", "verify", "review", "regress", "report", "retro"] as const;
        type Phase = (typeof PHASES)[number];
        type Status = "running" | "ok" | "fail" | "skipped";
        type Kind = "arch" | "scenario" | "rival" | "expect" | "local" | "constraint";
        type DItem = { id: string; kind: Kind; src: string; text: string; open: boolean };
        type Found = { tag: "arch" | "local"; src: string; text: string };
        type State = {
          run: string;
          task: string;
          issue?: string;
          root: string;
          phase: Phase;
          node: string;
          parent: string;
          seq: number;
          fails: number;
          snapshot: Record<string, string>;
          mark?: Record<string, string>;
          kind?: string;
          criteria?: string[];
          files?: string[];
          localized?: string;
          repros: string[];
          hypotheses?: string;
          skip?: string;
          brief?: string;
          plan?: string;
          touched?: string[];
          design?: string;
          checked?: boolean;
          estimate?: number;
          planEstimate?: number;
          round: number;
          items: DItem[];
          ideas: string[];
          rival?: number;
          experts?: boolean;
          decision?: string;
          questions?: string;
          pending?: string;
          inputs: number;
          dups: { id: string; name: string; of: string }[];
          news: { id: string; what: string }[];
          answers: Record<string, string>;
          findings?: Found[];
          fixing?: boolean;
          localRound: number;
          reviewLines?: number;
          reviewFiles?: string[];
          mutation?: string;
          stress?: string;
          res: Res[];
          read: string[];
          calls: string[];
          used: string[];
          skips: Record<string, string>;
          down: string[];
          log: { k: string; phase: Phase; text: string; resolved?: boolean }[];
          timeline: { phase: Phase; at: number }[];
          facts?: Fact[];
          hfacts?: Fact[];
          enforced?: Record<string, Phase>;
          gates?: Record<string, { ok: boolean; sig: string }>;
          resolution?: string;
          report?: string;
          gaveUp?: boolean;
        };
        type Item = { type: string; evidence: string; gap: string; proposal: string; target: string };
        type Msg = {
          role?: string;
          toolName?: string;
          isError?: boolean;
          model?: string;
          stopReason?: string;
          errorMessage?: string;
          usage?: { input?: number; cacheRead?: number; reasoning?: number };
          content?: { type: string; name?: string; arguments?: unknown; text?: string }[] | string;
        };
        type Fact = { text: string; resolved: boolean };
        type Res = { kind: "skill" | "mcp"; name: string; desc: string; path?: string; off?: boolean; manual?: boolean };
        type Pick = { res: Res; why: string; must?: boolean; fixed?: boolean };
        type Check = { ok: false; why: string } | { ok: true; note?: string; next?: Phase; status?: Status; wait?: string };
        type Job = { id?: string; agent?: string; task?: string; sessionId?: string; status?: string; ok?: boolean; answer?: string; error?: string };
        type Entry = { type: string; customType?: string; modelId?: string; data?: { state?: State | null; mode?: string; cutoff?: unknown }; message?: Msg };

        const READONLY = new Set<Phase>(["triage", "localize", "design", "checkpoint", "plan", "report", "retro"]);
        const AGENTS = ${piAgentsJs};
        const MAX_FAILS = 5;
        const MAX_ROUNDS = 3;
        const MAX_LOCAL = 2;
        const EVERY = 8;
        const TEST_CMD = /\b(go test|gotestsum|pytest|py\.test|cargo test|cargo nextest|jest|vitest|npm (run )?test|pnpm (run )?test|yarn test|make test|bats|ctest|mvn test|gradle test)\b/;
        const NOT_RUN = /command not found|no test files|matched no packages|\[setup failed\]|cannot find package|no required module provides|no tests to run|collected 0 items|ERROR: file or directory not found/i;
        const PREFIX: Record<Kind, string> = { arch: "A", scenario: "S", rival: "R", expect: "E", local: "L", constraint: "K" };

        const GUIDE: Record<Phase, string> = {
          triage:
            "Work as the skill triage does for this one ticket: gather context, verify the claim against the code (for a bug, the code path that produces it) and write its agent brief. Skip its tracker steps (labels, states, comments, setup) and never ask the user. Edits are blocked. Call advance_phase with summary: the type (bug, feature, refactor or docs) as the first word, then the brief in at most 12 lines (summary, current and desired behavior, key interfaces, out of scope, verification result), then a line `Acceptance criteria:` followed by a numbered list (`1. ...`) of checkable criteria taken from the task.",
          localize:
            "Find the code that must change with aft_search, aft_outline, aft_zoom and lsp_references. A bug follows phase 1 of the skill diagnosing-bugs: find the code path of the symptom and the seam a red test can reach, no theories yet. A feature or refactor names the public seams of the skill tdd. Edits are blocked. Call advance_phase with summary: each file to change as a repo-relative path with one line why, then the seams.",
          reproduce:
            "Only test files may be edited. A bug follows phases 1-3 of the skill diagnosing-bugs: the feedback loop is a failing Go test at the seam that reaches the bug, run and minimised; then rank 3-5 falsifiable hypotheses in the summary, one per line `1. If <X> is the cause, then <changing Y> makes the test pass`. A feature or refactor follows the skill tdd: one failing table-driven Go test at the first seam, red before green. Check it fails for the expected reason, not a build error elsewhere. Call advance_phase with evidence: the exact narrow test command you already ran, for example `go test ./pkg/x -run TestY -count=1`. For refactor or docs tasks you may pass evidence `skip: <why no behavior changes>` instead.",
          design:
            "You are the designer. Edits are blocked. Think the change through with the vocabulary of the skill codebase-design (module, interface, depth, seam, adapter, leverage, locality): name the seam, keep the interface small. The rival agent designs it a second time under a different constraint, as in its DESIGN-IT-TWICE. Call advance_phase with summary = the design doc, each section starting with its heading line:\n" +
            "Approach: what changes and how, with a line `Estimated diff: <N> lines` (non-test lines).\n" +
            "Why this is the right one:\n" +
            "Rejected alternatives: at least 2 bullets, one `minimal change` and one `reuse existing code`, each `- <alternative>: <concrete reason it loses>`.\n" +
            "Impact: callers, contracts (proto, swagger, migrations, config), concurrency, error and partial-failure paths, backward compatibility. Write `none` where nothing changes.\n" +
            "Test strategy: bullets mapping every criterion C<n> to a test at a named seam.\n" +
            "Anticipated objections: what a tester and a teammate at the daily would raise, each with your answer.\n" +
            "Critic, tester, rival and psychologist agents then check the design. A rejected design is reworked and resubmitted whole, answering every listed item by id.",
          checkpoint:
            "This is the only time the run asks the user. Follow the skill grilling for exactly one round: the frontier is every open decision of this run (unresolved items, the approach against its rejected alternatives, the test seams, scope). Facts are yours to find with read-only tools, only decisions go to the user. Edits are blocked. Call advance_phase with summary: the questions, each `Q<n>: <question worded so that yes accepts your recommendation>` followed by a line `Recommended: <your answer>`. The pipeline then returns the checkpoint screen with your questions: show it to the user as is and end your turn. The user's reply settles the whole frontier.",
          plan:
            "Edits are blocked. Slice the work as the skill to-tickets does, locally: tracer-bullet vertical slices, each a complete verifiable path with its blocking edges; a proto, swagger or migration change goes expand–contract (add the new form, migrate the callers, then remove the old). Nothing is published and the user is not quizzed. Call advance_phase with summary: a numbered plan of at most 5 slices (`1. ...`), each naming the file, how it is verified and `blocked by: <n or none>`, a line `Estimated diff: <N> lines` (non-test lines), and a line `E<n>: adopt <how>` or `E<n>: decline <why>` for every open expert expectation.",
          implement:
            "Follow the skill implement with the skill tdd, slice by slice in plan order: red before green, no test at a seam the checkpoint did not confirm, refactoring is not part of the loop. Its commit and code-review steps are the pipeline's. Run lsp_diagnostics after each edit, never weaken the reproduce tests and remove every `[DEBUG-...]` log you added. When the repro commands pass, call advance_phase with summary: what changed (path:line), and evidence: one line per acceptance criterion, `C1: TestName` or `C1: path/file.go:40 because <one line>`. The pipeline checks new exported names, files, packages and dependencies, then runs the gates, the repro commands, stress and mutation tests and the review.",
          verify: "Fix the failures above, then call advance_phase again with summary: what you fixed and the answers the pipeline asked for, and evidence: one line per acceptance criterion, `C1: TestName` or `C1: path/file.go:40 because <one line>`.",
          review:
            "The review follows the skill code-review on two axes: Spec by gopnik (also line by line) and Standards by psychologist (a documented repo standard overrides the baseline). Findings stay per axis as written, do not merge or rerank them. Fix each [local] finding in place now (edits are allowed while findings are open) or dismiss it. Then call advance_phase with summary: one line per finding, `F1: fix <what you changed>` or `F1: dismiss <why it is not a problem>`. The changed hunks are reviewed again (at most 2 rounds). Fixes larger than 30% of the diff send the task back to design.",
          regress: "Fix real regressions and call advance_phase again. If a failure looks unrelated to the change, run the flaky tool on that test first. If flaky confirms it, call advance_phase with evidence `flaky: <TestNames>`.",
          report:
            "Edits are blocked. Write the final report in the template of the skill pr, for the chat only (nothing is pushed or published): `## Summary` with the smallest sketch or tree of the change (path:line), `## Evidence` with Before (the repro failing) and After (repro, gates and regress passing), `## Merge Danger` with `Door: one-way` or `Door: two-way`, `Blast Radius: <one word>` and what is left. Call advance_phase with summary: that report.",
          retro:
            "Edits are blocked. Using only the facts above, write what the agents of this run and the harness lacked, sorted as the skill retro does: a mechanical gap gets a deterministic check (rule or tool), a judgement call gets a standard (skill, agents_md or doc), a steering line that changes nothing is a no-op to remove. Skill and AGENTS.md text follows the skill writing-for-agents. Every `design missed` fact needs an item whose gap says why the design missed it. Call advance_phase with summary: at most 7 items, each exactly these lines:\ntype: skill|agents_md|doc|tool|rule|harness\nevidence: F<n>[,H<m>]\ngap: one line\nproposal: the concrete text to add (SKILL.md section, AGENTS.md line, doc paragraph, ast-grep rule or harness change), at most 15 lines\ntarget: path\nNo item without evidence. agents_md only for facts that cannot be read from the code. harness items cite H facts and target a concrete file and setting (pi.nix <extension> <what>, ~/.pi/rules/<file>, mcp.json <server>). If nothing caused friction, the summary is just `none`.",
        };

        const NEED: Record<Phase, string> = {
          triage: "summary starting with bug, feature, refactor or docs, with a numbered `Acceptance criteria:` list.",
          localize: "summary naming the existing files to change.",
          reproduce: "evidence = a test command that fails now, or `skip: <reason>` for refactor or docs; for a bug, 3-5 ranked `If ... then ...` hypotheses in the summary.",
          design: "summary = the design doc with all six sections, answering every open item by id.",
          checkpoint: "one round of `Q<n>:` questions, each with `Recommended:`, then the user's decision; while waiting for it, end your turn.",
          plan: "summary with a numbered plan of at most 5 slices, each with `blocked by:`, `Estimated diff: <N> lines` and an answer for every open E<n>.",
          implement: "a changed non-test file, passing repro commands, answers to every D<n>/N<n> and evidence mapping every criterion C<n> to a test or path:line.",
          verify: "gates ok, repro commands passing, no tagged debug logs, stable tests, no surviving mutants in changed code and evidence mapping every criterion C<n>.",
          review: "every finding F<n> marked `fix` or `dismiss` in the summary.",
          regress: "go tests of the changed and dependent packages passing.",
          report: "summary with the report in the pr template: Summary, Evidence, Merge Danger with the door and the blast radius.",
          retro: "retro items (type, evidence, gap, proposal, target) citing fact ids, or `none`.",
        };

        const STOP = new Set(["добавл", "создан", "измене", "сервис", "исполь", "пользо", "говори", "когда", "напиши", "тригге", "задача", "service", "create", "update", "should", "with", "from", "that", "this", "when", "which", "core", "protei", "files", "file", "code"]);
        const IMPORTS = /^\+\s*(import\b|(\w+\s+)?"[\w.-]+\.[a-z]{2,}\/[^"]*"\s*$|from\s+\S+\s+import\b|.*\brequire\()/m;
        const SKILL_PHASES = new Set<Phase>(["reproduce", "implement", "report"]);

        const SKILL_HINTS: { phases: Phase[]; paths?: RegExp; match: RegExp; why: string }[] = [
          { phases: ["reproduce"], match: /test|тест/i, why: "this phase writes a test" },
          { phases: ["implement"], paths: /\.proto$/, match: /proto|контракт/i, why: ".proto files" },
          { phases: ["implement"], paths: /swagger|openapi|(^|\/)api\/|handler/i, match: /swagger|openapi|api-command/i, why: "API or swagger files" },
          { phases: ["implement"], paths: /migrat|\.sql$/i, match: /migrat|миграц/i, why: "migrations" },
          { phases: ["implement"], paths: /uc-config|(^|\/)configs?\/|config[^/]*\.ya?ml$/i, match: /config|конфиг/i, why: "config files" },
          { phases: ["implement"], paths: /logger\.ya?ml|logs-collector/i, match: /logger|логи/i, why: "logger config" },
          { phases: ["implement", "report"], paths: /(^|\/)docs\/|\.md$/i, match: /docs|документац/i, why: "docs files" },
          { phases: ["report"], match: /docs|документац/i, why: "docs for the change" },
        ];

        const notDocs = (st: State) => st.kind !== "docs";
        const FIXED: { phases: Phase[]; skill: string; why: string; when?: (st: State) => boolean }[] = [
          { phases: ["triage"], skill: "triage", why: "verify the claim, agent brief" },
          { phases: ["localize", "reproduce"], skill: "diagnosing-bugs", why: "bug: feedback loop, hypotheses", when: (st) => st.kind === "bug" },
          { phases: ["localize", "reproduce"], skill: "tdd", why: "seams, red before green", when: (st) => st.kind !== "bug" && notDocs(st) },
          { phases: ["design"], skill: "codebase-design", why: "deep modules, seams" },
          { phases: ["checkpoint"], skill: "grilling", why: "one round of decisions" },
          { phases: ["plan"], skill: "to-tickets", why: "vertical slices, blocking edges" },
          { phases: ["implement"], skill: "implement", why: "slice by slice" },
          { phases: ["implement"], skill: "tdd", why: "red before green at confirmed seams", when: notDocs },
          { phases: ["review"], skill: "code-review", why: "two-axis review of the diff" },
          { phases: ["report"], skill: "pr", why: "report template" },
          { phases: ["retro"], skill: "retro", why: "retro categories" },
        ];
        const FIXED_NAMES = new Set([...FIXED.map((f) => f.skill), "writing-for-agents"]);

        type McpHint = { phases: Phase[]; server: string; why: string; must?: boolean; when?: (st: State, paths: string[], diff: string) => boolean };
        const MCP_HINTS: McpHint[] = [
          { phases: ["triage"], server: "youtrack", why: "read the ticket", must: true, when: (st) => !!st.issue },
          { phases: ["triage"], server: "rag", why: "team knowledge base", must: true },
          { phases: ["triage"], server: "gitlab", why: "related merge requests" },
          { phases: ["localize"], server: "codebase_memory", why: "code graph" },
          { phases: ["localize"], server: "gitlab", why: "merge requests that touched these files" },
          { phases: ["reproduce", "implement"], server: "context7", why: "external library imports changed", when: (_st, _p, diff) => IMPORTS.test(diff) },
          { phases: ["reproduce", "implement"], server: "postgres", why: "SQL, migrations or repositories", when: (_st, paths) => paths.some((p) => /\.sql$|migrat|repositor|_repo\.go$|(^|\/)(storage|dao|db)\//i.test(p)) },
          { phases: ["regress"], server: "gitlab", why: "CI pipelines for these packages" },
        ];

        const SECTIONS: [string, RegExp][] = [
          ["approach", /^approach\b/i],
          ["why", /^why( this is the right one)?\b/i],
          ["rejected", /^rejected alternatives\b/i],
          ["impact", /^impact\b/i],
          ["tests", /^test strategy\b/i],
          ["objections", /^anticipated objections\b/i],
        ];
        const IMPACT: [string, RegExp][] = [
          ["callers", /caller/i],
          ["contracts (proto, swagger, migrations, config)", /contract|proto|swagger|migrat|config/i],
          ["concurrency", /concurren|race|lock|goroutine|parallel/i],
          ["error and partial-failure paths", /error|fail/i],
          ["backward compatibility", /backward|compatib/i],
        ];

        const norm = (n: string) => n.replace(/[^A-Za-z0-9_]/g, "_");

        const stems = (t: string) => new Set((t.toLowerCase().match(/[\p{L}\p{N}]{4,}/gu) ?? []).map((w) => w.slice(0, 6)).filter((w) => !STOP.has(w)));

        const pathsOf = (st: State) => st.touched ?? (st.files ?? []).map((f) => (f.startsWith(st.root + "/") ? f.slice(st.root.length + 1) : f));

        const relevant = (st: State, phase: Phase, paths: string[], diff = ""): Pick[] => {
          const words = stems(noSkips([st.task, st.brief ?? "", st.plan ?? "", ...(st.criteria ?? []), ...paths].join("\n")));
          const out: Pick[] = FIXED.filter((f) => f.phases.includes(phase) && (!f.when || f.when(st))).flatMap((f) => {
            const res = st.res.find((r) => r.kind === "skill" && r.name === f.skill);
            return res ? [{ res, why: f.why, must: true, fixed: true }] : [];
          });
          for (const kind of ["skill", "mcp"] as const) {
            const scored = st.res
              .filter((r) => r.kind === kind && !r.off && !r.manual && !FIXED_NAMES.has(r.name))
              .map((r) => {
                const text = `''${r.name} ''${r.desc}`;
                const hint =
                  kind === "skill"
                    ? SKILL_HINTS.find((h) => h.phases.includes(phase) && h.match.test(text) && (!h.paths || paths.some((p) => h.paths!.test(p))))
                    : MCP_HINTS.find((h) => h.phases.includes(phase) && h.server === norm(r.name) && (!h.when || h.when(st, paths, diff)));
                const hit = [...stems(`''${r.name.replace(/[-_]/g, " ")} ''${r.desc}`)].filter((w) => words.has(w));
                const why = hint?.why ?? (hit.length >= 2 ? `matches ''${hit.slice(0, 3).join(", ")}` : undefined);
                return why ? { res: r, why, must: (hint as McpHint | undefined)?.must, rank: (hint ? 10 : 0) + hit.length } : undefined;
              })
              .filter((x) => x !== undefined)
              .sort((a, b) => Number(!!b.must) - Number(!!a.must) || b.rank - a.rank);
            out.push(...scored.filter((x, i) => x.must || i < 3).map(({ res, why, must }) => ({ res, why, must })));
          }
          return out;
        };

        const noSkips = (t: string) => t.replace(/^.*\bskip\s+[\w.-]+\s*:.*$/gim, "");

        const done = (st: State, p: Pick) => (p.res.kind === "skill" ? st.read.includes(p.res.name) : st.calls.includes(p.res.name));

        const enforced = (phase: Phase, p: Pick) => (p.fixed ? true : p.res.kind === "skill" ? SKILL_PHASES.has(phase) : !["verify", "checkpoint", "retro"].includes(phase));

        const pickLine = (st: State, p: Pick) =>
          `- ''${p.res.kind === "skill" ? `skill ''${p.res.name}: read ''${p.res.path}` : p.res.name === "context7" ? "mcp context7: call resolve-library-id, then query-docs" : `mcp ''${p.res.name}: call its tools mcp__''${norm(p.res.name)}__*`} (''${p.why}''${p.must ? ", required, no skip" : ""})''${done(st, p) ? " [done]" : st.skips[p.res.name] && !p.must ? " [skipped]" : ""}`;

        const GLOBAL_SKILLS = join(homedir(), ".agents", "skills");

        const resText = (st: State, picks: Pick[]) =>
          picks.length
            ? `\nUse these before acting, they override your general habits:\n''${picks.map((p) => pickLine(st, p)).join("\n")}\nRead each SKILL.md and follow it exactly.''${picks.some((p) => p.res.path && !p.res.path.startsWith(GLOBAL_SKILLS)) && picks.some((p) => p.res.path?.startsWith(GLOBAL_SKILLS)) ? " Where a project skill and a global skill overlap, the project skill wins." : ""} Call MCP tools directly when declared, otherwise from codemode as tools.mcp__<server>__<tool> (describeNamespace("mcp__<server>") lists them). To skip one, write \`skip <name>: <reason>\` in the advance_phase summary.`
            : "";

        const AGENT_DIR = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");

        const findSkills = (dir: string, depth = 3): string[] => {
          try {
            return readdirSync(dir, { withFileTypes: true }).flatMap((d) => (d.isFile() && d.name === "SKILL.md" ? [join(dir, d.name)] : d.isDirectory() && depth > 0 ? findSkills(join(dir, d.name), depth - 1) : []));
          } catch {
            return [];
          }
        };

        const discover = (cwd: string, root: string, tools: string[]): Res[] => {
          const dirs: string[] = [];
          for (let d = resolve(cwd); ; d = dirname(d)) {
            dirs.push(join(d, ".agents", "skills"));
            if (d === root || !d.startsWith(root) || d === dirname(d)) break;
          }
          dirs.push(GLOBAL_SKILLS);
          const out = new Map<string, Res>();
          for (const path of dirs.flatMap((d) => findSkills(d))) {
            const meta = readFileSync(path, "utf8").match(/^---\r?\n([\s\S]*?)\r?\n---/)?.[1] ?? "";
            const field = (k: string) => meta.match(new RegExp(`^''${k}:\\s*(.+)$`, "m"))?.[1]?.trim().replace(/^["']|["']$/g, "");
            const name = field("name") ?? basename(dirname(path));
            if (!out.has(name)) out.set(name, { kind: "skill", name, desc: field("description") ?? "", path, manual: field("disable-model-invocation") === "true" });
          }
          const servers = new Map<string, { description?: string; enabled?: boolean; exposure?: string }>();
          for (const file of [join(AGENT_DIR, "mcp.json"), join(root, ".pi", "mcp.json")])
            try {
              const cfg = JSON.parse(readFileSync(file, "utf8")) as { mcpServers?: Record<string, { description?: string; enabled?: boolean; exposure?: string }> };
              for (const [name, v] of Object.entries(cfg.mcpServers ?? {})) servers.set(norm(name), { ...servers.get(norm(name)), ...v, description: v.description ?? servers.get(norm(name))?.description });
            } catch {}
          for (const [name, v] of servers) if (v.enabled !== false && v.exposure !== "hidden") out.set(`mcp:''${name}`, { kind: "mcp", name, desc: v.description ?? "" });
          if (tools.includes("query-docs")) out.set("mcp:context7", { kind: "mcp", name: "context7", desc: "Library and API documentation, current versions" });
          return [...out.values()];
        };

        const serverOf = (tool: string, input: { server?: unknown }) =>
          tool.startsWith("mcp__") ? tool.slice(5).split("__")[0] : tool === "mcp" ? norm(String(input.server ?? "")) : tool === "resolve-library-id" || tool === "query-docs" ? "context7" : undefined;

        const scriptServers = (code: unknown) => [...new Set([...String(code ?? "").matchAll(/\bmcp__([A-Za-z0-9_]+?)__\w/g)].map((m) => m[1]))];
        const ITEM_TYPES = ["skill", "agents_md", "doc", "tool", "rule", "harness"];
        const COULD_NOT = /could not|couldn't|cannot|can't|unable to|failed to|не удалось|не смог|не могу|нет доступа|не найден/i;
        const DOWN = /connect|unavailable|not available|ECONN|refused|timed? ?out|disconnected|fetch failed|\b50[234]\b|socket|ENOTFOUND/i;

        const couldNot = (text: string) => text.split(/(?<=[.!?])\s+|\n+/).filter((x) => COULD_NOT.test(x)).slice(0, 3).map((x) => head(x, 160));

        const textOf = (m?: Msg) => (typeof m?.content === "string" ? m.content : (m?.content ?? []).map((c) => (c.type === "text" ? c.text ?? "" : "")).join("\n"));

        const childMessages = (id: string): Msg[] => {
          try {
            for (const d of readdirSync(join(AGENT_DIR, "sessions"))) {
              const f = readdirSync(join(AGENT_DIR, "sessions", d)).find((n) => n.endsWith(`_''${id}.jsonl`));
              if (f)
                return readFileSync(join(AGENT_DIR, "sessions", d, f), "utf8")
                  .split("\n")
                  .flatMap((l) => {
                    try {
                      const m = (JSON.parse(l) as { message?: Msg }).message;
                      return m ? [m] : [];
                    } catch {
                      return [];
                    }
                  });
            }
          } catch {}
          return [];
        };

        const tally = () => {
          const map = new Map<string, { n: number; resolved: boolean }>();
          const put = (text: string, resolved = false) => {
            const x = map.get(text);
            if (x) x.n++;
            else map.set(text, { n: 1, resolved });
          };
          const list = (cap: number): Fact[] => [...map].sort((a, b) => b[1].n - a[1].n).slice(0, cap).map(([text, { n, resolved }]) => ({ text: n > 1 ? `(''${n}x) ''${text}` : text, resolved }));
          return { put, list };
        };

        const parseItems = (text: string): Item[] => {
          const items: Record<string, string>[] = [];
          let key = "";
          for (const line of text.split("\n")) {
            const m = line.match(/^\s*[-*]?\s*(type|evidence|gap|proposal|target)\s*:\s?(.*)$/i);
            if (m) {
              key = m[1].toLowerCase();
              if (key === "type" || !items.length) items.push({});
              items[items.length - 1][key] = m[2];
            } else if (key && items.length) items[items.length - 1][key] += "\n" + line;
          }
          return items.map((i) => ({ type: (i.type ?? "").trim().toLowerCase(), evidence: (i.evidence ?? "").trim(), gap: (i.gap ?? "").trim(), proposal: (i.proposal ?? "").replace(/^\s*\n|\s+$/g, ""), target: (i.target ?? "").trim() }));
        };

        const ISSUE = /^\s*([A-Z][A-Z0-9_]+-\d+)\b/;

        const issueOf = (task: string) => (task.match(/https?:\/\/\S*\/issue\/([A-Za-z][A-Za-z0-9_]*-\d+)/)?.[1] ?? task.match(ISSUE)?.[1])?.toUpperCase();

        const listCriteria = (c?: string[]) => (c?.length ? `\nAcceptance criteria:\n''${c.map((x, i) => `C''${i + 1} ''${x}`).join("\n")}` : "");

        const head = (s: string, n = 60) => {
          const t = s.replace(/\s+/g, " ").trim();
          return t.length > n ? t.slice(0, n - 1) + "…" : t;
        };

        const tail = (s: string, lines = 30, chars = 3000) => {
          const t = s.trim().split("\n").slice(-lines).join("\n");
          return t.length > chars ? "…" + t.slice(-chars) : t;
        };

        const q = (s: string) => `''\'''${s.replace(/'/g, `'\\'''`)}'`;

        const isTest = (f: string) => /(_test\.go|\.(test|spec)\.[cm]?[jt]sx?|_test\.py|(^|\/)test_[^/]*\.py|_test\.rs)$/.test(f) || /(^|\/)(tests?|__tests__|testdata)\//.test(f);

        const sectionsOf = (doc: string) => {
          const out: Record<string, string> = {};
          let cur = "";
          for (const line of doc.split("\n")) {
            const t = line.replace(/^[\s#*_]+/, "");
            const hit = SECTIONS.find(([, re]) => re.test(t));
            const rest = hit ? t.replace(hit[1], "").replace(/^[\s*_]*/, "") : "";
            if (hit && (rest === "" || rest.startsWith(":"))) {
              cur = hit[0];
              out[cur] = (out[cur] ?? "") + rest.replace(/^:[\s*_]*/, "") + "\n";
            } else if (cur) out[cur] += line + "\n";
          }
          return out;
        };

        const bullets = (t: string) => t.split("\n").filter((l) => /^\s*([-*]|\d+[.)])\s+\S/.test(l)).map((l) => l.replace(/^\s*([-*]|\d+[.)])\s+/, "").trim());

        const estimateOf = (t: string) => {
          const m = t.match(/estimated diff\D{0,20}(\d+)/i);
          return m ? Number(m[1]) : undefined;
        };

        const answerOf = (doc: string, id: string) => doc.match(new RegExp(`^[\\s*_-]*''${id}\\b[*_]*\\s*[:.)-]\\s*(\\S.*)$`, "m"))?.[1]?.trim() ?? "";

        const tagged = (answer: string, src: string): Found[] =>
          bullets(answer)
            .map((l) => ({ tag: /\[arch\]/i.test(l) ? ("arch" as const) : ("local" as const), src, text: head(l.replace(/\[(arch|local)\]\s*/i, ""), 300) }))
            .slice(0, 8);

        const blocks = (answer: string) => /^\s*VERDICT:\s*BLOCK\b/im.test(answer);

        const tokens = (name: string) => (name.match(/[A-Z]+(?![a-z])|[A-Z]?[a-z]+|\d+/g) ?? []).map((t) => t.toLowerCase());

        const sigOf = (params: string, results: string) => {
          const parts = params.split(",").map((p) => p.trim().split(/\s+/)).filter((p) => p[0]);
          const named = parts.some((p) => p.length > 1);
          const types: string[] = [];
          let next = "";
          for (const p of [...parts].reverse()) {
            if (named && p.length > 1) next = p.slice(1).join(" ");
            types.unshift(named ? next : p.join(" "));
          }
          return `''${types.join(",")}>''${results.replace(/\s+/g, "")}`;
        };

        const ranges = (diff: string) =>
          [...diff.matchAll(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/gm)].map((m) => [Number(m[1]), Number(m[1]) + Math.max(Number(m[2] ?? 1), 1) - 1] as [number, number]).filter((r) => r[1] >= r[0]);

        const planMode = (ctx: ExtensionContext) =>
          (ctx.sessionManager.getBranch() as Entry[]).findLast((e) => e.type === "custom" && e.customType === "pi-plan")?.data?.mode ?? "normal";

        const stateDefaults: Partial<State> = { repros: [], round: 0, items: [], ideas: [], inputs: 0, dups: [], news: [], answers: {}, localRound: 0, used: [] };

        const mergeState = (st: unknown): State | undefined => (st && typeof st === "object" ? ({ ...stateDefaults, ...(st as Partial<State>) } as State) : undefined);

        const load = (ctx: ExtensionContext) =>
          mergeState((ctx.sessionManager.getBranch() as Entry[]).findLast((e) => e.type === "custom" && e.customType === "pipeline")?.data?.state ?? undefined);

        type SessEntry = { id?: string; parentId?: string; timestamp?: string; type?: string; customType?: string; cwd?: string; data?: { state?: State | null } };

        const sessionState = (text: string): { cwd: string; state: State } | undefined => {
          const byId = new Map<string, SessEntry>();
          let cwd = "";
          for (const line of text.split("\n")) {
            if (!line) continue;
            try {
              const e = JSON.parse(line) as SessEntry;
              if (e.type === "session" && typeof e.cwd === "string") cwd = e.cwd;
              if (typeof e.id === "string") byId.set(e.id, e);
            } catch {}
          }
          if (!cwd || !byId.size) return undefined;
          const refs = new Set<string>();
          byId.forEach((e) => {
            if (typeof e.parentId === "string") refs.add(e.parentId);
          });
          let leaf: string | undefined;
          byId.forEach((e, id) => {
            if (refs.has(id)) return;
            if (!leaf || (e.timestamp ?? "") >= (byId.get(leaf)!.timestamp ?? "")) leaf = id;
          });
          if (!leaf) return undefined;
          let seen = false;
          let state: State | null = null;
          let cur: string | undefined = leaf;
          while (cur) {
            const e = byId.get(cur);
            if (!e) break;
            if (e.type === "custom" && e.customType === "pipeline") {
              if (!seen) state = e.data?.state ?? null;
              seen = true;
            }
            cur = typeof e.parentId === "string" ? e.parentId : undefined;
          }
          const st = mergeState(state);
          return st ? { cwd, state: st } : undefined;
        };

        const scanSessions = (): { file: string; cwd: string; state: State }[] => {
          const dir = process.env.PI_CODING_AGENT_SESSION_DIR || join(homedir(), ".pi", "agent", "sessions");
          let groups: string[] = [];
          try {
            groups = readdirSync(dir);
          } catch {
            return [];
          }
          const out: { file: string; cwd: string; state: State }[] = [];
          for (const g of groups) {
            let files: string[] = [];
            try {
              files = readdirSync(join(dir, g));
            } catch {
              continue;
            }
            for (const f of files) {
              if (!f.endsWith(".jsonl")) continue;
              const file = join(dir, g, f);
              let parsed: { cwd: string; state: State } | undefined;
              try {
                parsed = sessionState(readFileSync(file, "utf8"));
              } catch {
                continue;
              }
              if (parsed) out.push({ file, ...parsed });
            }
          }
          return out;
        };

        const projDir = (st: State) => join(homedir(), ".pi", "projects", st.root.replace(/\//g, "-"));

        export default function (pi: ExtensionAPI) {
          if (process.env.PI_HERDR_DEPTH) return;
          let s: State | undefined;
          let blocked = false;
          let shown = 0;
          let flaky = false;
          const blockedIds = new Set<string>();

          const sh = async (cmd: string, cwd: string, timeout: number, signal?: AbortSignal) => {
            const r = await pi.exec("bash", ["-c", cmd], { cwd, timeout, signal });
            return { code: r.killed ? 124 : r.code, stdout: r.stdout, out: r.stdout + "\n" + r.stderr };
          };

          const hash = (root: string, f: string) => {
            try {
              return createHash("sha1").update(readFileSync(join(root, f))).digest("hex");
            } catch {
              return "-";
            }
          };

          const dirty = async (root: string) => {
            const r = await sh("git diff --name-only HEAD; git ls-files --others --exclude-standard", root, 30000);
            return [...new Set(r.stdout.split("\n").map((l) => l.trim()).filter(Boolean))];
          };

          const snapshot = async (root: string) => Object.fromEntries((await dirty(root)).map((f) => [f, hash(root, f)]));

          const changed = async (st: State, since = st.snapshot) => (await dirty(st.root)).filter((f) => since[f] !== hash(st.root, f));

          const untracked = async (st: State, files: string[]) => {
            if (!files.length) return [];
            const tracked = new Set((await sh(`git ls-files -- ''${files.map(q).join(" ")}`, st.root, 30000)).stdout.split("\n"));
            return files.filter((f) => !tracked.has(f) && existsSync(join(st.root, f)));
          };

          const lines = (st: State, f: string) => {
            try {
              return readFileSync(join(st.root, f), "utf8").split("\n").length;
            } catch {
              return 0;
            }
          };

          const diffLines = async (st: State, files: string[]) => {
            if (!files.length) return 0;
            const fresh = await untracked(st, files);
            const r = await sh(`git diff HEAD --numstat -- ''${files.map(q).join(" ")}`, st.root, 30000);
            return r.stdout.split("\n").reduce((n, l) => n + l.split("\t").slice(0, 2).reduce((a, x) => a + (Number(x) || 0), 0), 0) + fresh.reduce((n, f) => n + lines(st, f), 0);
          };

          const fullDiff = async (st: State, files: string[]) => {
            if (!files.length) return "";
            const fresh = await untracked(st, files);
            const tracked = (await sh(`git diff HEAD -- ''${files.map(q).join(" ")}`, st.root, 30000)).stdout;
            const added = await Promise.all(fresh.map(async (f) => (await sh(`git diff --no-index -- /dev/null ''${q(f)}`, st.root, 30000)).stdout));
            return (tracked + added.join("")).slice(0, 12000);
          };

          const publish = (ctx: ExtensionContext) => {
            pi.events.emit("pipeline:phase", s ? { run: s.run, phase: s.phase, nodeId: s.node } : null);
            if (ctx.hasUI) ctx.ui.setStatus("pipeline", s?.phase);
            if (s) {
              process.env.PI_PIPELINE_NODE = s.node;
              process.env.PI_PIPELINE_RUN = s.run;
            } else {
              delete process.env.PI_PIPELINE_NODE;
              delete process.env.PI_PIPELINE_RUN;
            }
          };

          const save = () => pi.appendEntry("pipeline", { state: s ?? null });

          const refresh = (st: State, strict: boolean) => {
            const names = pi.getAllTools().filter((t) => t.exposure !== "hidden").map((t) => t.name);
            for (const r of st.res) if (r.kind === "mcp") r.off = st.down.includes(r.name) || (strict && r.name !== "context7" && !names.some((n) => n.startsWith(`mcp__''${norm(r.name)}__`)));
          };

          const openItems = (st: State, kinds: Kind[]) => st.items.filter((i) => i.open && kinds.includes(i.kind));

          const addItem = (st: State, kind: Kind, src: string, text: string) => {
            const id = `''${PREFIX[kind]}''${st.items.filter((i) => i.kind === kind).length + 1}`;
            st.items.push({ id, kind, src, text: head(text, 400), open: true });
            return id;
          };

          const itemsText = (st: State) => {
            const open = openItems(st, ["constraint", "arch", "scenario", "rival", "expect"]);
            const how: Record<Kind, string> = {
              constraint: "hard constraint, answer `<id>: <how the design meets it>`",
              arch: "answer `<id>: <what you changed in the approach>`",
              scenario: "cover it in Test strategy by id",
              rival: "answer `<id>: adopt` or `<id>: refute <concrete reason>`",
              expect: "answer `<id>: adopt <how>` or `<id>: decline <why>`",
              local: "",
            };
            const ideas = st.ideas.length ? `\nIdeas to evaluate as rivals on the next submission: ''${st.ideas.map((x) => head(x, 120)).join("; ")}` : "";
            return (open.length ? `\nOpen items:\n''${open.map((i) => `''${i.id} (''${i.src}) ''${i.text} -> ''${how[i.kind]}`).join("\n")}` : "") + ideas;
          };

          const baseGuide = (st: State) =>
            st.phase === "triage" && st.issue
              ? `First read YouTrack issue ''${st.issue} with the youtrack MCP tools (codemode namespace mcp__youtrack): summary, description, comments and fields. ''${GUIDE.triage} The summary must contain ''${st.issue}, restate the expected behavior and take the criteria from the issue.`
              : ["reproduce", "design", "plan", "implement", "verify"].includes(st.phase)
                ? GUIDE[st.phase] + listCriteria(st.criteria) + (st.phase === "design" || st.phase === "plan" ? itemsText(st) : "")
                : GUIDE[st.phase];

          const guide = (st: State) => {
            refresh(st, false);
            return baseGuide(st) + resText(st, relevant(st, st.phase, pathsOf(st)));
          };

          const fact = (st: State, k: string, text: string, resolved = false) => {
            if (st.log.length < 300) st.log.push({ k, phase: st.phase, text: head(text, 200), resolved });
          };

          const node = (st: State, status: Status, detail?: string) =>
            emitEvent({ id: st.node, parents: [st.parent], kind: "phase", label: st.phase, run: st.run, phase: st.phase, cwd: st.root, status, detail });

          const gate = (st: State, name: string, status: Status, detail?: string) =>
            emitEvent({ id: `''${st.node}:gate:''${name}`, parents: [st.node], kind: "gate", label: name, run: st.run, phase: st.phase, cwd: st.root, status, detail: detail && head(detail, 200) });

          const enter = async (st: State, phase: Phase, ctx: ExtensionContext) => {
            const from = st.phase;
            st.timeline.push({ phase, at: Date.now() });
            Object.assign(st, { phase, seq: st.seq + 1, fails: 0, calls: [], parent: st.node, node: `''${st.run}:''${st.seq + 1}:''${phase}` });
            if (phase === "implement") st.mark = await snapshot(st.root);
            if (phase === "design" && from !== "design") st.round = 0;
            if (phase === "checkpoint") Object.assign(st, { decision: undefined, questions: undefined });
            if (phase === "review") Object.assign(st, { fixing: false, localRound: 0, findings: undefined });
            flaky = false;
            node(st, "running");
            save();
            publish(ctx);
          };

          const finish = (status: Status, ctx: ExtensionContext, detail?: string) => {
            if (!s) return;
            node(s, status, detail);
            emitEvent({ id: s.run, parents: [], kind: "run", label: s.issue ?? head(s.task), run: s.run, cwd: s.root, sessionId: ctx.sessionManager.getSessionId(), status, detail });
            s = undefined;
            save();
            publish(ctx);
          };

          const start = async (task: string, ctx: ExtensionContext) => {
            const top = await sh("git rev-parse --show-toplevel", ctx.cwd, 10000);
            const root = top.code === 0 ? top.stdout.trim() : ctx.cwd;
            const run = randomUUID();
            const issue = issueOf(task);
            s = {
              run, task, issue, root, phase: "triage", node: `''${run}:0:triage`, parent: run, seq: 0, fails: 0, snapshot: await snapshot(root),
              res: discover(ctx.cwd, root, pi.getAllTools().map((t) => t.name)), read: [], calls: [], used: [], skips: {}, down: [], log: [],
              timeline: [{ phase: "triage", at: Date.now() }], repros: [], round: 0, items: [], ideas: [], inputs: 0, dups: [], news: [], answers: {}, localRound: 0,
            };
            emitEvent({ id: run, parents: [], kind: "run", label: issue ?? head(task), run, cwd: root, sessionId: ctx.sessionManager.getSessionId(), status: "running" });
            node(s, "running");
            save();
            publish(ctx);
            return `[Pipeline] Phases: ''${PHASES.join(" → ")}. Finish each phase with advance_phase, it checks the result and gives the next step.\nThe user is asked once per run, at the checkpoint phase. Otherwise never ask the user, decide yourself.\nPhase triage: ''${guide(s)}`;
          };

          const goPackages = async (st: State, files: string[], signal?: AbortSignal) => {
            const dirs = [...new Set(files.filter((f) => f.endsWith(".go") && existsSync(join(st.root, dirname(f)))).map((f) => "./" + dirname(f)))];
            if (!dirs.length) return [];
            const own = await sh(`go list ''${dirs.map(q).join(" ")}`, st.root, 120000, signal);
            if (own.code !== 0) return dirs;
            const mine = new Set(own.stdout.split("\n").map((l) => l.trim()).filter(Boolean));
            const all = await sh(`go list -f '{{.ImportPath}} {{join .Deps " "}} {{join .TestImports " "}} {{join .XTestImports " "}}' ./...`, st.root, 120000, signal);
            if (all.code !== 0) return [...mine];
            const users = all.stdout
              .split("\n")
              .map((l) => l.trim().split(/\s+/))
              .filter(([p, ...deps]) => p && (mine.has(p) || deps.some((d) => mine.has(d))))
              .map(([p]) => p);
            return users.length > 0 && users.length <= 60 ? users : [...mine];
          };

          const recordJobs = (st: State, jobs: Job[]) => {
            for (const j of jobs.filter((x) => x.sessionId && x.ok !== undefined)) {
              if (!j.ok) fact(st, "subagent", `subagent ''${j.agent} failed: ''${j.error ?? "no answer"}`);
              const msgs = childMessages(j.sessionId!).filter((m) => m.role === "assistant");
              for (const x of couldNot(j.answer || textOf(msgs[msgs.length - 1]))) fact(st, "subagent", `subagent ''${j.agent} said: ''${x}`);
              const u = msgs[0]?.usage;
              if (u) fact(st, "harness", `subagent ''${j.agent} cold start: first turn prefilled ''${(u.input ?? 0) + (u.cacheRead ?? 0)} tokens, ''${u.cacheRead ?? 0} from cache, ''${msgs.length} turns`, !!u.cacheRead);
            }
          };

          const batch = async (st: State, ctx: ExtensionToolContext, tasks: { agent: string; task: string }[], key: string, signal?: AbortSignal): Promise<Job[] | undefined> => {
            if (!ctx.tools.some((t) => t.name === "subagent")) {
              fact(st, "harness", `subagent tool missing, ''${key} agents skipped`);
              return undefined;
            }
            const bg = ctx.tools.some((t) => t.name === "subagent_wait");
            const r = await ctx.executeTool("subagent", bg ? { tasks, timeoutMin: 20, background: true } : { tasks, timeoutMin: 20 }, { signal });
            let jobs = (r.result.details as { jobs?: Job[] } | undefined)?.jobs ?? [];
            if (bg && jobs.length) {
              const ids = jobs.map((j) => j.id).filter((x): x is string => !!x);
              const w = await ctx.executeTool("subagent_wait", { ids, timeoutMin: 40 }, { signal });
              const got = (w.result.details as { jobs?: Job[] } | undefined)?.jobs ?? [];
              const err = w.result.content.map((c) => (c.type === "text" ? c.text : "")).join(" ");
              jobs = jobs.map((j) => got.find((g) => g.id === j.id) ?? { ...j, ok: false, error: head(err || "no result from subagent_wait", 120) });
            }
            if (!jobs.length) {
              fact(st, "harness", `subagent call for ''${key} returned no jobs: ''${head(r.result.content.map((c) => (c.type === "text" ? c.text : "")).join(" "), 120)}`);
              return undefined;
            }
            recordJobs(st, jobs);
            const parents = jobs.map((j) => j.sessionId ?? j.id).filter((x): x is string => !!x);
            emitEvent({ id: `''${st.node}:join:''${key}`, parents: parents.length ? parents : [st.node], kind: "join", label: `join ''${key}`, run: st.run, phase: st.phase, cwd: st.root, status: jobs.every((j) => j.ok) ? "ok" : "fail" });
            return tasks.map((t, i) => jobs[i] ?? { agent: t.agent, ok: false, error: "missing" });
          };

          const skillPaths = (st: State, files: string[]) => [...new Set((["reproduce", "implement"] as Phase[]).flatMap((ph) => relevant(st, ph, files).filter((p) => p.res.kind === "skill" && !p.fixed).map((p) => p.res.path!)))];

          const unmet = async (st: State, summary: string, ev: string, signal?: AbortSignal) => {
            for (const m of `''${summary}\n''${ev}`.matchAll(/\bskip\s+([\w.-]+)\s*:\s*(\S[^\n]{4,})/gi)) st.skips[m[1]] = m[2].trim();
            const paths = ["triage", "localize", "design", "checkpoint", "plan"].includes(st.phase) ? pathsOf(st) : (st.touched = await changed(st));
            const diff = (st.phase === "reproduce" || st.phase === "implement") && paths.length ? (await sh(`git diff HEAD -- ''${paths.map(q).join(" ")}`, st.root, 30000, signal)).stdout : "";
            const skipRepro = st.phase === "reproduce" && /^skip:/i.test(ev);
            refresh(st, true);
            const open = relevant(st, st.phase, paths, diff).filter((p) => enforced(st.phase, p) && !done(st, p) && (p.must || !st.skips[p.res.name]) && !(skipRepro && p.res.kind === "skill"));
            if (!open.length) return undefined;
            st.enforced = { ...st.enforced, ...Object.fromEntries(open.map((p) => [p.res.name, st.phase])) };
            return `Required in phase ''${st.phase} and not done yet:\n''${open.map((p) => pickLine(st, p)).join("\n")}\nRead each SKILL.md with read and follow it, call each MCP server at least once, then call advance_phase again. To skip one that does not apply, add \`skip <name>: <reason>\` to the summary.`;
          };

          const common = (st: State) =>
            `Repository: ''${st.root}\nTask: ''${st.task}\n''${listCriteria(st.criteria).trim()}\n` +
            (st.repros.length ? `Repro tests (fail before the change): ''${st.repros.join(" ; ")}\n` : st.skip ? `Reproduce skipped: ''${st.skip}\n` : "") +
            (st.hypotheses ? `Ranked hypotheses:\n''${st.hypotheses}\n` : "");

          const designTasks = (st: State, doc: string) => {
            const skills = skillPaths(st, pathsOf(st));
            const base = common(st) + (skills.length ? `Project skills, read them: ''${skills.join(", ")}\n` : "") + `Design:\n''${doc}\n`;
            const tasks: { agent: string; task: string; role: string; idea?: string }[] = [
              {
                role: "critic",
                agent: "critic",
                task: `You are the critic of this design. Find what makes the approach wrong, risky or bigger than needed. Read the code and skills you need.\n''${base}Reply exactly in this format, at most 10 lines, nothing else:\nVERDICT: PASS or BLOCK\n- [arch] <objection that needs a different approach, and why>\n- [local] <objection fixable inside this approach>`,
              },
              {
                role: "tester",
                agent: "tester",
                task: `You are an adversarial tester. List the scenarios you would use to break this change: edge cases, error and partial-failure paths, concurrency, backward compatibility. Check each against the Test strategy section.\n''${base}Reply at most 10 lines, nothing else, one per scenario:\n- COVERED: <scenario> -> <test strategy line>\n- MISSING: <scenario and the input that breaks it>`,
              },
            ];
            const rival = (idea?: string) => ({
              role: "rival",
              agent: "rival",
              idea,
              task:
                (idea ? `Evaluate this idea as a solution of the task and develop it into an approach: ''${idea}\n` : "Design your own solution of this task independently. Design constraint: minimize the interface, 1-3 entry points, maximum leverage per entry point, reuse existing code.\n") +
                `''${common(st)}Files located for the change: ''${pathsOf(st).join(", ") || "none"}\nLocalize notes:\n''${st.localized ?? ""}\nReply exactly, nothing else:\nAPPROACH: <one paragraph>\nDIFF: <estimated changed non-test lines, a number>\nWHY: <one line>`,
            });
            if (st.rival === undefined) tasks.push(rival());
            if (!st.experts)
              tasks.push({
                role: "psychologist",
                agent: "psychologist",
                task: `Identify the experts who own the touched code (git log and blame of the paths) and predict what they expect from this change: strategy, structure, naming, error handling, tests. Expert profiles file: ''${join(projDir(st), "experts.md")}, reuse it if it exists, otherwise write it.\nRepository: ''${st.root}\nTask: ''${st.task}\nTouched paths: ''${pathsOf(st).join(", ") || "none"}\nReply exactly, at most 12 lines, nothing else:\nEXPERT: <name> - <one line profile>\n- <concrete expectation of that expert>`,
              });
            for (const idea of st.ideas) if (tasks.length < 4) tasks.push(rival(idea));
            return tasks;
          };

          const validate = (st: State, doc: string) => {
            const secs = sectionsOf(doc);
            const errs: string[] = [];
            for (const [name] of SECTIONS) if ((secs[name] ?? "").trim().length < 15) errs.push(`section ''${name === "why" ? "Why this is the right one" : name === "rejected" ? "Rejected alternatives" : name === "tests" ? "Test strategy" : name === "objections" ? "Anticipated objections" : name[0].toUpperCase() + name.slice(1)} is missing or empty`);
            if (errs.length) return errs;
            if (estimateOf(secs.approach) === undefined) errs.push("Approach needs a line `Estimated diff: <N> lines`");
            const alts = bullets(secs.rejected);
            if (alts.length < 2) errs.push("Rejected alternatives needs at least 2 bullets");
            if (!alts.some((a) => /minimal/i.test(a))) errs.push("Rejected alternatives must include `minimal change`");
            if (!alts.some((a) => /reuse|existing code/i.test(a))) errs.push("Rejected alternatives must include `reuse existing code`");
            for (const a of alts) if (!/(because|since|:|—|–| - )\s*\S.{19,}/i.test(a)) errs.push(`give a concrete reason for the alternative "''${head(a, 50)}"`);
            for (const [name, re] of IMPACT) if (!re.test(secs.impact)) errs.push(`Impact must cover ''${name} (write none if nothing changes)`);
            (st.criteria ?? []).forEach((_, i) => {
              if (!new RegExp(`\\bC''${i + 1}\\b`).test(secs.tests)) errs.push(`Test strategy must map C''${i + 1}`);
            });
            const obj = bullets(secs.objections);
            if (obj.length < 2 || !obj.some((o) => /tester|qa\b/i.test(o)) || !obj.some((o) => /teammate|daily|colleague|team/i.test(o))) errs.push("Anticipated objections needs bullets for a tester and a teammate at the daily, each with your answer");
            for (const i of openItems(st, ["constraint", "arch", "rival", "expect"])) {
              const a = answerOf(doc, i.id);
              if (i.kind === "rival" ? !/^adopt\b/i.test(a) && a.length < 40 : i.kind === "expect" ? !/^adopt\b/i.test(a) && !/^decline\b.{15,}/i.test(a) : a.length < 30)
                errs.push(`answer ''${i.id} on its own line: ''${i.kind === "rival" ? "`adopt` or a concrete refutation of at least 40 chars" : i.kind === "expect" ? "`adopt <how>` or `decline <why>`" : "at least 30 chars on how the design handles it"}`);
            }
            for (const i of openItems(st, ["scenario"])) if (!new RegExp(`\\b''${i.id}\\b`).test(secs.tests)) errs.push(`Test strategy must cover ''${i.id}`);
            if (openItems(st, ["arch"]).length && st.design) {
              const o = sectionsOf(st.design);
              const flat = (x?: string) => (x ?? "").replace(/\s+/g, " ").trim();
              if (flat(o.approach) === flat(secs.approach) && flat(o.impact) === flat(secs.impact)) errs.push("rework, not patch: [arch] objections need a changed Approach or Impact, not only answers");
            }
            return errs;
          };

          const designCheck = async (st: State, doc: string, ctx: ExtensionToolContext, signal?: AbortSignal): Promise<Check> => {
            const errs = validate(st, doc);
            if (errs.length) return { ok: false, why: `The design doc is incomplete:\n- ''${errs.join("\n- ")}` };
            for (const i of openItems(st, ["constraint", "arch", "rival", "expect", "scenario"])) i.open = false;
            st.design = doc.slice(0, 8000);
            st.estimate = estimateOf(sectionsOf(doc).approach);
            st.round++;
            const tasks = designTasks(st, st.design);
            const jobs = await batch(st, ctx, tasks.map(({ agent, task }) => ({ agent, task })), `design''${st.round}`, signal);
            if (!jobs) return { ok: true, status: "skipped", note: "Design agents unavailable, design accepted unchecked." };
            const fresh: string[] = [];
            let block = false;
            jobs.forEach((j, n) => {
              const t = tasks[n];
              if (!j.ok) return fact(st, "subagent", `''${t.role} unavailable in design round ''${st.round}: ''${j.error ?? "error"}`);
              const a = j.answer ?? "";
              if (t.role === "critic") {
                const found = tagged(a, "critic");
                for (const f of found) fresh.push(addItem(st, f.tag, "critic", f.text));
                if (blocks(a) && !found.some((f) => f.tag === "arch")) fresh.push(addItem(st, "arch", "critic", `BLOCK: ''${head(a.replace(/^\s*VERDICT:.*$/im, ""), 300)}`));
                block = blocks(a) || found.some((f) => f.tag === "arch");
              } else if (t.role === "tester") {
                for (const l of bullets(a).filter((x) => /^MISSING\b/i.test(x))) fresh.push(addItem(st, "scenario", "tester", l.replace(/^MISSING:?\s*/i, "")));
              } else if (t.role === "rival") {
                const diff = Number(a.match(/DIFF:\D*(\d+)/i)?.[1] ?? NaN);
                const approach = a.match(/APPROACH:\s*([\s\S]*?)(?:\n\s*DIFF:|$)/i)?.[1] ?? a;
                if (t.idea) {
                  st.ideas = st.ideas.filter((x) => x !== t.idea);
                  fresh.push(addItem(st, "rival", "idea", `idea "''${head(t.idea, 120)}", estimated ''${Number.isNaN(diff) ? "?" : diff} lines vs yours ''${st.estimate}: ''${head(approach, 250)}`));
                } else {
                  st.rival = Number.isNaN(diff) ? Infinity : diff;
                  if (diff < (st.estimate ?? 0)) fresh.push(addItem(st, "rival", "rival", `rival approach with ''${diff} estimated lines vs yours ''${st.estimate}: ''${head(approach, 300)}`));
                }
              } else if (t.role === "psychologist") {
                st.experts = true;
                for (const l of bullets(a).slice(0, 6)) addItem(st, "expect", "psychologist", l);
              }
            });
            const rejecting = st.items.filter((i) => i.open && fresh.includes(i.id) && ["arch", "scenario", "rival"].includes(i.kind));
            const locals = openItems(st, ["local"]);
            const expects = openItems(st, ["expect"]);
            if (block || rejecting.length) {
              fact(st, "design", `design round ''${st.round} rejected: ''${rejecting.map((i) => `''${i.id} ''${head(i.text, 60)}`).join("; ")}`);
              emitEvent({ id: `''${st.node}:round:''${st.round}`, parents: [`''${st.node}:join:design''${st.round}`], kind: "step", label: `design round ''${st.round} rejected`, run: st.run, phase: "design", cwd: st.root, status: "fail" });
              if (st.round >= MAX_ROUNDS) return { ok: true, status: "fail", note: `Design not accepted after ''${MAX_ROUNDS} rounds. ''${st.checked ? "The unresolved items stay in the facts, the user already decided at the checkpoint." : "The unresolved items go to the user at the checkpoint."}` };
              save();
              return { ok: true, wait: `Design rejected (round ''${st.round}/''${MAX_ROUNDS}). Rework the approach (not a patch) and submit the whole design doc again with advance_phase.''${itemsText(st)}` };
            }
            return {
              ok: true,
              note:
                `Design accepted in round ''${st.round}.` +
                (locals.length ? `\nCritic notes for the plan:\n''${locals.map((i) => `''${i.id} ''${i.text}`).join("\n")}` : "") +
                (expects.length ? `\nExpert expectations to answer in the plan:\n''${expects.map((i) => `''${i.id} ''${i.text}`).join("\n")}` : ""),
            };
          };

          const screen = (st: State) => {
            const secs = sectionsOf(st.design ?? "");
            const open = openItems(st, ["arch", "scenario", "rival"]);
            const mcp = st.used.filter((u) => u.startsWith("mcp ")).map((u) => u.slice(4));
            const skills = st.used.filter((u) => u.startsWith("skill ")).map((u) => u.slice(6));
            return [
              `CHECKPOINT ''${st.issue ?? head(st.task, 80)}`,
              listCriteria(st.criteria).trim() || "Acceptance criteria: none",
              `Approach: ''${head(secs.approach ?? "none", 600)}`,
              `Rejected alternatives:\n''${bullets(secs.rejected ?? "").map((a) => `- ''${head(a, 200)}`).join("\n") || "none"}`,
              `Repro: ''${st.repros.join(" ; ") || (st.skip ? `skipped: ''${st.skip}` : "none")}`,
              `Skills: ''${skills.join(", ") || "none"} | MCP: ''${mcp.join(", ") || "none"}`,
              `Unresolved: ''${open.length ? "\n" + open.map((i) => `''${i.id} (''${i.src}) ''${head(i.text, 200)}`).join("\n") : "none"}`,
              ...(st.questions ? [`Decisions (reply yes to accept every recommendation, or answer by Q<n>):\n''${st.questions}`] : []),
            ].join("\n");
          };

          const skipCheckpoint = (st: State): Check => {
            for (const i of openItems(st, ["arch", "scenario", "rival"])) {
              i.open = false;
              fact(st, "design", `design went on after the checkpoint with ''${i.id} unresolved: ''${head(i.text, 120)}`);
            }
            return { ok: true, status: "skipped", note: "The user already decided at this run's checkpoint, checkpoint skipped." };
          };

          const runGates = async (ctx: ExtensionToolContext, signal?: AbortSignal) => {
            if (!ctx.tools.some((t) => t.name === "run_gates")) return { ok: true, text: "run_gates is not installed, gates skipped." };
            const g = await ctx.executeTool("run_gates", {}, { signal });
            const text = g.result.content.map((c) => (c.type === "text" ? c.text : "")).join("\n");
            const gd = g.result.details as { ok?: boolean } | undefined;
            return g.isError || gd?.ok !== true ? { ok: false, text: `Gates failed:\n''${tail(text, 30)}` } : { ok: true, text: "Gates ok." };
          };

          const runRepros = async (st: State, signal?: AbortSignal) => {
            for (const c of st.repros) {
              const r = await sh(c, st.root, 600000, signal);
              if (r.code !== 0) return `The repro command still fails: ''${c}\n''${tail(r.out, 20)}`;
            }
            return undefined;
          };

          const hate = async (st: State, summary: string, signal?: AbortSignal): Promise<Check | undefined> => {
            for (const m of summary.matchAll(/^[\s*_-]*([DN]\d+)\b[*_]*\s*[:.)-]\s*(\S.{9,})$/gm)) st.answers[m[1]] = m[2].trim();
            const src = (await changed(st)).filter((f) => !isTest(f));
            const size = await diffLines(st, src);
            if (st.planEstimate && size > 2 * st.planEstimate && size > 20) {
              const id = addItem(st, "constraint", "size", `the diff grew to ''${size} non-test lines, more than 2x the plan estimate of ''${st.planEstimate}: find a smaller approach or justify the size`);
              fact(st, "design-miss", `design missed the size: ''${size} diff lines vs plan estimate ''${st.planEstimate}`);
              gate(st, "size", "fail", `''${size} lines vs estimate ''${st.planEstimate}`);
              st.planEstimate = undefined;
              return { ok: true, status: "fail", next: "design", note: `The diff is ''${size} non-test lines, more than 2x the plan estimate. Back to design with ''${id}.` };
            }
            const fresh = await untracked(st, src);
            const whats = fresh.map((f) => `new file ''${f}`);
            for (const d of new Set(fresh.filter((f) => f.endsWith(".go")).map((f) => dirname(f)))) {
              const known = (await sh(`git ls-files -- ''${q(d)}`, st.root, 30000, signal)).stdout.split("\n").filter((f) => f.endsWith(".go") && dirname(f) === d);
              if (!known.length) whats.push(`new package ''${d}`);
            }
            if (src.includes("go.mod")) {
              const g = (await sh("git diff HEAD -U0 -- go.mod", st.root, 30000, signal)).stdout;
              const mods = (sign: string) => new Set([...g.matchAll(new RegExp(`^\\''${sign}\\s*(?:require\\s+)?([\\w.-]+\\.[a-z]{2,}/\\S+)\\s+v\\d`, "gm"))].map((m) => m[1]));
              const gone = mods("-");
              for (const m of mods("+")) if (!gone.has(m)) whats.push(`new go.mod dependency ''${m}`);
            }
            for (const w of whats) if (!st.news.some((n) => n.what === w)) st.news.push({ id: `N''${st.news.length + 1}`, what: w });
            const goSrc = src.filter((f) => f.endsWith(".go") && existsSync(join(st.root, f)));
            if (goSrc.length) {
              const freshGo = new Set(fresh);
              const tracked = goSrc.filter((f) => !freshGo.has(f));
              const added = [
                ...(tracked.length ? (await sh(`git diff HEAD -U0 -- ''${tracked.map(q).join(" ")}`, st.root, 30000, signal)).stdout.split("\n").filter((l) => l.startsWith("+") && !l.startsWith("+++")).map((l) => l.slice(1)) : []),
                ...goSrc.filter((f) => freshGo.has(f)).flatMap((f) => readFileSync(join(st.root, f), "utf8").split("\n")),
              ];
              const decl = /^func\s+(?:\(([^)]*)\)\s*)?([A-Z]\w*)\s*(?:\[[^\]]*\])?\(([^)]*)\)\s*([^{]*)|^type\s+([A-Z]\w*)\s/;
              const existing = (await sh(`git grep -n -E '^(func (\\([^)]*\\) ?)?[A-Z][A-Za-z0-9_]*(\\[[^]]*\\])?\\(|type [A-Z][A-Za-z0-9_]* )' HEAD -- '*.go' ':!:*_test.go'`, st.root, 60000, signal)).stdout
                .split("\n")
                .map((l) => l.match(/^HEAD:([^:]+):(\d+):(.*)$/))
                .filter((m): m is RegExpMatchArray => !!m)
                .map((m) => {
                  const d = m[3].match(decl);
                  return d ? { path: m[1], line: m[2], name: d[2] ?? d[5], sig: d[2] ? sigOf(d[3], d[4]) : "" } : undefined;
                })
                .filter((x) => x !== undefined);
              for (const l of added) {
                const d = l.match(decl);
                const name = d && (d[2] ?? d[5]);
                if (!d || !name || st.dups.some((x) => x.name === name) || existing.some((e) => e.name === name && goSrc.includes(e.path))) continue;
                const sig = d[2] ? sigOf(d[3], d[4]) : "";
                const mine = tokens(name);
                const best = existing
                  .map((e) => {
                    const other = tokens(e.name);
                    const shared = mine.filter((t) => other.includes(t)).length;
                    const jac = shared / new Set([...mine, ...other]).size;
                    const score = e.name === name ? 3 : shared >= 2 && jac >= 0.5 ? 2 : shared >= 1 && sig && sig === e.sig ? 1 : 0;
                    return { e, score };
                  })
                  .filter((x) => x.score > 0)
                  .sort((a, b) => b.score - a.score)[0];
                if (best && st.dups.length < 8) st.dups.push({ id: `D''${st.dups.length + 1}`, name, of: `''${best.e.name} at ''${best.e.path}:''${best.e.line}` });
              }
            }
            const open = [...st.dups.map((d) => [d.id, `possible duplicate: new ''${d.name} vs existing ''${d.of}`]), ...st.news.map((n) => [n.id, n.what])].filter(([id]) => !st.answers[id]);
            gate(st, "new-code", open.length ? "fail" : "ok", open.map(([id, t]) => `''${id} ''${t}`).join("; "));
            if (open.length) return { ok: false, why: `Answer each of these in the summary, one line each:\n''${open.map(([id, t]) => `''${id} ''${t}`).join("\n")}\nWrite \`D1: <why it is not a duplicate, or reuse the existing one instead>\` and \`N1: <why the new file, package or dependency is needed>\`.` };
            return undefined;
          };

          const stress = async (st: State, signal?: AbortSignal): Promise<string | undefined> => {
            if (!existsSync(join(st.root, "go.mod"))) {
              st.stress = "skip";
              return undefined;
            }
            const files = (await changed(st)).filter((f) => f.endsWith(".go") && existsSync(join(st.root, f)));
            const fresh = new Set(await untracked(st, files));
            const tests = new Map<string, Set<string>>();
            for (const f of files.filter((x) => x.endsWith("_test.go"))) {
              const text = fresh.has(f) ? readFileSync(join(st.root, f), "utf8") : (await sh(`git diff HEAD -U0 -- ''${q(f)}`, st.root, 30000, signal)).stdout;
              const re = fresh.has(f) ? /^func (Test\w+)\(/gm : /^(?:\+func |@@[^@]*@@ func )(Test\w+)\(/gm;
              for (const m of text.matchAll(re)) tests.set(dirname(f), (tests.get(dirname(f)) ?? new Set()).add(m[1]));
            }
            const pkgs = [...new Set(files.filter((f) => !isTest(f)).map((f) => "./" + dirname(f)))];
            const cmds = [...[...tests].map(([d, names]) => `go test -race -count=3 -shuffle=on -run ''${q(`^(''${[...names].join("|")})$`)} ''${q("./" + d)}`), ...(pkgs.length ? [`go test -race -count=1 ''${pkgs.map(q).join(" ")}`] : [])];
            if (!cmds.length) {
              st.stress = "skip";
              return undefined;
            }
            for (let cmd of cmds) {
              let r = await sh(cmd, st.root, 900000, signal);
              if (r.code !== 0 && /requires cgo|-race is not supported|race detector/i.test(r.out)) {
                fact(st, "harness", `go test -race unavailable here: ''${head(r.out.match(/.*(requires cgo|not supported|race detector).*/i)?.[0] ?? "", 120)}`);
                cmd = cmd.replace("-race ", "");
                r = await sh(cmd, st.root, 900000, signal);
              }
              gate(st, cmd.includes("-shuffle") ? "stress" : "race", r.code === 0 ? "ok" : "fail", cmd);
              if (r.code !== 0) {
                fact(st, "hate", `unstable or racy tests: ''${head(cmd, 120)}`, true);
                return `New or changed tests are not stable or race free (''${cmd}):\n''${tail(r.out.split("\n").filter((l) => /^(--- FAIL|FAIL|panic:|WARNING: DATA RACE|\s+\S+\.go:\d+)/.test(l)).join("\n") || r.out, 30)}`;
              }
            }
            st.stress = "ok";
            return undefined;
          };

          const mutate = async (st: State, signal?: AbortSignal): Promise<string | undefined> => {
            if (!existsSync(join(st.root, "go.mod"))) return undefined;
            if ((await sh("command -v gremlins", st.root, 10000, signal)).code !== 0) {
              if (!st.mutation) fact(st, "harness", "gremlins is not on PATH, mutation testing skipped");
              st.mutation = "skip";
              gate(st, "mutation", "skipped", "gremlins not on PATH");
              return undefined;
            }
            const files = (await changed(st)).filter((f) => f.endsWith(".go") && !isTest(f) && existsSync(join(st.root, f)));
            const fresh = new Set(await untracked(st, files));
            const span = new Map<string, [number, number][]>();
            for (const f of files) span.set(f, fresh.has(f) ? [[1, Infinity]] : ranges((await sh(`git diff HEAD -U0 -- ''${q(f)}`, st.root, 30000, signal)).stdout));
            const lived: string[] = [];
            for (const d of new Set(files.map((f) => dirname(f)))) {
              const r = await sh(`gremlins unleash ''${q("./" + d)}`, st.root, 1800000, signal);
              for (const m of r.out.matchAll(/\bLIVED\s+(\S+)\s+at\s+(\S+?):(\d+):(\d+)/g)) {
                const f = files.find((x) => x === m[2] || x.endsWith("/" + m[2]) || m[2].endsWith("/" + x) || join(d, m[2]) === x);
                const n = Number(m[3]);
                if (f && span.get(f)!.some(([a, b]) => n >= a && n <= b)) lived.push(`LIVED ''${m[1]} at ''${f}:''${n}:''${m[4]}: ''${head(readFileSync(join(st.root, f), "utf8").split("\n")[n - 1] ?? "", 120)}`);
              }
            }
            st.mutation = lived.length ? "fail" : "ok";
            gate(st, "mutation", lived.length ? "fail" : "ok", lived.join("; "));
            if (!lived.length) return undefined;
            fact(st, "hate", `''${lived.length} mutant(s) survived in changed code: ''${head(lived[0], 120)}`, true);
            return `Mutation testing: ''${lived.length} mutant(s) survived in changed code:\n''${lived.slice(0, 8).join("\n")}\nAdd or strengthen a test so each mutant fails, then call advance_phase again.`;
          };

          const reviewDir = (st: State) => join(projDir(st), "review", st.run);

          const keep = async (st: State) => {
            const dir = reviewDir(st);
            rmSync(dir, { recursive: true, force: true });
            const files = await changed(st);
            for (const f of files)
              if (existsSync(join(st.root, f))) {
                mkdirSync(dirname(join(dir, f)), { recursive: true });
                writeFileSync(join(dir, f), readFileSync(join(st.root, f)));
              }
            st.reviewFiles = files;
          };

          const since = async (st: State, stat: boolean) => {
            const dir = reviewDir(st);
            const files = [...new Set([...(st.reviewFiles ?? []), ...(await changed(st))])];
            let n = 0;
            let text = "";
            for (const f of files) {
              const a = existsSync(join(dir, f)) ? join(dir, f) : "/dev/null";
              const b = existsSync(join(st.root, f)) ? join(st.root, f) : "/dev/null";
              const r = await sh(`git diff --no-index ''${stat ? "--numstat" : "-U3"} -- ''${q(a)} ''${q(b)}`, st.root, 30000);
              if (stat) n += r.stdout.split("\n").reduce((x, l) => x + l.split("\t").slice(0, 2).reduce((y, v) => y + (Number(v) || 0), 0), 0);
              else text += r.stdout.split(dir.slice(1) + "/").join("").split(st.root.slice(1) + "/").join("");
            }
            return { n, text: text.slice(0, 12000) };
          };

          const reviewRun = async (st: State, ctx: ExtensionToolContext, diff: string, signal?: AbortSignal): Promise<Check> => {
            const files = await changed(st);
            st.touched = files;
            const skills = skillPaths(st, files);
            const base = common(st) + (skills.length ? `Project skills for this kind of change, read them: ''${skills.join(", ")}\n` : "") + `''${st.localRound ? "Changed hunks since the last review" : "Diff"}:\n\`\`\`diff\n''${diff}\n\`\`\`\n`;
            const jobs = await batch(
              st,
              ctx,
              [
                { agent: "gopnik", task: `Review the Spec axis of code-review: criteria missing or partial, scope creep, looks implemented but wrong, each quoting its criterion C<n>. Then go through this diff line by line and attack it: bugs, wrong edge cases, missing error and nil handling, races, broken callers, hidden contract changes. Read callers and surrounding code to confirm each finding.\n''${base}Reply exactly, at most 12 lines, nothing else:\nVERDICT: PASS or BLOCK\n- [arch] path:line: <problem that needs a different approach>\n- [local] path:line: <problem fixable in place>` },
                { agent: "psychologist", task: `Review the Standards axis of code-review: this diff as the experts who own this code would, style and business logic; a documented repo standard overrides their habits and the smell baseline. Expert profiles: ''${join(projDir(st), "experts.md")}, reuse them, otherwise identify the experts from git log and blame.\n''${base}Reply exactly, at most 10 lines, nothing else, or NONE if they would accept it as is:\n- [arch] path:line: <what they would reject in the approach>\n- [local] path:line: <what they would change in place>` },
              ],
              `review''${st.localRound}`,
              signal,
            );
            if (!jobs || !jobs.some((j) => j.ok)) return { ok: true, status: "skipped", note: "Review agents unavailable, review skipped." };
            const g = jobs[0];
            const found = [...(g.ok ? tagged(g.answer ?? "", "gopnik") : []), ...(jobs[1].ok && !/^\s*NONE\b/i.test(jobs[1].answer ?? "") ? tagged(jobs[1].answer ?? "", "psychologist") : [])];
            const arch = found.filter((f) => f.tag === "arch");
            if ((g.ok && blocks(g.answer ?? "")) || arch.length) {
              const list = arch.length ? arch : [{ tag: "arch" as const, src: "gopnik", text: `BLOCK: ''${head((g.answer ?? "").replace(/^\s*VERDICT:.*$/im, ""), 300)}` }];
              const ids = list.map((f) => {
                fact(st, "design-miss", `design missed: review [arch] ''${f.src}: ''${head(f.text, 150)}`);
                return addItem(st, "constraint", `review ''${f.src}`, f.text);
              });
              st.fixing = false;
              return { ok: true, status: "fail", next: "design", note: `Review found [arch] problems, back to design. They are hard constraints now: ''${ids.join(", ")}.` };
            }
            if (!found.length) return { ok: true, note: "Review found nothing." };
            st.findings = found;
            st.fixing = true;
            await keep(st);
            save();
            return { ok: true, wait: `Phase review, round ''${st.localRound + 1}/''${MAX_LOCAL}. Findings:\n''${found.map((f, i) => `F''${i + 1} (''${f.src}) ''${f.text}`).join("\n")}\n''${GUIDE.review}` };
          };

          const reviewCheck = async (st: State, summary: string, ctx: ExtensionToolContext, signal?: AbortSignal): Promise<Check> => {
            const found = st.findings ?? [];
            if (!st.fixing || !found.length) return { ok: true };
            const how = (i: number) => summary.match(new RegExp(`\\bF''${i + 1}\\b\\s*[:.)-]?\\s*(fix|dismiss)\\b([^\\n]*)`, "i"));
            const missing = found.map((_, i) => (how(i) ? "" : `F''${i + 1}`)).filter(Boolean);
            if (missing.length) return { ok: false, why: `Mark each finding: ''${missing.join(", ")} need a line \`F<n>: fix <what>\` or \`F<n>: dismiss <why>\`.` };
            st.resolution = [st.resolution, summary.slice(0, 1500)].filter(Boolean).join("\n");
            found.forEach((f, i) => fact(st, "review", `review finding (''${f.src}) ''${head(f.text, 100)} -> ''${head(how(i)![0], 100)}`, /fix/i.test(how(i)![1])));
            const fixes = found.filter((_, i) => /fix/i.test(how(i)![1])).length;
            const churn = (await since(st, true)).n;
            if (fixes && !churn) return { ok: false, why: "You marked findings as fix but changed nothing since the review. Fix them in place or dismiss them." };
            if (!churn) {
              st.fixing = false;
              return { ok: true, note: "All findings dismissed." };
            }
            if (st.reviewLines && churn > 0.3 * st.reviewLines) {
              const id = addItem(st, "constraint", "review", `local review fixes changed ''${churn} of ''${st.reviewLines} diff lines, more than 30%: ''${found.map((f) => head(f.text, 80)).join("; ")}`);
              fact(st, "design-miss", `design missed: local review fixes grew to ''${churn} of ''${st.reviewLines} lines`);
              st.fixing = false;
              return { ok: true, status: "fail", next: "design", note: `The review fixes are larger than 30% of the diff, treated as [arch]. Back to design with ''${id}.` };
            }
            const g = await runGates(ctx, signal);
            if (!g.ok) return { ok: false, why: g.text };
            const rp = await runRepros(st, signal);
            if (rp) return { ok: false, why: rp };
            st.localRound++;
            if (st.localRound >= MAX_LOCAL) {
              st.fixing = false;
              fact(st, "review", `review stopped after ''${MAX_LOCAL} local rounds, the last fixes were not re-reviewed`);
              return { ok: true, note: `''${g.text} Review closed after ''${MAX_LOCAL} local rounds.` };
            }
            return reviewRun(st, ctx, (await since(st, false)).text, signal);
          };

          const check = async (st: State, summary: string, evidence: string | undefined, ctx: ExtensionToolContext, signal?: AbortSignal): Promise<Check> => {
            const ev = (evidence ?? "").trim();
            if (!["verify", "checkpoint", "review"].includes(st.phase)) {
              const open = await unmet(st, summary, ev, signal);
              if (open) return { ok: false, why: open };
            }
            switch (st.phase) {
              case "triage": {
                const kind = summary.match(/\b(bug|feature|refactor|docs)\b/i)?.[1]?.toLowerCase();
                if (!kind) return { ok: false, why: "Start the summary with the task type: bug, feature, refactor or docs." };
                if (st.issue && !summary.toUpperCase().includes(st.issue)) return { ok: false, why: `Read issue ''${st.issue} with the youtrack MCP tools, then name ''${st.issue} in the summary and restate its expected behavior.` };
                if (st.issue && summary.replace(/\s+/g, " ").trim().length < 60) return { ok: false, why: `Restate the expected behavior from ''${st.issue} in 1-3 lines.` };
                const lines = summary.split("\n");
                const at = lines.findIndex((l) => /acceptance criteria/i.test(l));
                const criteria: string[] = [];
                for (const l of at < 0 ? [] : lines.slice(at + 1)) {
                  const m = l.match(/^\s*(?:[-*]\s*)?(?:C?\d+[.):])\s+(\S.*)$/);
                  if (m) criteria.push(head(m[1], 200));
                  else if (l.trim() && criteria.length) break;
                }
                if (!criteria.length) return { ok: false, why: "Add a line `Acceptance criteria:` followed by a numbered list `1. ...`, at least one checkable criterion from the task." };
                st.criteria = [...criteria.slice(0, 8), ...(st.criteria ?? [])];
                st.kind = kind;
                st.brief = summary.slice(0, 1500);
                return { ok: true, note: `Criteria stored:''${listCriteria(st.criteria)}` };
              }
              case "localize": {
                const files = [
                  ...new Set(
                    summary
                      .split(/[\s,;()`'"<>\[\]]+/)
                      .map((t) => t.replace(/(:\d+)+$/, "").replace(/[.:]+$/, ""))
                      .filter((t) => /[./]/.test(t))
                      .map((t) => (isAbsolute(t) ? t : resolve(st.root, t)))
                      .filter((p) => {
                        try {
                          return statSync(p).isFile();
                        } catch {
                          return false;
                        }
                      }),
                  ),
                ];
                if (!files.length) return { ok: false, why: `The summary names no existing file. Write repo-relative paths, for example internal/foo/bar.go, relative to ''${st.root}.` };
                st.files = files;
                st.localized = summary.slice(0, 1500);
                return { ok: true, note: `Located: ''${files.map((f) => f.replace(st.root + "/", "")).join(", ")}` };
              }
              case "reproduce": {
                const skip = ev.match(/^skip:\s*(.+)/is)?.[1]?.trim();
                if (skip) {
                  if (st.kind !== "refactor" && st.kind !== "docs") return { ok: false, why: `Only refactor or docs tasks may skip reproduce, this task is a ''${st.kind}. Write a failing test.` };
                  if (skip.length < 10) return { ok: false, why: "Give a real reason why no behavior changes after `skip:`." };
                  st.skip = skip;
                  return { ok: true, status: "skipped", note: `Reproduce skipped: ''${skip}` };
                }
                if (!TEST_CMD.test(ev)) return { ok: false, why: "Pass evidence: the exact test command, for example `go test ./pkg/x -run TestY -count=1`." };
                const hyps = summary.split("\n").filter((l) => /^\s*(\d+[.)]|[-*])\s+.*\bif\b.+\bthen\b/i.test(l));
                if (st.kind === "bug" && !st.hypotheses && (hyps.length < 3 || hyps.length > 5))
                  return { ok: false, why: `Rank 3-5 falsifiable hypotheses in the summary (found ''${hyps.length}), one per line: \`1. If <X> is the cause, then <changing Y> makes the test pass\`.` };
                const r = await sh(ev, st.root, 600000, signal);
                if (r.code === 0) return { ok: false, why: `The command passes now, so it reproduces nothing. Make the test fail for the expected reason.\n''${tail(r.out, 10)}` };
                if (r.code === 124) return { ok: false, why: "The command timed out after 10 minutes. Narrow it with -run or a single package." };
                if (NOT_RUN.test(r.out)) return { ok: false, why: `The command did not run the test.\n''${tail(r.out, 15)}` };
                if (/\[build failed\]|^# \S+/m.test(r.out)) {
                  const near = new Set([...(st.files ?? []), ...(await changed(st)).map((f) => join(st.root, f))].map((f) => dirname(f)));
                  const errs = [...r.out.matchAll(/^(?:\.\/)?(\S+\.go):\d+(?::\d+)?:/gm)].map((m) => dirname(resolve(st.root, m[1])));
                  if (!errs.some((d) => near.has(d))) return { ok: false, why: `Build fails in code you did not localize or touch. Fix the command or the test setup.\n''${tail(r.out, 15)}` };
                }
                st.repros = [...new Set([...st.repros, ev])];
                if (hyps.length >= 3) st.hypotheses = hyps.slice(0, 5).map((l) => head(l, 200)).join("\n");
                return { ok: true, note: `Repro fails as expected:\n''${tail(r.out, 8, 800)}` };
              }
              case "design":
                return designCheck(st, summary, ctx, signal);
              case "checkpoint": {
                if (!st.decision && st.questions) return { ok: true, wait: `The pipeline waits for the user's decision.\n''${screen(st)}\nShow this screen to the user and end your turn.` };
                if (!st.decision) {
                  const open = await unmet(st, summary, ev, signal);
                  if (open) return { ok: false, why: open };
                  const qs = summary.split(/^(?=[\s*_#>❓-]*Q\d+\b)/m).filter((b) => /^[\s*_#>❓-]*Q\d+\b/.test(b));
                  if (!qs.length) return { ok: false, why: "Write one round of questions, each `Q<n>: <question worded so that yes accepts your recommendation>` followed by a line `Recommended: <your answer>`." };
                  if (qs.length > 8) return { ok: false, why: `''${qs.length} questions: ask only the decisions on the frontier, at most 8, and find the facts yourself.` };
                  const bare = qs.filter((b) => !/recommend|➡/i.test(b)).map((b) => b.match(/Q\d+/)![0]);
                  if (bare.length) return { ok: false, why: `Give your recommended answer for ''${bare.join(", ")} on a line \`Recommended: <answer>\`.` };
                  st.questions = qs.map((b) => b.trim()).join("\n").slice(0, 3000);
                  return { ok: true, wait: `Phase checkpoint.\n''${screen(st)}\nShow this screen to the user as is and end your turn now. Do not call tools. The user's next message is the decision.` };
                }
                const route = summary.match(/route:\s*(design|plan)\b/i)?.[1]?.toLowerCase();
                if (!route) return { ok: false, why: `User decision: "''${head(st.decision, 300)}". A plain yes accepts every recommended answer. Call advance_phase with summary \`route: design\` if it changes the approach or the acceptance criteria, else \`route: plan\`, plus one line why.` };
                const d = st.decision;
                st.decision = undefined;
                st.checked = true;
                if (route === "design") {
                  const id = addItem(st, "constraint", "user", d);
                  fact(st, "design-miss", `design missed the user's checkpoint decision: ''${head(d, 150)}`);
                  return { ok: true, next: "design", note: `Back to design with the user's decision as hard constraint ''${id}.` };
                }
                for (const i of openItems(st, ["arch", "scenario", "rival"])) {
                  i.open = false;
                  fact(st, "design", `user accepted the design with ''${i.id} unresolved: ''${head(i.text, 120)}`);
                }
                fact(st, "checkpoint", `user decision: ''${head(d, 150)}`, true);
                return { ok: true, note: `User decision: ''${head(d, 200)}` };
              }
              case "plan": {
                const steps = summary.split("\n").filter((l) => /^\s*\d+[.)]\s+\S/.test(l));
                if (!steps.length) return { ok: false, why: "Write the plan as a numbered list, one step per line: `1. ...`." };
                if (steps.length > 5) return { ok: false, why: `The plan has ''${steps.length} steps, merge them into at most 5.` };
                const loose = steps.filter((l) => !/blocked by/i.test(l)).map((l) => head(l, 40));
                if (loose.length) return { ok: false, why: `Give each slice its blocking edges, \`blocked by: <n or none>\` on its line: ''${loose.join("; ")}.` };
                if (pathsOf(st).some((f) => /\.proto$|swagger|openapi|migrat/i.test(f)) && !(/expand/i.test(summary) && /contract/i.test(summary)))
                  return { ok: false, why: "The change touches proto, swagger or migrations: sequence it expand–contract, slices that expand (add the new form), migrate the callers and contract (remove the old form)." };
                const est = estimateOf(summary);
                if (est === undefined || est < 1) return { ok: false, why: "Add a line `Estimated diff: <N> lines` with the expected non-test diff size." };
                const open = openItems(st, ["expect"]).filter((i) => {
                  const a = answerOf(summary, i.id);
                  return !/^adopt\b/i.test(a) && !/^decline\b.{15,}/i.test(a);
                });
                if (open.length) return { ok: false, why: `Answer each expert expectation: ''${open.map((i) => `''${i.id} ''${head(i.text, 100)}`).join("; ")}. Write \`E1: adopt <how>\` or \`E1: decline <why>\`.` };
                for (const i of openItems(st, ["local"])) i.open = false;
                for (const i of openItems(st, ["expect"])) {
                  i.open = false;
                  fact(st, "design", `''${i.id} ''${head(i.text, 80)} -> ''${head(answerOf(summary, i.id), 80)}`, true);
                }
                st.planEstimate = est;
                st.plan = summary.slice(0, 1500);
                return { ok: true };
              }
              case "implement": {
                const files = (await changed(st, st.mark ?? st.snapshot)).filter((f) => !isTest(f));
                if (!files.length) return { ok: false, why: "No non-test file changed in this phase. Make the change from the plan first." };
                const h = await hate(st, summary, signal);
                if (h) return h;
                return { ok: true, note: `Changed: ''${files.join(", ")}` };
              }
              case "verify": {
                const missing: string[] = [];
                for (const [i] of (st.criteria ?? []).entries()) {
                  const id = `C''${i + 1}`;
                  const m = ev.match(new RegExp(`^\\s*[-*]?\\s*''${id}\\s*[:=-]\\s*(.+)$`, "im"))?.[1]?.trim() ?? "";
                  const loc = m.match(/^(\S+?):(\d+)\b\s*(.*)$/);
                  const test = m.match(/^`?((?:Test|Benchmark|Example|Fuzz|test_)\w*)`?/)?.[1];
                  if (loc) {
                    if (!existsSync(isAbsolute(loc[1]) ? loc[1] : join(st.root, loc[1]))) missing.push(`''${id} (no file ''${loc[1]})`);
                    else if (loc[3].replace(/^(because|:|-)\s*/i, "").length < 10) missing.push(`''${id} (justify ''${loc[1]}:''${loc[2]} in one line)`);
                  } else if (test) {
                    if ((await sh(`git grep --untracked -qw ''${q(test)}`, st.root, 30000, signal)).code !== 0) missing.push(`''${id} (test ''${test} not found)`);
                  } else missing.push(id);
                }
                if (missing.length) return { ok: false, why: `Evidence must map every acceptance criterion to a test or path:line, one per line (\`C1: TestName\` or \`C1: path/file.go:40 because ...\`). Missing or invalid: ''${missing.join(", ")}.` };
                const h = await hate(st, summary, signal);
                if (h) return h;
                const dbg = [
                  ...(await sh("git diff HEAD -U0", st.root, 30000, signal)).stdout.split("\n").filter((l) => l.startsWith("+") && !l.startsWith("+++")),
                  ...(await sh("git ls-files --others --exclude-standard -z | xargs -0r grep -HnF '[DEBUG' --", st.root, 30000, signal)).stdout.split("\n"),
                ].filter((l) => /\[DEBUG-\w*]|\[DEBUG\]/.test(l));
                if (dbg.length) return { ok: false, why: `Remove the tagged debug logs before verify:\n''${dbg.slice(0, 8).map((l) => head(l, 160)).join("\n")}` };
                const g = await runGates(ctx, signal);
                if (!g.ok) return { ok: false, why: g.text };
                const rp = await runRepros(st, signal);
                if (rp) return { ok: false, why: rp };
                const sx = await stress(st, signal);
                if (sx) return { ok: false, why: sx };
                const mx = await mutate(st, signal);
                if (mx) return { ok: false, why: mx };
                return { ok: true, note: [g.text, st.repros.length ? `Repro passes: ''${st.repros.join(" ; ")}` : "", (st.stress === "skip" ? "Stress and race skipped (no Go changes)." : "Stress and race ran ok."), st.mutation === "skip" ? "Mutation testing skipped (no gremlins)." : st.mutation === "ok" ? "No surviving mutants in changed code." : ""].filter(Boolean).join(" ") };
              }
              case "review":
                return reviewCheck(st, summary, ctx, signal);
              case "regress": {
                if (!existsSync(join(st.root, "go.mod"))) return { ok: true, status: "skipped", note: "No go.mod at the repo root, regress skipped." };
                const pkgs = await goPackages(st, await changed(st), signal);
                if (!pkgs.length) return { ok: true, status: "skipped", note: "No Go package changed, regress skipped." };
                const r = await sh(`go test -count=1 ''${pkgs.map(q).join(" ")}`, st.root, 900000, signal);
                if (r.code === 0) return { ok: true, note: `Regress ok: go test -count=1 on ''${pkgs.length} package(s).` };
                const failed = [...new Set([...r.out.matchAll(/--- FAIL: (\S+)/g)].map((m) => m[1]))];
                const listed = ev.match(/^flaky:\s*(.+)/is)?.[1] ?? "";
                if (flaky && failed.length && failed.every((t) => listed.includes(t))) return { ok: true, note: `Regress ok except flaky: ''${failed.join(", ")}` };
                const lines = r.out.split("\n").filter((l) => /^(--- FAIL|FAIL|panic:|\S+\.go:\d+)/.test(l));
                return { ok: false, why: `Regress failed (go test -count=1 ''${head(pkgs.join(" "), 200)}):\n''${tail(lines.join("\n") || r.out, 30)}\nRun the flaky tool on a failing test before you call it unrelated.` };
              }
              case "report": {
                if (!summary.trim()) return { ok: false, why: "Write the final report in the summary." };
                const gaps = [/^#*\s*summary\b/im.test(summary) ? "" : "## Summary", /^#*\s*evidence\b/im.test(summary) ? "" : "## Evidence", /^#*\s*merge danger\b/im.test(summary) ? "" : "## Merge Danger", /\b(one|two)-way\b/i.test(summary) ? "" : "Door: one-way or two-way", /blast radius/i.test(summary) ? "" : "Blast Radius: <one word>"].filter(Boolean);
                if (gaps.length) return { ok: false, why: `Write the report in the pr template, missing: ''${gaps.join(", ")}.` };
                st.report = summary.trim();
                return { ok: true };
              }
              case "retro":
                return retroCheck(st, summary);
            }
          };

          const collectFacts = (st: State, ctx: ExtensionContext) => {
            const F = tally();
            const H = tally();
            for (const l of st.log) (l.k === "harness" ? H : F).put(l.text, !!l.resolved);
            for (const [name, why] of Object.entries(st.skips)) {
              F.put(`skipped ''${name}: ''${why}`);
              if (st.enforced?.[name]) H.put(`''${name} was required in ''${st.enforced[name]}, then skipped: ''${head(why, 100)}`);
            }
            if (st.skip) F.put(`reproduce skipped: ''${st.skip}`);
            for (const d of st.dups) F.put(`possible duplicate ''${d.name} of ''${d.of} -> ''${head(st.answers[d.id] ?? "unanswered", 100)}`, !!st.answers[d.id]);
            for (const n of st.news) F.put(`''${n.what} -> ''${head(st.answers[n.id] ?? "unanswered", 100)}`, !!st.answers[n.id]);
            for (const i of st.items) if (i.open && i.kind !== "local") F.put(`design item ''${i.id} (''${i.src}) left open: ''${head(i.text, 120)}`);
            const rejects = new Map<string, number>();
            for (const l of st.log) if (l.k === "advance") rejects.set(head(l.text, 90), (rejects.get(head(l.text, 90)) ?? 0) + 1);
            for (const [t, n] of rejects) if (n >= 3) H.put(`''${n} rejections on the same criterion: ''${t}`);
            const quit = st.log.find((l) => l.k === "give_up")?.phase;
            if (quit) for (const l of st.log) if (l.k === "blocked" && l.phase === quit) H.put(`before give_up: ''${l.text}`);
            const branch = ctx.sessionManager.getBranch() as Entry[];
            const from = branch.findIndex((e) => e.type === "custom" && e.customType === "pipeline" && e.data?.state?.run === st.run);
            let phase: Phase = "triage";
            const turns: Record<string, number> = {};
            const calls = new Map<string, number>();
            let turn = 0;
            let peak = 0;
            let compactions = 0;
            let masks = 0;
            let cut: unknown;
            let model: string | undefined;
            let between: string[] = [];
            for (const e of branch.slice(Math.max(0, from))) {
              if (e.type === "custom" && e.customType === "pipeline" && e.data?.state?.run === st.run) phase = e.data.state.phase;
              if (e.type === "compaction") compactions++, between.push("compaction");
              if (e.type === "model_change") between.push(`model_change ''${e.modelId}`);
              if (e.type === "custom_message") between.push(`custom_message ''${e.customType}`);
              if (e.type === "custom" && e.customType === "context-keeper") {
                if (e.data?.cutoff !== undefined && e.data.cutoff !== cut) masks++, between.push("context-keeper mask");
                cut = e.data?.cutoff;
              }
              const m = e.type === "message" ? e.message : undefined;
              if (m?.role === "toolResult") {
                const text = textOf(m);
                if (m.isError && (m.toolName === "edit" || /^aft_(?!outline|zoom|search)/.test(m.toolName ?? ""))) H.put(`''${m.toolName} failed in ''${phase}: ''${head(text, 100)}`);
                if (/^(Blocked: this|Skipped: you already ran)/.test(text)) H.put(`loop guard triggered on ''${m.toolName} in ''${phase}`);
                between.push(`tool ''${m.toolName}`);
              }
              if (m?.role === "user") between.push("user message");
              if (m?.role !== "assistant") continue;
              turn++;
              turns[phase] = (turns[phase] ?? 0) + 1;
              for (const c of Array.isArray(m.content) ? m.content : []) if (c.type === "toolCall") calls.set(`''${c.name} ''${JSON.stringify(c.arguments)}`, (calls.get(`''${c.name} ''${JSON.stringify(c.arguments)}`) ?? 0) + 1);
              const u = m.usage ?? {};
              const seen = (u.input ?? 0) + (u.cacheRead ?? 0);
              peak = Math.max(peak, seen);
              if (turn > 1 && seen > 8000 && (u.cacheRead ?? 0) < seen / 2) H.put(`turn ''${turn} in ''${phase}: cache read ''${u.cacheRead ?? 0} of ''${seen} tokens, after ''${head([...new Set(between)].join(", ") || "nothing", 120)}`);
              if (m.model && model && m.model !== model) H.put(`model switched ''${model} -> ''${m.model} at turn ''${turn} in ''${phase}`);
              if (m.stopReason === "length" || m.stopReason === "error") H.put(`turn ''${turn} in ''${phase} stopped with ''${m.stopReason}''${m.errorMessage ? `: ''${head(m.errorMessage, 80)}` : ""}`);
              const budget = [2048, 4096, 6144].find((b) => Math.abs((u.reasoning ?? 0) - b) <= b * 0.05);
              if (budget) H.put(`turn ''${turn} in ''${phase}: thinking used ''${u.reasoning} tokens, the whole ''${budget} budget`);
              model = m.model ?? model;
              between = [];
            }
            for (const [k, n] of calls) if (n >= 3) F.put(`identical call repeated ''${n} times: ''${head(k, 120)}`);
            H.put(`context: peak ''${peak} tokens, ''${compactions} compactions, ''${masks} context-keeper masks`, compactions + masks === 0);
            const wall: Record<string, number> = {};
            st.timeline.forEach((t, i) => (wall[t.phase] = (wall[t.phase] ?? 0) + ((st.timeline[i + 1]?.at ?? Date.now()) - t.at)));
            const stats = PHASES.filter((p) => p !== "retro" && (wall[p] || turns[p])).map((p) => `''${p} ''${turns[p] ?? 0} turns ''${Math.round((wall[p] ?? 0) / 60000)} min`);
            st.facts = [...F.list(40), ...(stats.length ? [{ text: `phases: ''${stats.join(", ")}`, resolved: true }] : [])];
            st.hfacts = H.list(20);
          };

          const factsText = (st: State) =>
            `Facts of this run:\n''${(st.facts ?? []).map((f, i) => `F''${i + 1} ''${f.text}''${f.resolved ? " [resolved]" : ""}`).join("\n") || "none"}\n` +
            `Harness facts (pi setup and this pipeline):\n''${(st.hfacts ?? []).map((f, i) => `H''${i + 1} ''${f.text}''${f.resolved ? " [resolved]" : ""}`).join("\n") || "none"}`;

          const saveRetro = (st: State, items: Item[]) => {
            const dir = join(projDir(st), "retro");
            const jsonl = join(dir, "items.jsonl");
            const seen = new Map<string, number>();
            try {
              for (const l of readFileSync(jsonl, "utf8").split("\n").filter(Boolean)) {
                const o = JSON.parse(l) as Item;
                seen.set(`''${o.type}|''${o.target}`, (seen.get(`''${o.type}|''${o.target}`) ?? 0) + 1);
              }
            } catch {}
            const date = new Date().toLocaleDateString("sv-SE");
            const label = (st.issue ?? st.run.slice(0, 8)).replace(/[^\w.-]/g, "_");
            const file = join(dir, `''${date}-''${label}.md`);
            const global = join(homedir(), ".pi", "retro", "harness.jsonl");
            const hseen = new Map<string, number>();
            try {
              for (const l of readFileSync(global, "utf8").split("\n").filter(Boolean)) {
                const o = JSON.parse(l) as Item;
                hseen.set(o.target, (hseen.get(o.target) ?? 0) + 1);
              }
            } catch {}
            const times = items.map((it) => (it.type === "harness" ? (hseen.get(it.target) ?? 0) : (seen.get(`''${it.type}|''${it.target}`) ?? 0)) + 1);
            const seenText = (i: number) => (times[i] > 1 ? ` (seen ''${times[i]} times)` : "");
            const md =
              `# Retro ''${label} ''${date}\n\nTask: ''${st.task}\n\n## Facts\n''${factsText(st)}\n\n## Items\n` +
              (items.map((it, i) => `### ''${i + 1}. ''${it.type} -> ''${it.target}''${seenText(i)}\n- evidence: ''${it.evidence}\n- gap: ''${it.gap}\n\n''${it.proposal}\n`).join("\n") || "none\n");
            try {
              mkdirSync(dir, { recursive: true });
              writeFileSync(file, md);
              if (items.length) appendFileSync(jsonl, items.map((it) => JSON.stringify({ ...it, run: st.run, label, date, root: st.root })).join("\n") + "\n");
              const harness = items.filter((it) => it.type === "harness");
              if (harness.length) {
                mkdirSync(dirname(global), { recursive: true });
                appendFileSync(global, harness.map((it) => JSON.stringify({ ...it, project: st.root.replace(/\//g, "-"), run: st.run, label, date })).join("\n") + "\n");
              }
            } catch (e) {
              return `Retro could not be saved: ''${String(e)}`;
            }
            items.forEach((it, i) => emitEvent({ id: `''${st.node}:item:''${i + 1}`, parents: [st.node], kind: "step", label: `''${it.type}: ''${head(it.gap, 40)}`, run: st.run, phase: "retro", cwd: st.root, status: "ok", detail: it.target }));
            const order = items.map((_, i) => i).sort((a, b) => times[b] - times[a]);
            return `Retro saved to ''${file}.''${order.map((i) => `\n''${i + 1}. ''${items[i].type} -> ''${items[i].target}: ''${items[i].gap}''${seenText(i)}`).join("")}`;
          };

          const retroCheck = (st: State, summary: string): Check => {
            const facts = st.facts ?? [];
            const hfacts = st.hfacts ?? [];
            if (/^\s*(none|нет)\.?\s*$/i.test(summary)) {
              const open = [...facts.map((f, i) => (f.resolved ? "" : `F''${i + 1}`)), ...hfacts.map((f, i) => (f.resolved ? "" : `H''${i + 1}`))].filter(Boolean);
              return open.length ? { ok: false, why: `\`none\` is accepted only when every fact is resolved. Write items for ''${open.join(", ")}.` } : { ok: true, note: saveRetro(st, []) };
            }
            const items = parseItems(summary);
            const errs: string[] = [];
            if (!items.length) errs.push("No items found. Start each item with a line `type: ...`.");
            if (items.length > 7) errs.push(`''${items.length} items, keep at most 7.`);
            const cited = new Set<string>();
            items.forEach((it, i) => {
              const n = `Item ''${i + 1}`;
              if (!ITEM_TYPES.includes(it.type)) errs.push(`''${n}: type must be one of ''${ITEM_TYPES.join(", ")}.`);
              const ids = [...it.evidence.matchAll(/\b([FH])(\d+)\b/g)].map((m) => ({ k: m[1], n: Number(m[2]) }));
              for (const x of ids) cited.add(x.k + x.n);
              if (!ids.length) errs.push(`''${n}: evidence must cite fact ids like F1,H2.`);
              const bad = ids.filter((x) => x.n < 1 || x.n > (x.k === "F" ? facts.length : hfacts.length));
              if (bad.length) errs.push(`''${n}: unknown facts ''${bad.map((x) => x.k + x.n).join(", ")}, the facts are F1..F''${facts.length} and H1..H''${hfacts.length}.`);
              if (it.type === "harness" && !ids.some((x) => x.k === "H")) errs.push(`''${n}: a harness item must cite H facts.`);
              if (it.type === "harness" && !/pi\.nix|\.pi\/rules|mcp\.json|\.pi\/agent\/|settings\.json/.test(it.target))
                errs.push(`''${n}: a harness target must name a concrete file and setting: pi.nix <extension> <what>, ~/.pi/rules/<file> or mcp.json <server>.`);
              if (!it.gap || it.gap.includes("\n")) errs.push(`''${n}: gap must be exactly one line.`);
              if (!it.proposal) errs.push(`''${n}: proposal is empty, write the concrete text to add.`);
              else if (it.proposal.split("\n").length > 15) errs.push(`''${n}: proposal has more than 15 lines.`);
              if (!it.target) errs.push(`''${n}: target path is missing.`);
              if (it.type === "agents_md" && /\b(is|are) (located|defined|implemented|stored) in\b|\blives in\b|находится в|расположен|лежит в|определ[её]н в/i.test(it.proposal))
                errs.push(`''${n}: an AGENTS.md line must state a rule or constraint that cannot be read from the code, not where code lives.`);
            });
            const missed = facts.map((f, i) => (/design missed/.test(f.text) && !cited.has(`F''${i + 1}`) ? `F''${i + 1}` : "")).filter(Boolean);
            const style = st.res.find((r) => r.kind === "skill" && r.name === "writing-for-agents");
            if (style && items.some((it) => it.type === "skill" || it.type === "agents_md") && !st.read.includes(style.name)) errs.push(`Skill and AGENTS.md items follow the skill writing-for-agents: read ''${style.path} first.`);
            if (missed.length) errs.push(`Every \`design missed\` fact needs an item that says why the design missed it: ''${missed.join(", ")} are not cited.`);
            return errs.length ? { ok: false, why: errs.join("\n") } : { ok: true, note: saveRetro(st, items) };
          };

          const advance = async (st: State, summary: string, evidence: string | undefined, ctx: ExtensionToolContext, signal?: AbortSignal) => {
            const out: string[] = [];
            let r = await check(st, summary, evidence, ctx, signal);
            while (true) {
              if (!r.ok) {
                st.fails++;
                fact(st, "advance", `advance_phase failed in ''${st.phase}: ''${r.why.split("\n")[0]}`, true);
                if (st.fails >= MAX_FAILS) {
                  const phase = st.phase;
                  finish("fail", ctx, head(r.why, 200));
                  out.push(`''${r.why}\nPipeline stopped after ''${MAX_FAILS} failed attempts in ''${phase}. Tell the user what blocks you.`);
                } else {
                  save();
                  out.push(`Not done: ''${r.why}\nPhase ''${st.phase} (attempt ''${st.fails}/''${MAX_FAILS}) needs ''${NEED[st.phase]}''${st.phase === "verify" || st.phase === "regress" ? "\n" + guide(st) : ""}`);
                }
                return out.join("\n\n");
              }
              if (r.wait) {
                save();
                return [...out, r.wait].join("\n\n");
              }
              if (r.note) out.push(r.note);
              node(st, r.status ?? "ok", head(summary || r.note || "", 200));
              if (st.phase === "retro") {
                finish(st.gaveUp ? "fail" : "ok", ctx);
                out.push(`Pipeline ''${st.gaveUp ? "stopped after give_up" : "done"}. Now give the user the final report from the report phase, then the retro items, recurring ones first.\nReport:\n''${st.report ?? ""}`);
                return out.join("\n\n");
              }
              await enter(st, r.next ?? PHASES[PHASES.indexOf(st.phase) + 1], ctx);
              summary = "";
              const now = st.phase as Phase;
              if (now === "verify" || now === "regress") r = await check(st, "", now === "verify" ? evidence : undefined, ctx, signal);
              else if (now === "review") {
                const files = await changed(st);
                st.reviewLines = await diffLines(st, files);
                r = await reviewRun(st, ctx, await fullDiff(st, files), signal);
              } else if (now === "checkpoint") {
                if (!st.checked) {
                  save();
                  return [...out, `Phase checkpoint: ''${guide(st)}\nState of the run:\n''${screen(st)}`].join("\n\n");
                }
                r = skipCheckpoint(st);
              } else if (now === "retro") {
                collectFacts(st, ctx);
                save();
                return [...out, `Phase retro. ''${factsText(st)}\n''${GUIDE.retro}`].join("\n\n");
              } else return [...out, `Phase ''${st.phase}: ''${guide(st)}`].join("\n\n");
            }
          };

          const triageInput = async (st: State, type: string, text: string, ctx: ExtensionContext) => {
            st.inputs++;
            st.pending = undefined;
            fact(st, "design-miss", `design missed ''${type} from outside: ''${head(text, 150)}`);
            emitEvent({ id: `''${st.node}:input:''${st.inputs}`, parents: [st.node], kind: "step", label: `input ''${type}`, run: st.run, phase: st.phase, cwd: st.root, status: "ok", detail: head(text, 200) });
            const at = PHASES.indexOf(st.phase);
            let target: Phase | undefined;
            let note: string;
            if (type === "bug") {
              st.criteria = [...(st.criteria ?? []), head(text, 200)];
              note = `New acceptance criterion C''${st.criteria.length}: ''${head(text, 200)}. Write a failing test for it; the design must cover it in Test strategy.`;
              if (at > PHASES.indexOf("reproduce")) target = "reproduce";
            } else if (type === "idea") {
              st.ideas.push(head(text, 300));
              note = "The idea is evaluated as a rival on the next design submission against the current approach.";
              if (at > PHASES.indexOf("design")) target = "design";
            } else {
              const id = addItem(st, "constraint", type, text);
              note = `Recorded as hard constraint ''${id} for the design.`;
              if (at > PHASES.indexOf("design")) target = "design";
            }
            if (!target) {
              save();
              return `''${note}\nContinue phase ''${st.phase}: ''${guide(st)}`;
            }
            node(st, "skipped", `input ''${type}`);
            await enter(st, target, ctx);
            return `''${note}\nPhase ''${st.phase}: ''${guide(st)}`;
          };

          const restore = (ctx: ExtensionContext) => {
            s = load(ctx);
            shown = 0;
            blocked = false;
            publish(ctx);
          };
          pi.on("session_start", (_event, ctx) => restore(ctx));
          pi.on("session_tree", (_event, ctx) => restore(ctx));

          pi.on("input", (event) => {
            if (!s) return { action: "continue" as const };
            const text = event.text.trim();
            const m = text.match(/^input:\s*([\s\S]+)$/i);
            if (m) {
              s.pending = m[1].trim().slice(0, 2000);
              blocked = true;
              save();
            } else if (s.phase === "checkpoint" && !s.decision && event.source !== "extension" && text) {
              s.decision = text.slice(0, 2000);
              blocked = true;
              save();
            }
            return { action: "continue" as const };
          });

          pi.registerCommand("task", {
            description: "Run a task (text, YouTrack URL or issue ID) through the pipeline: triage, localize, reproduce, design, checkpoint, plan, implement, verify, review, regress, report",
            handler: async (args, ctx) => {
              const task = args.trim();
              if (!task) return ctx.ui.notify("Usage: /task <description>", "warning");
              if (planMode(ctx) !== "normal") return ctx.ui.notify("Plan mode is on, leave it with /plan first", "warning");
              if (s) return ctx.ui.notify(`A pipeline is running (''${s.phase}), use /task-abort first`, "warning");
              const guide = await start(task, ctx);
              pi.sendUserMessage(`''${task}\n\n''${guide}`, ctx.isIdle() ? undefined : { deliverAs: "followUp" });
            },
          });

          pi.registerCommand("task-input", {
            description: "Feed outside news into the running pipeline: a bug, an idea, a rewrite request or a constraint",
            handler: async (args, ctx) => {
              const text = args.trim();
              if (!text) return ctx.ui.notify("Usage: /task-input <text>", "warning");
              if (!s) return ctx.ui.notify("No pipeline is running", "warning");
              pi.sendUserMessage(`input: ''${text}`, ctx.isIdle() ? undefined : { deliverAs: "followUp" });
            },
          });

          pi.registerCommand("task-abort", {
            description: "Abort the running task pipeline",
            handler: async (_args, ctx) => {
              if (!s) return ctx.ui.notify("No pipeline is running", "info");
              finish("fail", ctx, "aborted by user");
            },
          });

          pi.registerTool({
            name: "pipeline_start",
            label: "Pipeline start",
            description: "Start the task pipeline for a code task: triage, localize, reproduce, design, checkpoint, plan, implement, verify, review, regress, report. Each phase is finished with advance_phase.",
            parameters: Type.Object({
              task: Type.String({ description: "The task in 1-3 sentences, or a YouTrack issue URL or ID" }),
              fresh: Type.Optional(Type.Boolean({ description: "Start a new run even if an unfinished run for this project exists; the old run stays resumable" })),
            }),
            async execute(_id, params, _signal, _onUpdate, ctx) {
              const fail = (text: string) => ({ content: [{ type: "text" as const, text }], details: {}, isError: true });
              if (planMode(ctx) !== "normal") return fail("Plan mode is on, the pipeline cannot start. Plan in plan mode instead.");
              if (s) return fail(`A pipeline is already running, phase ''${s.phase}. Continue it with advance_phase.`);
              if (!params.task.trim()) return fail("Pass the task text.");
              if (!params.fresh) {
                const top = await sh("git rev-parse --show-toplevel", ctx.cwd, 10000);
                const root = top.code === 0 ? top.stdout.trim() : ctx.cwd;
                const c = scanSessions().find((x) => x.cwd === root);
                if (c)
                  return fail(
                    `An unfinished pipeline run exists in another session (phase ''${c.state.phase}, run ''${c.state.run}, session ''${c.file}). Resume it with pipeline_resume, or start a new run with fresh=true (the old run stays resumable).`,
                  );
              }
              return { content: [{ type: "text", text: await start(params.task.trim(), ctx) }], details: {} };
            },
          });

          pi.registerTool({
            name: "pipeline_resume",
            label: "Pipeline resume",
            description: "Resume a task pipeline that stopped in another session (crash, closed pi, compaction) from the phase where it stopped. Without session it finds the latest unfinished run for this project; with session (path to the .jsonl or its session id) it resumes that run.",
            parameters: Type.Object({ session: Type.Optional(Type.String({ description: "Path to the session .jsonl or its session id, when several unfinished runs are found" })) }),
            async execute(_id, params, _signal, _onUpdate, ctx) {
              const fail = (text: string) => ({ content: [{ type: "text" as const, text }], details: {}, isError: true });
              if (s)
                return { content: [{ type: "text", text: `A pipeline is already running in this session, phase ''${s.phase}; resume is for a run stopped in another session.` }], details: {} };
              if (planMode(ctx) !== "normal") return fail("Plan mode is on, the pipeline cannot run. Plan in plan mode instead.");
              const top = await sh("git rev-parse --show-toplevel", ctx.cwd, 10000);
              const root = top.code === 0 ? top.stdout.trim() : ctx.cwd;
              const all = scanSessions();
              const cands = all.filter((x) => x.cwd === root);
              let pick: { file: string; cwd: string; state: State } | undefined;
              if (params.session) {
                const q = params.session.trim();
                pick = cands.find((x) => x.file === q || x.file.endsWith(`_''${q}.jsonl`)) ?? all.find((x) => x.file === q || x.file.endsWith(`_''${q}.jsonl`));
                if (!pick) return fail(`No unfinished pipeline run found for session ''${q}.`);
              } else {
                const same = cands.length ? cands : all;
                if (same.length === 0) return { content: [{ type: "text", text: "No unfinished pipeline run found for this project." }], details: {} };
                if (same.length > 1)
                  return {
                    content: [{ type: "text", text: `Several unfinished runs, pass one to pipeline_resume as session:\n''${same.map((x) => `- ''${x.state.phase} (run ''${x.state.run}, cwd ''${x.cwd}) ''${x.file}`).join("\n")}` }],
                    details: {},
                  };
                pick = same[0];
              }
              s = pick.state;
              emitEvent({ id: s.run, parents: [], kind: "run", label: s.issue ?? head(s.task), run: s.run, cwd: s.root, sessionId: ctx.sessionManager.getSessionId(), status: "running", detail: `resumed from ''${pick.file}` });
              node(s, "running");
              save();
              publish(ctx);
              const n = PHASES.indexOf(s.phase) + 1;
              const extra = s.phase === "checkpoint" ? `\nCheckpoint: ''${s.decision ? `decision given: ''${s.decision}` : "waiting for the user's decision"}` : "";
              return { content: [{ type: "text", text: `Resumed run ''${s.run}: ''${head(s.task, 200)}\nPhase ''${s.phase} (''${n}/''${PHASES.length}), attempt ''${s.fails + 1}/''${MAX_FAILS}''${extra}\n''${listCriteria(s.criteria)}''${s.phase === "design" || s.phase === "plan" ? itemsText(s) : ""}\nTo advance: ''${NEED[s.phase]} Continue the phase, do not start over.` }], details: {} };
            },
          });

          pi.registerTool({
            name: "advance_phase",
            label: "Advance phase",
            description: "Finish the current task pipeline phase. The pipeline checks the exit criteria in code and returns the next phase's instructions, or what is still missing.",
            parameters: Type.Object({
              summary: Type.String({ description: "What this phase produced, as the phase instructions ask" }),
              evidence: Type.Optional(Type.String({ description: "reproduce: the failing test command or `skip: <reason>`. implement/verify: `C1: TestName` lines. regress: `flaky: <TestNames>` after the flaky tool confirmed them" })),
            }),
            async execute(_id, params, signal, _onUpdate, ctx) {
              if (!s) return { content: [{ type: "text", text: "No pipeline is running. Start one with pipeline_start." }], details: {}, isError: true };
              const st = s;
              const text = await advance(st, params.summary ?? "", params.evidence, ctx, signal);
              return { content: [{ type: "text", text }], details: { run: st.run, phase: s?.phase ?? null } };
            },
          });

          pi.registerTool({
            name: "pipeline_input_triage",
            label: "Pipeline input triage",
            description: "Classify outside news that arrived during the task pipeline (a message starting with `input:`). The pipeline routes it.",
            parameters: Type.Object({
              type: Type.Union([Type.Literal("bug"), Type.Literal("idea"), Type.Literal("rewrite"), Type.Literal("constraint")], { description: "bug: a defect someone found; idea: another way to solve it; rewrite: a request to redo the approach; constraint: a new requirement" }),
              summary: Type.String({ description: "The news restated in one checkable line" }),
            }),
            async execute(_id, params, _signal, _onUpdate, ctx) {
              if (!s?.pending) return { content: [{ type: "text", text: "No outside input is pending. Continue with advance_phase." }], details: {}, isError: true };
              const st = s;
              const text = await triageInput(st, params.type, params.summary.trim() || st.pending!, ctx);
              return { content: [{ type: "text", text }], details: { run: st.run, phase: st.phase } };
            },
          });

          const use = (st: State, r: Res) => {
            const list = r.kind === "skill" ? st.read : st.calls;
            if (!st.used.includes(`''${r.kind} ''${r.name}`)) st.used.push(`''${r.kind} ''${r.name}`);
            if (list.includes(r.name)) return;
            list.push(r.name);
            emitEvent({ id: `''${st.node}:''${r.kind}:''${r.name}`, parents: [st.node], kind: "step", label: `''${r.kind}: ''${r.name}`, run: st.run, phase: st.phase, cwd: st.root, status: "ok" });
            save();
          };

          pi.on("tool_call", (event) => {
            if (!s) return;
            const st = s;
            const server = serverOf(event.toolName, event.input as { server?: unknown });
            const servers = event.toolName === "codemode" ? scriptServers((event.input as { code?: unknown }).code) : server ? [server] : [];
            for (const r of st.res) if (r.kind === "mcp" && servers.includes(norm(r.name))) use(st, r);
            const block = (reason: string) => {
              blocked = true;
              fact(st, "blocked", `''${event.toolName} blocked in ''${st.phase}: ''${reason}`);
              blockedIds.add(event.toolCallId);
              save();
              return { block: true, reason: `Pipeline phase ''${st.phase}: ''${reason} To advance: ''${NEED[st.phase]}` };
            };
            const name = event.toolName;
            const input = event.input as { command?: unknown; path?: unknown; tasks?: { agent?: string }[] };
            if (st.pending && name !== "pipeline_input_triage") return block(`outside input is pending: "''${head(st.pending, 120)}". Call pipeline_input_triage first.`);
            if (st.phase === "checkpoint" && (st.questions || st.decision) && !["advance_phase", "pipeline_input_triage"].includes(name))
              return block(st.decision ? "the user answered. Call advance_phase with the route." : "the pipeline waits for the user. Show the checkpoint screen with the questions and end your turn.");
            if (READONLY.has(st.phase) || (st.phase === "review" && !st.fixing)) {
              if (name === "edit" || name === "write") return block("file edits are blocked.");
              if (name === "bash") {
                const c = checkCommand(String(input.command ?? ""));
                if (!c.safe) return block(`''${(c.reason ?? "mutating command.").replace(/^Plan mode:\s*/, "")} Only read-only commands are allowed.`);
              }
              if (name === "subagent" && (input.tasks ?? []).some((t) => !AGENTS.includes(t.agent ?? "scout"))) return block(`only ''${AGENTS.join(", ")} subagents are allowed.`);
            }
            if (st.phase === "reproduce" && (name === "edit" || name === "write") && !isTest(String(input.path ?? ""))) return block("only test files may be edited until the failing test exists.");
          });

          pi.on("tool_result", (event, ctx) => {
            if (!s) return;
            if (event.toolName === "flaky" && !event.isError) flaky = true;
            if (event.toolName === "give_up" && !event.isError) {
              const st = s;
              fact(st, "give_up", `give_up in ''${st.phase}: ''${String((event.input as { reason?: unknown }).reason ?? "")}`);
              st.gaveUp = true;
              if (st.phase === "retro") return void save();
              return void enter(st, "retro", ctx).then(() => {
                collectFacts(st, ctx);
                blocked = true;
                save();
              });
            }
            if (event.isError && !blockedIds.has(event.toolCallId)) {
              const text = event.content.map((c) => (c.type === "text" ? c.text : "")).join(" ");
              const server = serverOf(event.toolName, event.input as { server?: unknown });
              const r = server ? s.res.find((x) => x.kind === "mcp" && norm(x.name) === server) : undefined;
              if (r && DOWN.test(text)) {
                if (!s.down.includes(r.name)) s.down.push(r.name);
                fact(s, "mcp", `server ''${r.name} unavailable: ''${head(text, 120)}`);
              } else fact(s, r ? "mcp" : "tool", `''${event.toolName} error in ''${s.phase}: ''${head(text, 150)}`);
              save();
            }
            if (!event.isError && ["read", "aft_zoom", "aft_outline", "bash"].includes(event.toolName)) {
              const vals = Object.values(event.input).flatMap((v) => (Array.isArray(v) ? v : [v])).filter((v): v is string => typeof v === "string");
              for (const r of s.res)
                if (r.path && vals.some((v) => v.includes(r.path!) || resolve(ctx.cwd, v) === r.path || v.includes(`.agents/skills/''${basename(dirname(r.path!))}/SKILL.md`))) use(s, r);
            }
            if ((event.toolName === "subagent" || event.toolName === "subagent_wait") && !event.parentToolCallId) recordJobs(s, (event.details as { jobs?: Job[] } | undefined)?.jobs ?? []);
          });

          pi.on("tool_result", async (event) => {
            if (!s || event.toolName !== "run_gates") return;
            const st = s;
            const sig = createHash("sha1").update(JSON.stringify(await snapshot(st.root))).digest("hex");
            for (const x of (event.details as { results?: { name: string; ok: boolean }[] } | undefined)?.results ?? []) {
              const last = st.gates?.[x.name];
              if (!x.ok) fact(st, "gate", `gate ''${x.name} failed in ''${st.phase}`, true);
              if (last && last.ok !== x.ok && last.sig === sig) fact(st, "harness", `gate ''${x.name} flipped ''${last.ok ? "ok -> fail" : "fail -> ok"} without a code change`);
              st.gates = { ...st.gates, [x.name]: { ok: x.ok, sig } };
            }
            save();
          });

          pi.on("context", (event, ctx) => {
            if (!s || planMode(ctx) === "plan") return;
            let since = 0;
            let seq = -1;
            for (const e of ctx.sessionManager.getBranch() as Entry[]) {
              if (e.type === "custom" && e.customType === "pipeline") {
                if ((e.data?.state?.seq ?? -1) !== seq) since = 0;
                seq = e.data?.state?.seq ?? -1;
              } else if (e.type === "message" && e.message?.role === "toolResult") since = e.message.toolName === "advance_phase" ? 0 : since + 1;
            }
            const bucket = Math.floor(since / EVERY);
            const show = blocked || bucket > shown;
            shown = bucket;
            blocked = false;
            if (!show) return;
            const extra = s.pending
              ? `\nOutside input arrived: "''${head(s.pending, 300)}". Call pipeline_input_triage with its type (bug, idea, rewrite or constraint) and a one-line summary before anything else.`
              : s.phase === "checkpoint"
                ? s.decision
                  ? `\nThe user's checkpoint decision: "''${head(s.decision, 400)}". A plain yes accepts every recommended answer. Call advance_phase with summary \`route: design\` if it changes the approach or the acceptance criteria, else \`route: plan\`, plus one line why.`
                  : s.questions
                    ? "\nShow the checkpoint screen with the questions to the user and end your turn."
                    : `\n''${GUIDE.checkpoint}`
                : "";
            const content =
              `[Pipeline] Task: ''${s.issue ? s.issue + " " : ""}''${head(s.task, 200)}\nPhase ''${s.phase} (''${PHASES.indexOf(s.phase) + 1}/''${PHASES.length})''${READONLY.has(s.phase) || (s.phase === "review" && !s.fixing) ? ", edits blocked" : ""}. ` +
              `To advance: ''${NEED[s.phase]} Then call advance_phase.` +
              extra +
              (s.phase === "retro" ? `\n''${factsText(s)}\n''${GUIDE.retro}` : (refresh(s, false), resText(s, relevant(s, s.phase, pathsOf(s)).filter((p) => !done(s!, p) && (p.must || !s!.skips[p.res.name])))));
            const reminder = { role: "custom", customType: "pipeline-reminder", content, display: false, timestamp: Date.now() };
            return { messages: [...event.messages, reminder as (typeof event.messages)[number]] };
          });
        }
      '';

      pipelineCommon = ''
        const EVENTS = join(homedir(), ".pi", "agent", "pipeline", "events.jsonl");
        function emitEvent(node: Record<string, unknown>) {
          try {
            mkdirSync(dirname(EVENTS), { recursive: true });
            appendFileSync(EVENTS, JSON.stringify({ ...node, ts: Date.now(), pid: process.pid }) + "\n");
          } catch {}
        }
        function currentNode(p?: { run: string; nodeId: string; phase?: string } | null) {
          if (p && p.nodeId) return { run: p.run, parent: p.nodeId, phase: p.phase };
          if (process.env.PI_PIPELINE_NODE) return { run: process.env.PI_PIPELINE_RUN ?? "", parent: process.env.PI_PIPELINE_NODE, phase: "" };
          return undefined;
        }
      '';

      appendSystemFile = pkgs.writeText "pi-append-system.md" /* markdown */ ''
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
      npmPins = {
        "@cortexkit/aft-pi" = config.programs.pi.aftVersion;
        "pi-lsp-extension" = "1.4.0";
      };
    in
    {
      options.programs.pi.aftVersion = lib.mkOption {
        type = lib.types.str;
        default = "0.59.0";
        description = "aft version shared by pi and opencode, both write the same storage";
      };

      config = {

        home.packages = [
          piNvimWrapped
          piStats
          piPipelineView
          piEval
          (pkgs.callPackage mkPiAcp { })
          pkgs.ast-grep
          pkgs.gopls
          pkgs.nixd
          pkgs.pyright
          pkgs.rust-analyzer
          pkgs.typescript-language-server
        ];

        # Не ходить на pi.dev при старте: version check, remote model catalog, install telemetry
        home.sessionVariables = {
          PI_OFFLINE = "1";
          LLAMA_BASE_URL = "http://127.0.0.1:8085";
        };

        home.file.".pi/agent/agents/scout.md".text = ''
          ---
          name: scout
          description: read-only reconnaissance of code and docs
          ${subagentReadOnly}---
          You are scout, a read-only reconnaissance agent started by another agent. The first user message is your task and the only context you get.

          Explore code and docs until the task is answered. Locate code with aft_search, aft_outline and lsp_references, files with find, then read only the line ranges you need. Check library and API facts with query-docs. Never modify files, never run commands that change state, and never ask the user questions.

          Your final message is the only thing the caller sees. Keep it to at most 40 lines. Start with the direct answer, then list the findings, each with its path:line. Mark what you could not confirm. Do not paste file contents or tool output.
        '';

        home.file.".pi/agent/agents/reviewer.md".text = ''
          ---
          name: reviewer
          description: read-only review of a diff or files for correctness bugs
          ${subagentReadOnly}---
          You are reviewer, a read-only code review agent started by another agent. The first user message is your task and the only context you get. It names a diff, a commit range or files to review.

          Look for correctness bugs: wrong logic, broken edge cases, missing error handling, races, resource leaks, security holes and mismatches with the surrounding code. Ignore style and naming unless they hide a bug. Read enough of the surrounding code to confirm each finding before you report it. Never modify files, never run commands that change state, and never ask the user questions.

          Your final message is the only thing the caller sees. Keep it to at most 40 lines. Rank the findings by severity (critical, major, minor). For each give its path:line, the problem and the input or case that breaks, in one or two sentences. If you find nothing, say so in one line.
        '';

        home.file.".pi/agent/agents/critic.md".text = ''
          ---
          name: critic
          description: antagonist of a proposed design, returns VERDICT PASS or BLOCK
          model: Protei/agent_proteya_slow
          ${subagentReadOnly}---
          You are critic, a read-only antagonist of the solution designer, started by another agent. The first user message is your task and the only context you get: the task, its acceptance criteria and the proposed design.

          Your goal is to tear the design apart. Judge depth, seams and locality in the vocabulary of ${agentSkillsDir}/codebase-design/SKILL.md. Check it against the real code: architectural flaws, the wrong layer, hidden coupling, contract breaks (proto, swagger, DB migrations, config), concurrency, error and partial-failure paths, rollout and backward compatibility, and what a teammate or tester will hit later. Never modify files, never run commands that change state, and never ask the user questions.

          Every objection must carry a concrete failing scenario (input, state, sequence of events) and the path:line it hits. An objection without a concrete scenario is worthless: do not write it.

          Your final message is the only thing the caller sees: at most 10 lines, nothing else. The first line is exactly `VERDICT: PASS` or `VERDICT: BLOCK`. Then one line per objection, most severe first, `- [arch] <objection that needs a different approach, scenario, path:line>` or `- [local] <objection fixable inside this approach, scenario, path:line>`. BLOCK only when there is an `[arch]` objection. If the task gives a different reply format, follow the task.
        '';

        home.file.".pi/agent/agents/tester.md".text = ''
          ---
          name: tester
          description: adversarial QA, scenarios that break a design, COVERED or MISSING
          model: Protei/agent_proteya_slow
          ${subagentReadOnly}---
          You are tester, an adversarial QA colleague working in parallel on the same ticket, started by another agent. The first user message is your task and the only context you get: the task, its acceptance criteria and the proposed design with its Test strategy.

          Find the scenarios that would break the design. Read the code the design touches and its existing tests to learn what is already covered, and ${agentSkillsDir}/tdd/SKILL.md for what a good test at a seam is. Think of boundary inputs, empty and nil values, duplicates, ordering, concurrent calls, restarts, partial failures, timeouts and old data or old clients. Check each scenario against the Test strategy section. Never modify files, never run commands that change state, and never ask the user questions.

          Every scenario must be concrete: the input and state that break it and the path:line it hits. A scenario without concrete input and state is worthless: do not write it.

          Your final message is the only thing the caller sees: at most 10 lines, nothing else, one line per scenario, most likely to break first: `- COVERED: <scenario> -> <the Test strategy line that covers it>` or `- MISSING: <scenario, the input that breaks it, path:line, the Go test that would catch it>`. If the task gives a different reply format, follow the task.
        '';

        home.file.".pi/agent/agents/rival.md".text = ''
          ---
          name: rival
          description: independent alternative design from task, criteria and code only
          ${subagentReadOnly}---
          You are rival, a read-only designer started by another agent. The first user message is your task and the only context you get: the task, its acceptance criteria, the located files and sometimes an idea to develop. You never see another design, so design your own from the task, the criteria and the code.

          You are the second design of ${agentSkillsDir}/codebase-design/DESIGN-IT-TWICE.md: follow the design constraint the task gives you. Aim for the simplest, most elegant change that reuses existing code: find the helpers, patterns and extension points already in place before inventing anything. Prefer the smallest diff that fully meets the criteria. Never modify files, never run commands that change state, and never ask the user questions.

          Your final message is the only thing the caller sees: exactly these three lines, nothing else:
          `APPROACH: <one paragraph: the change, the files with path:line of each change point and the existing code it reuses>`
          `DIFF: <estimated changed non-test lines, a number>`
          `WHY: <one line why it beats the obvious alternatives>`
        '';

        home.file.".pi/agent/agents/psychologist.md".text = ''
          ---
          name: psychologist
          description: emulates the most senior contributors of the touched code, their approach and style
          model: Protei/agent_proteya_slow
          tools: read, grep, find, ls, aft_outline, aft_zoom, aft_search, bash, codemode, write
          permission:
            tools:
              read: allow
              grep: allow
              find: allow
              ls: allow
              aft_outline: allow
              aft_zoom: allow
              aft_search: allow
              bash: allow
              codemode: allow
              write: allow
              edit: deny
          ---
          You are psychologist, a read-only agent started by another agent. The first user message is your task and the only context you get: the task and the paths it touches, or a diff to review as the experts would.

          1. Cache: the task names the expert profiles file `~/.pi/projects/<slug>/experts.md`. If it exists and covers the touched paths, and its first line `updated: <YYYY-MM-DD>` is less than 7 days old, reuse its profiles and skip step 2.
          2. Find the most experienced contributors of the touched area: `git shortlog -sne` and `git log --stat` on the touched paths, `git blame` on the key files, the size and complexity of their commits, and merge request titles through the gitlab MCP tools from codemode if you have them. Pick the 1-2 most senior. Write their profiles with evidence (commit hashes and path:line) to the profiles file with the first line `updated: <today>`. This is the only file you may write.
          3. Role-play each expert: how they would solve the task and how they would write and lay out the code (naming, errors, logging, structure, tests). Every expectation must rest on evidence from their commits.
          4. For a diff review you are the Standards axis of ${agentSkillsDir}/code-review/SKILL.md: find the documented standards (CODING_STANDARDS.md, CONTRIBUTING.md, AGENTS.md, linter configs); a documented standard overrides the experts' habits and the smell baseline, and is cited in the finding.

          Never modify any other file, never run commands that change state, and never ask the user questions.

          Your final message is the only thing the caller sees. Use exactly the reply format the task gives, nothing else:
          - For a task or design: at most 12 lines, per expert `EXPERT: <name> - <one line profile>`, then one line per concrete expectation `- <expectation, with a commit hash or path:line as evidence>`.
          - For a diff review: at most 10 lines, `- [arch] path:line: <what they would reject in the approach>` or `- [local] path:line: <what they would change in place>`, or the single word `NONE` if they would accept it as is.
          An expectation or finding without evidence is worthless: do not write it.
        '';

        home.file.".pi/agent/agents/gopnik.md".text = ''
          ---
          name: gopnik
          description: line-by-line paranoid antagonist of a diff, returns VERDICT PASS or BLOCK
          model: Protei/agent_proteya_slow
          ${subagentReadOnly}---
          You are gopnik, a read-only, paranoid code antagonist started by another agent. The first user message is your task and the only context you get. It names a diff, a commit range or files.

          First check the Spec axis of ${agentSkillsDir}/code-review/SKILL.md against the acceptance criteria in the task: missing or partial, scope creep, looks implemented but wrong, each finding quoting its criterion. Then pick on every changed line: nil and zero values, ignored errors, ctx cancellation and deadlines, goroutine and resource leaks, races, overflow and type conversions, injection, retries and idempotency, partial failure, timeouts, secrets in logs. Read the callers and callees to confirm each finding. Never modify files, never run commands that change state, and never ask the user questions.

          Every finding must carry a concrete failing scenario and its path:line. Prefer proving it with a failing test you describe in one line: test name, input and the actual result. A finding without a concrete scenario is worthless: do not write it.

          Your final message is the only thing the caller sees: at most 12 lines, nothing else. The first line is exactly `VERDICT: PASS` or `VERDICT: BLOCK`. Then one line per finding, most severe first, `- [arch] path:line: <problem that needs a different approach, scenario>` or `- [local] path:line: <problem fixable in place, scenario>`. If the task gives a different reply format, follow the task.
        '';

        home.file.".pi/rules/go/ctx-first.yml".text = ''
          id: go-ctx-first
          language: go
          severity: error
          message: context.Context must be the first parameter.
          rule:
            kind: parameter_declaration
            has:
              field: type
              regex: '^context\.Context$'
            follows:
              kind: parameter_declaration
              stopBy: end
        '';

        home.file.".pi/rules/go/errorf-wrap.yml".text = ''
          id: go-errorf-wrap
          language: go
          severity: error
          message: Wrap the error with %w instead of %v so callers can use errors.Is and errors.As.
          rule:
            pattern:
              context: 'func f() { fmt.Errorf($FMT, $$$) }'
              selector: call_expression
            has:
              field: arguments
              has:
                kind: identifier
                regex: '^err[A-Za-z0-9]*$'
                nthChild:
                  position: 1
                  reverse: true
          constraints:
            FMT:
              regex: '%v[^%]*"$'
        '';

        home.file.".pi/rules/go/errors-new-sprintf.yml".text = ''
          id: go-errors-new-sprintf
          language: go
          severity: error
          message: Use fmt.Errorf(...) instead of errors.New(fmt.Sprintf(...)).
          rule:
            pattern:
              context: 'func f() { errors.New(fmt.Sprintf($$$)) }'
              selector: call_expression
        '';

        home.file.".pi/rules/go/no-context-background.yml".text = ''
          id: go-no-context-background
          language: go
          severity: warning
          message: Pass the caller's ctx instead of creating a new root context. context.Background and context.TODO belong in main, init and tests.
          ignores:
            - "**/*_test.go"
          rule:
            pattern:
              context: 'func f() { context.$F() }'
              selector: call_expression
            not:
              inside:
                kind: function_declaration
                has:
                  field: name
                  regex: '^(main|init)$'
                stopBy: end
          constraints:
            F:
              regex: '^(Background|TODO)$'
        '';

        home.file.".pi/rules/go/no-exit-outside-main.yml".text = ''
          id: go-no-exit-outside-main
          language: go
          severity: error
          message: Only main may exit the process. Return an error instead of os.Exit or log.Fatal.
          ignores:
            - "**/*_test.go"
          rule:
            any:
              - pattern:
                  context: 'func f() { os.Exit($$$) }'
                  selector: call_expression
              - pattern:
                  context: 'func f() { log.$F($$$) }'
                  selector: call_expression
            not:
              inside:
                kind: function_declaration
                has:
                  field: name
                  regex: '^main$'
                stopBy: end
          constraints:
            F:
              regex: '^Fatal(f|ln)?$'
        '';

        home.file.".pi/rules/go/no-fmt-print.yml".text = ''
          id: go-no-fmt-print
          language: go
          severity: warning
          message: Do not print to stdout from a library package. Use the project logger or return the value.
          ignores:
            - "**/*_test.go"
          rule:
            pattern:
              context: 'func f() { fmt.$P($$$) }'
              selector: call_expression
            not:
              inside:
                kind: source_file
                has:
                  kind: package_clause
                  has:
                    kind: package_identifier
                    regex: '^main$'
                stopBy: end
          constraints:
            P:
              regex: '^Print(ln|f)?$'
        '';

        home.file.".pi/rules/go/no-panic.yml".text = ''
          id: go-no-panic
          language: go
          severity: error
          message: Return an error instead of panic. panic is allowed only in main, init and tests.
          ignores:
            - "**/*_test.go"
          rule:
            pattern:
              context: 'func f() { panic($$$) }'
              selector: call_expression
            not:
              inside:
                kind: function_declaration
                has:
                  field: name
                  regex: '^(main|init)$'
                stopBy: end
        '';

        home.activation.setupPi = mkAfter /* bash */ ''
          set -euo pipefail

          agent_dir="${piAgentDir}"
          cortexkit_dir="${config.home.homeDirectory}/.config/cortexkit"

          log() { printf '[pi] %s\n' "$*" >&2; }

          mkdir -p "$agent_dir" "$cortexkit_dir"

          cp --reflink=never "${aftJsonFile}" "$cortexkit_dir/aft.jsonc"
          chmod 644 "$cortexkit_dir/aft.jsonc"

          cp --reflink=never "${modelsJsonFile}" "$agent_dir/models.json"
          chmod 600 "$agent_dir/models.json"

          cp --reflink=never "${permissionsPolicyFile}" "$agent_dir/pi-permissions.jsonc"
          chmod 600 "$agent_dir/pi-permissions.jsonc"

          cp --reflink=never "${keybindingsJsonFile}" "$agent_dir/keybindings.json"
          chmod 600 "$agent_dir/keybindings.json"

          cp --reflink=never "${appendSystemFile}" "$agent_dir/APPEND_SYSTEM.md"
          chmod 644 "$agent_dir/APPEND_SYSTEM.md"

          mkdir -p "$agent_dir/extensions"
          rm -f "$agent_dir/extensions/checkpoint-nudge.ts"
          rm -rf "$agent_dir/self-compact"
          rm -f "$agent_dir/extensions/scout.ts"
          cp --reflink=never "${researchFile}" "$agent_dir/extensions/research.ts"
          chmod 644 "$agent_dir/extensions/research.ts"
          rm -f "$agent_dir/extensions/thinking-auto.ts" "$agent_dir/thinking-auto.json"
          cp --reflink=never "${proteiAutoFile}" "$agent_dir/extensions/protei-auto.ts"
          chmod 644 "$agent_dir/extensions/protei-auto.ts"

          for ext in damage-control tool-counter session-replay; do
            cp --reflink=never "${piVsCcExtensions}/$ext.ts" "$agent_dir/extensions/$ext.ts"
            chmod 644 "$agent_dir/extensions/$ext.ts"
          done
          cp --reflink=never "${fffJsonFile}" "$agent_dir/extensions/pi-fff.json"
          chmod 644 "$agent_dir/extensions/pi-fff.json"
          cp --reflink=never "${todoReminderFile}" "$agent_dir/extensions/todo-reminder.ts"
          chmod 644 "$agent_dir/extensions/todo-reminder.ts"
          cp --reflink=never "${contextKeeperFile}" "$agent_dir/extensions/context-keeper.ts"
          chmod 644 "$agent_dir/extensions/context-keeper.ts"
          cp --reflink=never "${subagentFile}" "$agent_dir/extensions/subagent.ts"
          chmod 644 "$agent_dir/extensions/subagent.ts"
          cp --reflink=never "${gatesFile}" "$agent_dir/extensions/gates.ts"
          chmod 644 "$agent_dir/extensions/gates.ts"
          cp --reflink=never "${harnessToolsFile}" "$agent_dir/extensions/tools.ts"
          chmod 644 "$agent_dir/extensions/tools.ts"
          cp --reflink=never "${pipelineFile}" "$agent_dir/extensions/pipeline.ts"
          chmod 644 "$agent_dir/extensions/pipeline.ts"
          rm -f "$agent_dir/extensions/grill-hint.ts"
          cp --reflink=never "${nvimFile}" "$agent_dir/extensions/nvim.ts"
          chmod 644 "$agent_dir/extensions/nvim.ts"
          cp --reflink=never "${piReview}/review.ts" "$agent_dir/extensions/review.ts"
          chmod 644 "$agent_dir/extensions/review.ts"
          cp --reflink=never "${piVsCcExtensions}/damage-control-rules.json" "${config.home.homeDirectory}/.pi/damage-control-rules.json"
          chmod 644 "${config.home.homeDirectory}/.pi/damage-control-rules.json"

          cp --reflink=never "${mcpJsonFile}" "$agent_dir/mcp.json"
          chmod 600 "$agent_dir/mcp.json"

          if [[ -f "$agent_dir/settings.json" ]]; then
            "${lib.getExe pkgs.jq}" --slurpfile seed "${settingsSeedFile}" '. * $seed[0]' \
              "$agent_dir/settings.json" > "$agent_dir/settings.json.tmp" \
              && mv "$agent_dir/settings.json.tmp" "$agent_dir/settings.json"
          else
            cp --reflink=never "${settingsSeedFile}" "$agent_dir/settings.json"
            chmod 644 "$agent_dir/settings.json"
          fi

          npm_dir="$agent_dir/npm"
          wanted=(${lib.escapeShellArgs (map (lib.removePrefix "npm:") (lib.filter (lib.hasPrefix "npm:") settingsSeed.packages))})
          export PATH="${
            lib.makeBinPath [
              pkgs.nodejs
              pkgs.git
              pkgs.coreutils
            ]
          }:$PATH"

          if [[ -f "$npm_dir/package.json" ]]; then
            while read -r dep; do
              if ! printf '%s\n' "''${wanted[@]}" | grep -qxF -- "$dep"; then
                log "Removing $dep"
                npm --prefix "$npm_dir" uninstall "$dep" --legacy-peer-deps >/dev/null 2>&1 \
                  || log "WARNING: npm uninstall $dep failed"
              fi
            done < <("${lib.getExe pkgs.jq}" -r '.dependencies // {} | keys[]' "$npm_dir/package.json")
          fi

          declare -A pins=(${
            lib.concatStrings (
              lib.mapAttrsToList (
                name: version: " [${lib.escapeShellArg name}]=${lib.escapeShellArg version}"
              ) npmPins
            )
          } )

          for dep in "''${wanted[@]}"; do
            pin="''${pins[$dep]:-}"
            have="$("${lib.getExe pkgs.jq}" -r '.version // empty' "$npm_dir/node_modules/$dep/package.json" 2>/dev/null || true)"
            if [[ ! -d "$npm_dir/node_modules/$dep" || ( -n "$pin" && "$have" != "$pin" ) ]]; then
              log "Installing $dep''${pin:+@$pin}"
              "${pkgs.coreutils}/bin/timeout" 180s npm --prefix "$npm_dir" install "$dep''${pin:+@$pin}" --legacy-peer-deps >/dev/null 2>&1 \
                || log "WARNING: npm install $dep failed (no network?)"
            fi
          done

          if DISABLE_TELEMETRY=1 DO_NOT_TRACK=1 "${pkgs.coreutils}/bin/timeout" 300s \
            npx -y skills@latest add mattpocock/skills -g -a pi -y --copy -s ${lib.escapeShellArgs mattpocockSkills} >/dev/null 2>&1; then
            log "Updated mattpocock/skills in ${agentSkillsDir}"
          else
            log "WARNING: npx skills add mattpocock/skills failed (no network?), keeping the installed copies"
          fi
          for skill in ${lib.escapeShellArgs mattpocockSkills}; do
            skill_md="${agentSkillsDir}/$skill/SKILL.md"
            if [[ ! -f "$skill_md" ]]; then
              log "WARNING: skill $skill is not installed"
              continue
            fi
            ${pkgs.gnused}/bin/sed -i -E \
              -e 's/Call the Skill tool twice, for ["`]([a-z0-9-]+)["`] and ["`]([a-z0-9-]+)["`]/Read the skills \1 and \2 (their SKILL.md files are listed in your available skills)/g' \
              -e 's/call the Skill tool twice, for ["`]([a-z0-9-]+)["`] and ["`]([a-z0-9-]+)["`]/read the skills \1 and \2 (their SKILL.md files are listed in your available skills)/g' \
              -e 's/Call the Skill tool (with|for) ["`]([a-z0-9-]+)["`]/Read the skill \2 (its SKILL.md is listed in your available skills)/g' \
              -e 's/call the Skill tool (with|for) ["`]([a-z0-9-]+)["`]/read the skill \2 (its SKILL.md is listed in your available skills)/g' \
              -e 's/should call the Skill tool for/should read (each SKILL.md is listed in the available skills)/g' \
              "$skill_md"
            if grep -q "Skill tool" "$skill_md"; then
              log "WARNING: $skill/SKILL.md still mentions the Skill tool"
            fi
          done

          perm="$npm_dir/node_modules/pi-permission-system/src/index.ts"
          if [[ -f "$perm" ]]; then
            ${pkgs.gnused}/bin/sed -i \
              's/const allTools = pi.getAllTools();/const allTools = pi.getAllTools().filter((tool) => pi.getActiveTools().includes(getEventToolName(tool) ?? ""));/' \
              "$perm"
          fi

          fff_dir="$npm_dir/node_modules/pi-fff/src"
          if [[ -f "$fff_dir/fff-runtime.ts" ]] && ! grep -qF 'async searchPathCandidates' "$fff_dir/fff-runtime.ts"; then
            ${pkgs.gnused}/bin/sed -i \
              's|^\tasync findFiles(request: FindFilesRequest): Promise<FindFilesResult> {$|\tasync searchPathCandidates(query: string, limit = DEFAULT_FILE_CANDIDATE_LIMIT): Promise<AppResult<FffFileCandidate[], RuntimeInitializationError \| FinderOperationError>> { const finderResult = await this.ensure(); if (finderResult.isErr()) return propagateError(finderResult); const normalizedQuery = normalizePathQuery(query); if (!normalizedQuery) return Result.ok([]); const search = safeFinderCall("mixedSearch", () => finderResult.value.mixedSearch(normalizedQuery, { pageSize: Math.max(limit, DEFAULT_FILE_CANDIDATE_LIMIT) })); if (search.isErr()) return propagateError(search); return Result.ok(search.value.items.slice(0, limit).map((entry, index) => normalizeCandidate(entry.item as FileItem, search.value.scores[index]))); }\n\n&|' \
              "$fff_dir/fff-runtime.ts"
          fi
          if [[ -f "$fff_dir/editor.ts" ]] && grep -qF 'async searchPathCandidates' "$fff_dir/fff-runtime.ts" && ! grep -qF 'searchPathCandidates' "$fff_dir/editor.ts"; then
            ${pkgs.gnused}/bin/sed -i \
              's|this.runtime.searchFileCandidates(rawQuery, MAX_RESULTS)|this.runtime.searchPathCandidates(rawQuery, MAX_RESULTS)|' \
              "$fff_dir/editor.ts"
          fi
          if [[ -f "$fff_dir/editor.ts" ]] && ! grep -qF 'searchPathCandidates' "$fff_dir/editor.ts"; then
            log "WARNING: pi-fff directory autocomplete patch did not apply"
          fi

          lsp_ext="$npm_dir/node_modules/pi-lsp-extension/dist/index.js"
          if [[ -f "$lsp_ext" ]] && ! grep -qF '".nix": "nix"' "$lsp_ext"; then
            ${pkgs.gnused}/bin/sed -i \
              -e 's/^  "\.php": "php"$/  ".php": "php",\n  ".nix": "nix"/' \
              -e 's/^  java: { command: "jdtls", args: \[\] }$/  java: { command: "jdtls", args: [] },\n  nix: { command: "nixd", args: [] }/' \
              "$lsp_ext"
            grep -qF 'nix: { command: "nixd"' "$lsp_ext" || log "WARNING: pi-lsp-extension nix patch did not apply"
          fi

          if [[ -f "$lsp_ext" ]] && ! grep -qF 'existsSync3(join2(dir, marker))' "$lsp_ext"; then
            ${pkgs.gnused}/bin/sed -i \
              -e 's|^    if (!existsSync3(configPath)) return null;$|    if (!existsSync3(configPath)) { const autoStart = [...new Set([["go.mod", "go"], ["Cargo.toml", "rust"], ["flake.nix", "nix"], ["default.nix", "nix"], ["shell.nix", "nix"], ["tsconfig.json", "typescript"], ["package.json", "typescript"], ["pyproject.toml", "python"], ["setup.py", "python"], ["requirements.txt", "python"]].filter(([marker]) => existsSync3(join2(dir, marker))).map(([, lang]) => lang))]; return autoStart.length > 0 ? { autoStart } : null; }|' \
              "$lsp_ext"
            grep -qF 'existsSync3(join2(dir, marker))' "$lsp_ext" || log "WARNING: pi-lsp-extension autoStart patch did not apply"
          fi

          log "pi setup complete"
        '';
      };
    };
}
