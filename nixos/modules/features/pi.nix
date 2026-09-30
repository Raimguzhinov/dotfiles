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
        settings.namespaceProxyTools = false;
        mcpServers = {
          youtrack = {
            url = "https://youtrackmcp.ai.protei.ru/mcp";
            headers."youtrack-token" = readSecret "youtrack/token";
          };
          gitlab = {
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
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:${toString searxPort}";
          };
          postgres = {
            command = "npx";
            args = [
              "-y"
              "@modelcontextprotocol/server-postgres"
              "postgresql://uc:ucPassword@localhost:5432/uc?sslmode=disable&options=-csearch_path%3Dcompany_0%2Cpublic"
            ];
          };
          gh_grep = {
            url = "https://mcp.grep.app";
            auth = false;
          };
          codebase_memory = {
            command = "npx";
            args = [
              "-y"
              "codebase-memory-mcp"
            ];
            env = {
              CBM_ALLOWED_ROOT = config.home.homeDirectory;
            };
          };
        };
      };

      settingsSeed = {
        defaultProvider = "Protei";
        defaultModel = "agent_proteya";
        theme = "dark";
        defaultThinkingLevel = "low";
        thinkingBudgets = {
          low = 2048;
          medium = 4096;
          high = 6144;
        };
        compaction = {
          reserveTokens = 32768;
          keepRecentTokens = 20000;
        };
        packages = [
          "npm:@cortexkit/aft-pi"
          "npm:@upstash/context7-pi"
          "npm:pi-llama-cpp"
          "npm:@juicesharp/rpiv-todo"
          "npm:pi-cache-optimizer"
          "npm:pi-checkpoint-compaction"
          "npm:pi-mcp-adapter"
          "npm:pi-permission-system"
          "${piPlan}"
          "npm:pi-undo-redo"
        ];

        llamaSettings = {
          servers = [
            {
              url = "http://127.0.0.1:8085";
              id = "llama-local";
              name = "Local";
            }
          ];
          reactToModelSelect = true;
          autoloadOnMessage = true;
          sortBy = "asc";
          pollingTimeout = 120000;
          serverTimeout = 2000;
        };
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
          checkpoint_update = "allow";
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
              --replace-fail 'damage-control-rules.yaml' 'damage-control-rules.json'
            substitute "$src/extensions/tool-counter.ts" "$out/tool-counter.ts" \
              --replace-fail 'import { applyExtensionDefaults } from "./themeMap.ts";' "" \
              --replace-fail 'applyExtensionDefaults(import.meta.url, ctx);' "" \
              --replace-fail 'let tokIn = 0;' 'let tokIn = 0; let tokCache = 0;' \
              --replace-fail 'tokIn += m.usage.input;' 'tokIn += m.usage.input; tokCache += m.usage.cacheRead ?? 0;' \
              --replace-fail 'theme.fg("dim", " in ") +' 'theme.fg("dim", " in ") + theme.fg("success", `''${fmt(tokCache)}`) + theme.fg("dim", " cached ") +' \
              --replace-fail 'return [line1, line2];' 'const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean).join(theme.fg("dim", " · ")); return statuses ? [line1, line2, truncateToWidth(" " + statuses, width, "")] : [line1, line2];'
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

        const SCOUT_TOOLS = ["read", "bash", "grep", "find", "ls", "aft_outline", "aft_zoom", "aft_search", "resolve-library-id", "query-docs", "mcp"];

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

      checkpointNudgeFile = pkgs.writeText "checkpoint-nudge.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
        import { readFileSync } from "node:fs";
        import { homedir } from "node:os";
        import { join } from "node:path";

        const DEFAULT_RESERVE_TOKENS = 16384;
        const NOTICE_SHARE = 0.6;
        const WARNING_SHARE = 0.8;

        const CONTENT =
          "GOAL (the user's actual intent), DECISIONS (choices made and why), STATE (key paths, variables, test status). " +
          "For DONE and NEXT write one line pointing to the todo list instead of repeating it.";

        const readCompaction = (file: string): Record<string, any> => {
          try {
            return JSON.parse(readFileSync(file, "utf8")).compaction ?? {};
          } catch {
            return {};
          }
        };

        const reserveTokens = (ctx: ExtensionContext): number => {
          const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
          const global = readCompaction(join(agentDir, "settings.json"));
          const project = readCompaction(join(ctx.cwd, ".pi", "settings.json"));
          const key = ctx.model ? `''${ctx.model.provider}/''${ctx.model.id}` : "";
          return (
            project.modelOverrides?.[key]?.reserveTokens ??
            global.modelOverrides?.[key]?.reserveTokens ??
            project.reserveTokens ??
            global.reserveTokens ??
            DEFAULT_RESERVE_TOKENS
          );
        };

        const k = (tokens: number) => `''${Math.round(tokens / 1000)}k`;

        export default function (pi: ExtensionAPI) {
          let stage = 0;
          let checkpointedAt = -1;
          let checkpointedThisTurn = false;
          let forced = false;

          const reset = () => {
            stage = 0;
            checkpointedAt = -1;
            checkpointedThisTurn = false;
            forced = false;
          };

          const nudge = (text: string) => ({
            type: "custom_message" as const,
            customType: "checkpoint-nudge",
            display: true,
            content: text,
          });

          const usage = (ctx: ExtensionContext) => {
            const u = ctx.getContextUsage();
            if (!u || u.tokens == null) return undefined;
            const compactAt = u.contextWindow - reserveTokens(ctx);
            if (compactAt <= 0) return undefined;
            return { tokens: u.tokens, compactAt };
          };

          pi.on("session_start", reset);
          pi.on("session_compact", reset);
          pi.on("session_tree", reset);

          pi.on("tool_result", (event) => {
            if (event.toolName !== "checkpoint_update" || event.isError) return;
            const text = event.content.map((c) => (c.type === "text" ? c.text : "")).join("");
            if (!text.startsWith("checkpoint_update ignored")) checkpointedThisTurn = true;
          });

          pi.on("turn_end", (_event, ctx) => {
            const u = usage(ctx);
            const next = !u ? stage : u.tokens >= u.compactAt * WARNING_SHARE ? 2 : u.tokens >= u.compactAt * NOTICE_SHARE ? 1 : 0;
            const advanced = next > stage;
            if (advanced) stage = next;
            if (checkpointedThisTurn) {
              checkpointedAt = stage;
              checkpointedThisTurn = false;
              return;
            }
            if (!advanced || !u) return;
            const where = `[context ''${k(u.tokens)} of ''${k(u.compactAt)} before compaction]`;
            const text =
              stage === 1
                ? `''${where} At your next milestone call checkpoint_update with ''${CONTENT}`
                : `''${where} Compaction is close. Before your next action call checkpoint_update with ''${CONTENT} Anything not in the checkpoint will be lost.`;
            return { entries: [nudge(text)] };
          });

          pi.on("agent_before_settle", (event, ctx) => {
            if (event.outcome !== "completed" || stage < 2 || checkpointedAt >= 2 || forced) return;
            forced = true;
            const u = usage(ctx);
            const where = u ? `[context ''${k(u.tokens)} of ''${k(u.compactAt)} before compaction]` : "[context almost full]";
            return {
              entries: [nudge(`''${where} The checkpoint is not updated. Call checkpoint_update now with ''${CONTENT} Then stop.`)],
              continue: true,
            };
          });
        }
      '';

      appendSystemFile = pkgs.writeText "pi-append-system.md" /* markdown */ ''
        The user is a senior developer. Be terse. Reply in the user's language. Work autonomously until the task is done or you are blocked.

        For every task:
        1. Locate: find the relevant code with grep, aft_search, aft_outline or aft_zoom. Read only the line ranges you need. Never guess file contents, APIs or paths.
        2. Plan: if the change touches more than one file, first write a numbered plan of at most 5 steps.
        3. Edit: make one small change at a time. Match the existing style. Do not add files, dependencies or refactors that were not asked for.
        4. Verify: after editing, run the narrowest build, test or lint command. On failure, read the error, fix it and re-run. After 3 failed attempts, stop and report.
        5. Report in at most 5 lines: what changed (path:line), how it was verified, what is left.

        Rules:
        - Make independent read-only tool calls in the same turn.
        - If the request is ambiguous, ask one question before editing anything.
        - Never claim success without a passing verify step; if nothing can be run, say so.
        - Do not repeat file contents or tool output back to the user.
        - If the same error appears twice in a row, stop and explain what you tried.
      '';
    in
    {
      config = {

        home.packages = [
          pkgs-unstable.pi-coding-agent
          (pkgs.callPackage mkPiAcp { })
        ];

        # Не ходить на pi.dev при старте: version check, remote model catalog, install telemetry
        home.sessionVariables.PI_OFFLINE = "1";

        programs.zsh.shellAliases.pig = "pi -e ${grillMePackage}";

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
          cp --reflink=never "${checkpointNudgeFile}" "$agent_dir/extensions/checkpoint-nudge.ts"
          chmod 644 "$agent_dir/extensions/checkpoint-nudge.ts"
          cp --reflink=never "${scoutFile}" "$agent_dir/extensions/scout.ts"
          chmod 644 "$agent_dir/extensions/scout.ts"

          for ext in damage-control tool-counter session-replay; do
            cp --reflink=never "${piVsCcExtensions}/$ext.ts" "$agent_dir/extensions/$ext.ts"
            chmod 644 "$agent_dir/extensions/$ext.ts"
          done
          cp --reflink=never "${piVsCcExtensions}/damage-control-rules.json" "${config.home.homeDirectory}/.pi/damage-control-rules.json"
          chmod 644 "${config.home.homeDirectory}/.pi/damage-control-rules.json"

          if ! cmp -s "${mcpJsonFile}" "$agent_dir/mcp.json"; then
            cp --reflink=never "${mcpJsonFile}" "$agent_dir/mcp.json"
            chmod 600 "$agent_dir/mcp.json"
            rm -f "$agent_dir/mcp-cache.json"
            log "mcp.json changed, dropped metadata cache to re-probe servers"
          fi

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
