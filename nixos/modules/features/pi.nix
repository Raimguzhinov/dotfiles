{ ... }:
let
  searxPort = 8899;

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
    {
      lib,
      pkgs,
      ...
    }:

    let
      searxSecretFile = "/var/lib/searx-secret/env";
    in
    {
      config = {
        programs.nix-ld.enable = true;

        systemd.services.searx-secret = {
          requiredBy = [
            "searx-init.service"
            "searx.service"
          ];
          before = [
            "searx-init.service"
            "searx.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StateDirectory = "searx-secret";
            StateDirectoryMode = "0700";
            UMask = "0077";
          };
          script = /* bash */ ''
            if [[ ! -s ${searxSecretFile} ]]; then
              printf 'SEARXNG_SECRET=%s\n' \
                "$(${lib.getExe pkgs.openssl} rand -hex 32)" > ${searxSecretFile}
            fi
          '';
        };

        services.searx = {
          enable = true;
          domain = "localhost";
          environmentFile = searxSecretFile;
          settings = {
            server = {
              port = searxPort;
              bind_address = "127.0.0.1";
              secret_key = "$SEARXNG_SECRET";
            };
            search.formats = [
              "html"
              "json"
            ];
            # Эти движки captcha-блокируют/тихо отдают decoy с домашнего IP
            # (journalctl -u searx.service); mcp-searxng может явно запросить
            # их через engines=, так что одного disabled: true недостаточно.
            use_default_settings.engines.remove = [
              "google"
              "startpage"
              "duckduckgo"
              "brave"
              # brave.images/videos/news ссылаются на network: brave —
              # без базового движка searxng падает с KeyError на старте
              "brave.images"
              "brave.videos"
              "brave.news"
              "mojeek"
              "bing"
            ];
            # yandex по умолчанию выключен (disabled: true) — единственный
            # оставшийся общий web-движок, не пойманный на бане с этого IP.
            engines = [
              {
                name = "yandex";
                disabled = false;
              }
            ];
          };
        };
      };
    };

  flake.homeModules.pi =
    {
      config,
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

      modelsConfig = {
        providers.Protei = {
          baseUrl = "https://agent.ai.protei.ru/api";
          api = "openai-completions";
          apiKey = readSecret "work_ai/litellm_api_key";
          models = [
            {
              id = "agent_proteya";
              name = "Protei Coding";
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
              thinkingLevelMap = {
                off = "none";
                minimal = null;
                low = "low";
                medium = "medium";
                high = null;
                xhigh = "xhigh";
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
            }
          ];
        };
      };

      mcpConfig = {
        mcpServers = {
          youtrack = {
            description = "Protei YouTrack: search and read issues";
            url = "https://youtrackmcp.ai.protei.ru/mcp";
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
            env.SEARXNG_URL = "http://127.0.0.1:${toString searxPort}";
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
          uc-dev = {
            command = "uc-dev";
            args = [ "mcp" ];
            env.UC_DEV_CORE = "${config.home.homeDirectory}/Work/core";
          };
        };
      };

      settingsSeed = {
        defaultProvider = "Protei";
        defaultModel = "agent_proteya";
        theme = "dark";
        defaultThinkingLevel = "low";
        defaultTools = [ "-powershell" ];
        thinkingBudgets = {
          low = 2048;
          medium = 4096;
          high = 6144;
        };
        compaction = {
          reserveTokens = 32768;
          keepRecentTokens = 20000;
        };
        extensions = [ "self-compact/extensions/self-compact/self-compact.ts" ];
        packages = [
          "npm:@cortexkit/aft-pi"
          "npm:@upstash/context7-pi"
          "npm:@juicesharp/rpiv-todo"
          "npm:pi-cache-optimizer"
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
          self_compact = "allow";
          view_context = "allow";
          codemode = "allow";
          "mcp__*" = "allow";
        };
      };

      keybindingsOverrides = {
        "app.thinking.cycle" = "alt+t";
      };

      aftConfig = {
        format_on_edit = true;
        edit_mode = "hashline";
        bash.background = false;
        disabled_tools = [
          "aft_inspect"
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
              --replace-fail 'let tokIn = 0;' 'let tokIn = 0; let tokCache = 0;' \
              --replace-fail 'tokIn += m.usage.input;' 'tokIn += m.usage.input; tokCache += m.usage.cacheRead ?? 0;' \
              --replace-fail 'theme.fg("dim", " in ") +' 'theme.fg("dim", " in ") + theme.fg("success", `''${fmt(tokCache)}`) + theme.fg("dim", " cached ") +' \
              --replace-fail 'const l1Left =' 'const sc = footerData.getExtensionStatuses().get("self-compact"); const l1Left = sc ? theme.fg("dim", ` ''${model} `) + sc :' \
              --replace-fail 'return [line1, line2];' 'const statuses = [...footerData.getExtensionStatuses()].filter(([key, value]) => key !== "self-compact" && value).map(([, value]) => value).join(theme.fg("dim", " · ")); return statuses ? [line1, line2, truncateToWidth(" " + statuses, width, "")] : [line1, line2];'
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
              --replace-fail 'const NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write"];' 'let NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write"];' \
              --replace-fail 'pi.setActiveTools(PLAN_MODE_TOOLS);' 'if (pi.getActiveTools().includes("edit")) NORMAL_MODE_TOOLS = pi.getActiveTools(); pi.setActiveTools(PLAN_MODE_TOOLS);' \
              --replace-fail 'ctx.ui.theme.muted(' 'ctx.ui.theme.fg("muted", ' \
              --replace-fail '`Execute the plan. Start with: ''${steps[0].text}`' '`Execute the plan. Start with: ''${steps[0].text}\nAfter completing a step, include a [DONE:n] tag in your response.`'
          '';

      scoutFile = pkgs.writeText "scout.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

        const SCOUT_TOOLS = ["read", "bash", "grep", "find", "ls", "aft_outline", "aft_zoom", "aft_search", "resolve-library-id", "query-docs", "codemode"];

        const scoutPrompt = (task: string) => `Scout the codebase for the task below before any planning. Do not modify anything.

        Task: ''${task}

        1. Locate the code the task touches: entry points, key types and functions, callers, data flow. Read only the line ranges you need.
        2. Find existing patterns to copy and the tests that cover this area, with the exact command that runs them.
        3. If the task uses external libraries, check their current API with context7.

        Reply with a "## Scout" report of at most 40 lines:
        - Entry points: path:line
        - Relevant code: path:lines, why it matters
        - Patterns to follow
        - Tests: files and the run command
        - Risks and open questions
        Do not plan or propose changes yet.`;

        const planPrompt = (task: string) => `Using the scout report above, plan: ''${task}

        Plan test-first. For every behavior change, one step writes a failing test and the next step makes it pass. Put the exact test command in the steps. For a step that cannot be tested (config, docs, wiring), say how it will be verified instead.`;

        const TDD =
          "[TDD] For each plan step: write or extend the test first, run it and confirm it fails for the expected reason, " +
          "then write the minimal code that makes it pass and run it again, then refactor with the tests green. " +
          "Never weaken a test to make it pass. Show the failing and the passing run.";

        type Entry = { type: string; customType?: string; data?: { mode?: string } };

        const planEntries = (ctx: ExtensionContext) =>
          (ctx.sessionManager.getBranch() as Entry[]).filter(
            (e) => e.type === "custom" && (e.customType === "pi-plan" || e.customType === "scout"),
          );

        const planMode = (ctx: ExtensionContext) =>
          planEntries(ctx).findLast((e) => e.customType === "pi-plan")?.data?.mode ?? "normal";

        const scouted = (ctx: ExtensionContext) => {
          for (const e of planEntries(ctx).reverse()) {
            if (e.customType === "scout") return true;
            if (e.data?.mode === "normal") return false;
          }
          return false;
        };

        export default function (pi: ExtensionAPI) {
          let task: string | undefined;
          let inPlan = false;
          let restore: string[] = [];
          let ok = false;

          pi.registerCommand("scout", {
            description: "Scout the code for a task, then plan it test-first in /plan",
            handler: async (args, ctx) => {
              const text = args.trim();
              if (!text) return ctx.ui.notify("Usage: /scout <task>", "warning");
              if (!ctx.isIdle()) return ctx.ui.notify("Wait for the agent to finish", "warning");
              const mode = planMode(ctx);
              if (mode === "execute") return ctx.ui.notify("A plan is executing", "warning");
              task = text;
              inPlan = mode === "plan";
              pi.appendEntry("scout", { task });
              if (!inPlan) {
                restore = pi.getActiveTools();
                const known = new Set(pi.getAllTools().map((t) => t.name));
                pi.setActiveTools(SCOUT_TOOLS.filter((n) => known.has(n)));
              }
              pi.sendUserMessage(scoutPrompt(text));
            },
          });

          pi.on("agent_end", (event) => {
            if (!task) return;
            const last = event.messages.findLast((m) => m.role === "assistant") as { stopReason?: string } | undefined;
            ok = !!last && last.stopReason !== "aborted" && last.stopReason !== "error";
          });

          pi.on("agent_settled", () => {
            if (!task) return;
            const t = task;
            task = undefined;
            if (restore.length > 0) pi.setActiveTools(restore);
            restore = [];
            if (!ok) return;
            if (!inPlan) pi.sendUserMessage("/plan", { expandPromptTemplates: true });
            pi.sendUserMessage(planPrompt(t));
          });

          pi.on("context", (event, ctx) => {
            if (planMode(ctx) !== "execute" || !scouted(ctx)) return;
            const i = event.messages.findLastIndex((m) => (m as { customType?: string }).customType === "pi-plan-execute");
            if (i < 0) return;
            const messages = [...event.messages];
            messages.splice(i + 1, 0, { ...messages[i], customType: "scout-tdd", content: TDD } as (typeof messages)[number]);
            return { messages };
          });
        }
      '';

      piReview = pkgs.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi-review";
        rev = "f1de050504936046c0f85b21fec0e0a93ef394eb";
        hash = "sha256-bvdJjLudTd9YQF8ip30jIvi6MY3MAcw5GXVONx1DLuQ=";
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

      selfCompact =
        pkgs.runCommand "pi-self-compact"
          {
            src = pkgs.fetchFromGitHub {
              owner = "disler";
              repo = "self-compact-pi-agent";
              rev = "576fe4abda021849f5cde5b6f5796467ffa4bcbd";
              hash = "sha256-AFx6WLMbSsWyFoJV9vVVya+8Q+e+xE56uBzeL3KzmbE=";
            };
          }
          /* bash */ ''
            app="$src/apps/self-compact"
            mkdir -p "$out/extensions/self-compact" "$out/.pi"
            cp -r "$app/.pi/self-compact" "$out/.pi/"
            cp "$app"/extensions/self-compact/*.ts "$out/extensions/self-compact/"
            chmod -R u+w "$out"
            cd "$out/extensions/self-compact"
            substituteInPlace defaults.ts \
              --replace-fail '{ softAt: "10%", at: "20%", buffer: "10%" }' '{ softAt: "60000", at: "80000", buffer: "15000" }'
            substituteInPlace self-compact.ts \
              --replace-fail 'installFooter(ctx);' "" \
              --replace-fail 'if (ctx.mode === "tui") R.requestRender?.();' "" \
              --replace-fail 'else if (ctx.hasUI) ctx.ui.setStatus("self-compact"' 'if (ctx.hasUI) ctx.ui.setStatus("self-compact"'
            substituteInPlace summary.ts \
              --replace-fail 'instructions: string, budgetChars: number) {' 'instructions: string, budgetChars: number, system: string) {' \
              --replace-fail 'const messages = context.messages.map(message => {' 'const messages = context.messages.map((message, index) => { if (message.role === "system" && index === 0) return { ...message, content: system };' \
              --replace-fail 'historyInput(event.preparation.turnPrefixMessages)].sort(' 'historyInput(event.preparation.turnPrefixMessages), `# Conversation\n''${serializeConversation(convertToLlm(event.preparation.turnPrefixMessages))}\n\n# Instructions\n`].sort(' \
              --replace-fail 'replaceInstructions(context, inputs, userInstructions, budgetChars);' 'replaceInstructions(context, inputs, userInstructions, budgetChars, system.text);'
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

        ## Workflow for code tasks
        Work autonomously until the task is done or you are blocked.
        1. Locate: find the relevant code with grep, aft_search, aft_outline or aft_zoom. Read only the line ranges you need. Never guess file contents, APIs or paths.
        2. Plan: if the change touches more than one file, first write a numbered plan of at most 5 steps.
        3. Edit: make one small change at a time. Match the existing style. Do not add files, dependencies or refactors that were not asked for.
        4. Verify: after editing, run the narrowest build, test or lint command. On failure, read the error, fix it and re-run. After 3 failed attempts, stop and report.
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
      config = {

        home.packages = [
          pkgs-unstable.pi-coding-agent
          (pkgs.callPackage mkPiAcp { })
        ];

        # Не ходить на pi.dev при старте: version check, remote model catalog, install telemetry
        home.sessionVariables = {
          PI_OFFLINE = "1";
          LLAMA_BASE_URL = "http://127.0.0.1:8085";
        };

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
          cp -r --no-preserve=mode "${selfCompact}" "$agent_dir/self-compact"
          cp --reflink=never "${scoutFile}" "$agent_dir/extensions/scout.ts"
          chmod 644 "$agent_dir/extensions/scout.ts"

          for ext in damage-control tool-counter session-replay; do
            cp --reflink=never "${piVsCcExtensions}/$ext.ts" "$agent_dir/extensions/$ext.ts"
            chmod 644 "$agent_dir/extensions/$ext.ts"
          done
          cp --reflink=never "${grillHintFile}" "$agent_dir/extensions/grill-hint.ts"
          chmod 644 "$agent_dir/extensions/grill-hint.ts"
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

          for dep in "''${wanted[@]}"; do
            if [[ ! -d "$npm_dir/node_modules/$dep" ]]; then
              log "Installing $dep"
              "${pkgs.coreutils}/bin/timeout" 180s npm --prefix "$npm_dir" install "$dep" --legacy-peer-deps >/dev/null 2>&1 \
                || log "WARNING: npm install $dep failed (no network?)"
            fi
          done

          log "pi setup complete"
        '';
      };
    };
}
