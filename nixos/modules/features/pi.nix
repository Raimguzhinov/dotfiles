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

      piAgentDir = "${config.home.homeDirectory}/.pi/agent";

      grillMePackage = "npm:@majorgilles/pi-grill-me";

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
                contextWindow = 231072;
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
          "grill_*" = "allow";
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

      piPlan =
        pkgs.runCommand "pi-plan"
          {
            src = pkgs.fetchurl {
              url = "https://registry.npmjs.org/pi-plan/-/pi-plan-0.1.1.tgz";
              hash = "sha256-aLu4Q64abvDSsa0w/041DG40eHuuuJH/eE9/CAwcT2o=";
            };
          }
          /* bash */ ''
            mkdir -p "$out"
            tar xzf "$src" -C "$out" --strip-components=1
            substituteInPlace "$out/extensions/plan/index.ts" \
              --replace-fail 'const NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write"];' "" \
              --replace-fail 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls"];' 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls", "todo", "lsp_definition", "lsp_references", "lsp_hover", "lsp_diagnostics", "aft_outline", "aft_zoom", "aft_search", "query-docs", "resolve-library-id"];' \
              --replace-fail '- You can only use: read, bash, grep, find, ls' '- You can only use: read, bash, grep, find, ls, todo, lsp_definition, lsp_references, lsp_hover, lsp_diagnostics, aft_outline, aft_zoom, aft_search, query-docs, resolve-library-id' \
              --replace-fail 'pi.setActiveTools(PLAN_MODE_TOOLS);' "" \
              --replace-fail 'pi.setActiveTools(NORMAL_MODE_TOOLS);' 'if (!pi.getActiveTools().includes("edit")) pi.setActiveTools(pi.getAllTools().filter((t) => !t.exposure || t.exposure === "direct" || t.exposure === "model-only").map((t) => t.name));' \
              --replace-fail 'if (event.toolName === "write" || event.toolName === "edit") {' 'if (!PLAN_MODE_TOOLS.includes(event.toolName) && event.toolName !== "mcp" && !event.toolName.startsWith("mcp__")) {' \
              --replace-fail '"Plan mode active. File modifications blocked. Use /plan to disable."' '`Plan mode active. Only ''${PLAN_MODE_TOOLS.join(", ")} are allowed, file modifications are blocked. Use /plan to disable.`' \
              --replace-fail 'ctx.ui.theme.muted(' 'ctx.ui.theme.fg("muted", ' \
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

      researchFile = pkgs.writeText "research.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

        const RESEARCH_TOOLS = ["read", "bash", "grep", "find", "ls", "lsp_definition", "lsp_references", "lsp_hover", "lsp_diagnostics", "aft_outline", "aft_zoom", "aft_search", "resolve-library-id", "query-docs", "codemode", "todo"];

        const researchPrompt = (topic: string) => `Research the topic below before any planning. Do not modify anything.

        Topic: ''${topic}

        1. Decide which sources the topic needs: this codebase, library or API docs, the web, GitLab projects, merge requests and pipelines, the team knowledge base, issues. Use only the ones that matter.
        2. Codebase: locate the code with aft_search, aft_outline and LSP references or definitions, read only the line ranges you need, note existing patterns and how this area is verified today.
        3. Libraries and APIs: check the current docs with context7. Web, GitLab, knowledge base and issues: use the matching MCP tools you have.
        4. Prefer primary sources. Cross-check every claim the result depends on. Mark what you could not confirm.

        Reply with a "## Research" report of at most 60 lines:
        - Question: what was researched, in one line
        - Findings: each with its source (path:line or URL)
        - Options and trade-offs, if there is a choice to make
        - Recommendation
        - Deliverable: what the result should be (code change, tests, report, OpenAPI/Swagger spec, diagram, table, ADR or another artifact) and why
        - Open questions
        Do not plan or propose changes yet.`;

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
          reserveTokens: ${toString settingsSeed.compaction.reserveTokens},
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
                const big = contextTokens(request.messages) > Math.min(find("main").contextWindow, find("small").contextWindow) - CFG.reserveTokens;
                const key = request.previous && keyOf(request.previous.model);
                const next: Target = key ? (big && key !== "strict" ? "strict" : key) : big || planMode(ctx) === "plan" ? "strict" : pool;
                return { model: find(next), thinkingLevel: request.thinkingLevel };
              }
              review = reviewActive(ctx, request.messages);
              const sticky = request.reason === "retry" ? request.failed : request.reason === "user" ? undefined : request.previous;
              const stickyKey = sticky && keyOf(sticky.model);
              const stickyLevel = sticky?.thinkingLevel;
              const forced: ModelThinkingLevel = "high";
              const limit = Math.min(find("main").contextWindow, find("small").contextWindow) - CFG.reserveTokens;
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
                if (swap || leavePlan) choosePool(now);
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
              choosePool(now);
              retarget(big || planMode(ctx) === "plan" ? "strict" : pool);
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
            if (msg.provider !== "ProteiStrict" && wall > 0 && (tokens >= CFG.minTokens || wall >= CFG.slowWallMs)) poolSample(msg.model, tokens / (busy / 1000));
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

      grillHintFile = pkgs.writeText "grill-hint.ts" /* typescript */ ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

        export default function (pi: ExtensionAPI) {
          if (process.argv.some((arg) => arg.includes("pi-grill-me"))) return;
          pi.registerCommand("grill", {
            description: "grill-me загружается только через алиас pig",
            handler: async (_args, ctx) => {
              ctx.ui.notify("grill-me в этой сессии не загружен. Выйди из pi, запусти pig и повтори /grill", "warning");
            },
          });
        }
      '';

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
        import { mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { homedir, tmpdir } from "node:os";
        import { join, resolve } from "node:path";

        type Agent = { name: string; description: string; tools?: string; model?: string; thinking?: string; body: string };
        type Answer = { answer: string; stopReason?: string; usage?: unknown };
        type Herdr = { ok: true; result: any } | { ok: false; code: string; message: string };
        type Job = {
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
        };

        const DIR = join(process.env.XDG_RUNTIME_DIR || tmpdir(), "pi-herdr");
        const AGENTS = join(process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent"), "agents");
        const TICK_MS = 5000;
        const CAP = 4000;

        const head = (s: string, n = 30) => {
          const t = s.replace(/\s+/g, " ").trim();
          return t.length > n ? t.slice(0, n - 1) + "…" : t;
        };

        const file = (run: string, ext: string) => join(DIR, run + ext);

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

        const childEnv = (job: Job) => ({ PI_HERDR_DEPTH: "1", PI_HERDR_RUN: job.run });

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
              const p = await herdr(["agent", "prompt", name, "--wait", "--until", "idle", "--until", "done", "--until", "blocked", "--timeout", String(left()), "--", job.task], sig);
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
          `Agents: ''${[...agents.values()].map((a) => (a.description ? `''${a.name} (''${a.description})` : a.name)).join(", ") || "none"}.`;

        export default function (pi: ExtensionAPI) {
          if (process.env.PI_HERDR_DEPTH) return childMode(pi);
          const agents = loadAgents();
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
            }),
            async execute(_id, params, signal, onUpdate, ctx) {
              const outer = signal ?? new AbortController().signal;
              const timeoutMs = Math.max(1, params.timeoutMin ?? 30) * 60000;
              const notify = (msg: string) => {
                if (ctx.hasUI) ctx.ui.notify(msg, "warning");
                onUpdate?.({ content: [{ type: "text", text: msg }], details: { jobs } });
              };
              let ws = process.env.HERDR_ENV === "1" ? process.env.HERDR_WORKSPACE_ID : undefined;
              if (process.env.HERDR_ENV === "1" && !ws && process.env.HERDR_PANE_ID) {
                const p = await herdr(["pane", "get", process.env.HERDR_PANE_ID], outer);
                if (p.ok) ws = p.result.pane?.workspace_id;
              }
              const jobs: Job[] = params.tasks.map((t) => ({
                agent: t.agent || "scout",
                task: t.task,
                cwd: resolve(ctx.cwd, t.cwd || "."),
                run: randomUUID(),
                sessionId: randomUUID(),
                status: "queued",
              }));
              const runOne = async (job: Job) => {
                const agent = agents.get(job.agent);
                if (!agent) return Object.assign(job, { ok: false, error: `unknown agent, available: ''${[...agents.keys()].join(", ") || "none"}` });
                try {
                  const args = childArgs(agent, job);
                  job.progress = undefined;
                  if (ws) await viaHerdr(job, args, ws, outer, timeoutMs, notify);
                  else await viaPrint(job, args, outer, timeoutMs);
                } catch (e) {
                  Object.assign(job, { ok: false, error: String(e) });
                } finally {
                  job.status = job.ok ? "done" : "failed";
                  for (const ext of [".json", ".progress", ".md"]) rmSync(file(job.run, ext), { force: true });
                }
              };
              const tick = () => {
                for (const j of jobs) if (ws && j.status !== "done" && j.status !== "failed") j.progress = readText(file(j.run, ".progress")) ?? j.progress;
                const text = jobs.map((j) => `''${j.agent}: ''${head(j.task)} [''${j.status}''${j.progress ? `, ''${j.progress}` : ""}]`).join("\n");
                onUpdate?.({ content: [{ type: "text", text }], details: { jobs } });
              };
              const timer = setInterval(tick, TICK_MS);
              try {
                const queue = [...jobs];
                const limit = Math.max(1, Number(process.env.PI_SUBAGENT_CONCURRENCY) || 2);
                await Promise.all(
                  Array.from({ length: Math.min(limit, jobs.length) }, async () => {
                    for (let job = queue.shift(); job; job = queue.shift()) await runOne(job);
                  }),
                );
              } finally {
                clearInterval(timer);
              }
              const text = jobs
                .map((j) => {
                  const body = j.ok
                    ? (j.answer ?? "").length > CAP
                      ? `''${j.answer!.slice(0, CAP)}\n[answer truncated at ''${CAP} chars]`
                      : j.answer
                    : `No answer: ''${j.error}.''${j.tab ? ` Tab "''${j.tab}" (pane ''${j.pane}) is kept open.` : ""}`;
                  return `### ''${j.agent}: ''${head(j.task)}\n''${body}\nsession: ''${j.sessionId}`;
                })
                .join("\n\n");
              return { content: [{ type: "text", text }], details: { jobs }, isError: jobs.every((j) => !j.ok) };
            },
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
        - Almost never write comments in code, including godoc and other doc comments on functions, types and packages.
        - Write a comment only when the code cannot explain itself:
          - a workaround for a bug in a library, tool or upstream service
          - an order of operations, locking or concurrency rule that breaks if changed
          - a magic value imposed by a protocol, hardware or external API
          - code that looks dead, wrong or redundant but is intentional
          - a non-obvious side effect or performance trick
        - Never repeat what the code, names or types already say.
        - Format: one short sentence in Russian, no period at the end, no dashes, no ";".
        - Put it at the end of the code line. Only if it does not fit, put it on the line above.

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
          (pkgs.callPackage mkPiAcp { })
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

        programs.zsh.shellAliases.pig = "pi -e ${piAgentDir}/npm/node_modules/${lib.removePrefix "npm:" grillMePackage}";

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
          cp --reflink=never "${grillHintFile}" "$agent_dir/extensions/grill-hint.ts"
          chmod 644 "$agent_dir/extensions/grill-hint.ts"
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
          wanted=(${
            lib.escapeShellArgs (
              map (lib.removePrefix "npm:") (
                lib.filter (lib.hasPrefix "npm:") (settingsSeed.packages ++ [ grillMePackage ])
              )
            )
          })
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
