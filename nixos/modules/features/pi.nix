# pi харнесс, шпаргалка: что за чем и когда использовать
#
# Запуск
#   pi              сам агент (эта конфигурация)
#   pi-acp          ACP-адаптер
#   /plan           plan-режим: read-only (read/grep/lsp/aft), план в todo;
#                   /plan ещё раз и начинается исполнение
#
# Задача: просто попросить. Агент сам:
#   правит -> lsp_diagnostics -> run_gates (go build, golangci-lint, go test,
#   buf lint, nixfmt, ast-grep standards) -> кратко отчитывается
#   give_up        честная остановка, когда застрял (вместо бесконечных ретраев)
#
# Субагенты (pi-herdr-subagents, herdr-вкладки, subagent / subagent_wait)
#   worker         один универсальный: читает, правит, гоняет проверки
#
# Скиллы (~/.agents/skills, общий для всех агентов магазин,
#   обновляется harness.nix при каждом switch, вызов /skill:<имя>)
#   engineering: ask-matt, codebase-design, code-review, diagnosing-bugs,
#   domain-modeling, grill-with-docs, implement, implement-spec,
#   improve-codebase-architecture, pr, prototype, research, retro,
#   setup-matt-pocock-skills, tdd, to-spec, to-tickets, triage, wayfinder, wizard
#   productivity: grilling, grill-me, handoff, teach, to-questionnaire,
#   wait-what, writing-for-agents
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
#   nixos           пакеты, опции NixOS/Home Manager/nix-darwin, версии nixpkgs
#   uc_dev
#   context7        актуальные доки библиотек: resolve-library-id + query-docs
#
# npm-экстеншены (источники встроенных инструментов)
#   aft-pi            aft_search / aft_outline / aft_zoom / codemode
#   pi-lsp-extension  lsp_* (Python/pyright, Nix/nixd, TypeScript, Go/gopls, Rust/rust-analyzer)
#   rpiv-todo         todo (план многошаговой работы)
#   pi-herdr-subagents  subagent / subagent_wait через herdr
#   pi-add-dir, @gotgenes/pi-permission-system, pi-fff, pi-undo-redo
#
# Карта файла (секции в порядке следования)
#   piExtensionDeps      npm-экстеншены и их версии
#   piExtensionsLock     package-lock экстеншенов
#   mkPiExtensions       сборка экстеншенов в store, патчи upstream
#   modelsConfig         модели Protei (id, reasoning, API-ключ)
#   mcpConfig            MCP-серверы
#   settingsSeed         seed settings.json (пути экстеншенов в store)
#   permissionConfig     конфиг @gotgenes/pi-permission-system (ADR-0006)
#   keybindingsOverrides маппинги клавиш
#   aftConfig            конфиг aft (lsp.disabled из lspOwnership harness.nix)
#   proteiAutoFile       protei-auto.ts (вирт. модели + кастомный footer)
#   piStats / piEval     статистика сессий / eval-харнес
#   todoReminderFile     todo-напоминатель
#   gatesFile            run_gates
#   bashGuardSource      bash-guard.ts source (pre-execution блок bash code-search/read)
#   appendSystemFile     приложение к системному промпту
#   home.file            конфиги в ~/.pi и ~/.config/cortexkit
#   home.activation      merge settings.json (setupPi)
#
{ config, lib, ... }:
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

  piExtensionDeps = {
    "@cortexkit/aft-pi" = "0.59.0";
    "@gotgenes/pi-permission-system" = "40.3.0";
    "@juicesharp/rpiv-todo" = "2.12.0";
    "pi-add-dir" = "1.3.1";
    "pi-fff" = "0.1.13";
    "pi-herdr-subagents" = "0.2.1";
    "pi-lsp-extension" = "1.4.0";
    "pi-undo-redo" = "0.1.3";
  };

  piExtensionsLock = {
    "node_modules/@cortexkit/aft-bridge" = {
      version = "0.59.0";
      integrity = "sha512-RFmIQ6+R5tM0Mxbt3kQsKF5YoERAx90SyyVJ4MK1yXzllShA9mclUg+5NFCnzmM3tiewpTUUqFpDqDCskYPxTQ==";
      dependencies = {
        "@cortexkit/subc-client" = "^0.20.0";
        "undici" = "^7.25.0";
      };
    };
    "node_modules/@cortexkit/aft-linux-x64" = {
      version = "0.59.0";
      integrity = "sha512-zbt9EL2rmC5ca+5evghb7AoxaXUPkIDVLQmR7aE6VKA1NKT7gNhO/g1FEnX315CLmpWtGnwZeO1qpZvKSfRrvg==";
      optional = true;
    };
    "node_modules/@cortexkit/aft-pi" = {
      version = "0.59.0";
      integrity = "sha512-0fxDsNi59RvJC5QIYsQWEU8Yn+JbyBL8b0DxNIrMPp7IBqBHziMZ6DwETCPBp2LA7w2PIZ07n2fl2ZOUzXZMLg==";
      dependencies = {
        "@cortexkit/aft-bridge" = "0.59.0";
        "comment-json" = "^5.0.0";
        "diff" = "^8.0.4";
        "zod" = "^4.4.3";
      };
      optionalDependencies = {
        "@cortexkit/aft-linux-x64" = "0.59.0";
      };
    };
    "node_modules/@cortexkit/subc-client" = {
      version = "0.20.0";
      integrity = "sha512-nH0A6QFFYD/ac7cDfUX9fL9jRWK/XjKz84IDFlUu5Rq1cvqYML3l/iY9RduT0lLTMbvcnmawT9v9NqbxlDvE5w==";
    };
    "node_modules/@ff-labs/fff-bin-linux-x64-gnu" = {
      version = "0.9.6";
      integrity = "sha512-OdROw237Ne7qy3HbTB78eovQMusccJ0PhRNAB6AmFuo+MiAzi1AdYs9iTAPYHqEH3uwEu0fdVFo9GTZcdnm03g==";
      optional = true;
    };
    "node_modules/@ff-labs/fff-node" = {
      version = "0.9.6";
      integrity = "sha512-2LbHJjwW/7vOLh1lSv0ipzA9Du5+LatUGiumQFaO9IcjMT8YgpmrCp/RRMyInsG0iBIX6A0WSxgei8qOFJLlNw==";
      dependencies = {
        "ffi-rs" = "^1.0.0";
      };
      optionalDependencies = {
        "@ff-labs/fff-bin-linux-x64-gnu" = "0.9.6";
      };
    };
    "node_modules/@gotgenes/pi-permission-system" = {
      version = "40.3.0";
      integrity = "sha512-B3iAs1YOnyUdeh66P40+YEJ0G3WBFsEpJAtXv/pY0CyhpIoErCoLBNKN2Sx9+Cg3VXmGMC1h/3T7r+b0d97oVg==";
      dependencies = {
        "tree-sitter-bash" = "^0.25.1";
        "web-tree-sitter" = "^0.26.9";
        "zod" = "^4.4.3";
      };
    };
    "node_modules/@juicesharp/rpiv-config" = {
      version = "2.13.9";
      integrity = "sha512-wCy7w4PNi+9pVD5gsbsIxq6ysdoFKXGPIQfOICyITW/+Jg6OGlFZa/tG99J9OZvTHDM8ZwUvqXNrFRsU6Z8NTQ==";
    };
    "node_modules/@juicesharp/rpiv-todo" = {
      version = "2.12.0";
      integrity = "sha512-bTILerGqMGrWMUkahHzXTuYa4iPkRX/LTl12HPppcCdPg7pGwrC1K7/ZtPfp7Xi4cXzqEoyZpeUM6IA8y5gtEQ==";
      dependencies = {
        "@juicesharp/rpiv-config" = "^2.12.0";
      };
    };
    "node_modules/@yuuang/ffi-rs-linux-x64-gnu" = {
      version = "1.3.7";
      integrity = "sha512-upEz1Q98T51x2In872fsjgHCJbE3e8r9JxhJD+5NvSMk6BpieYWRodTbsMxV6oKWmfl12loKwF2j4OBSWKl0lA==";
      optional = true;
    };
    "node_modules/array-timsort" = {
      version = "1.0.3";
      integrity = "sha512-/+3GRL7dDAGEfM6TseQk/U+mi18TU2Ms9I3UlLdUMhz2hbvGNTKdj9xniwXfUqgYhHxRx0+8UnKkvlNwVU+cWQ==";
    };
    "node_modules/better-result" = {
      version = "2.10.0";
      integrity = "sha512-oQhh0y1qo2/ZKdAAEvHZAqKKiHOFU5k/bW96fE2ScgQOVkJRiHwB+nOS1SgFsYqRlxMDWvefXi9Q3px7QvgNDw==";
    };
    "node_modules/comment-json" = {
      version = "5.0.0";
      integrity = "sha512-uiqLcOiVDJtBP8WGkZHEP+FZIhTzP1dxvn59EfoYUi9gqupjrBWVQkO2atDrbnKPwLeotFYDsuNb26uBMqB+hw==";
      dependencies = {
        "array-timsort" = "^1.0.3";
        "esprima" = "^4.0.1";
      };
    };
    "node_modules/diff" = {
      version = "8.0.4";
      integrity = "sha512-DPi0FmjiSU5EvQV0++GFDOJ9ASQUVFh5kD+OzOnYdi7n3Wpm9hWWGfB/O2blfHcMVTL5WkQXSnRiK9makhrcnw==";
    };
    "node_modules/esprima" = {
      version = "4.0.1";
      integrity = "sha512-eGuFFw7Upda+g4p+QHvnW0RyTX/SVeJBDM/gCtMARO0cLuT2HcEKnTPvhjV6aGeqrCB/sbNop0Kszm0jsaWU4A==";
    };
    "node_modules/ffi-rs" = {
      version = "1.3.7";
      integrity = "sha512-5MMZQS2t/6f/ec3sx0f51gBcKGZPGfolPAW04lvLOSYnr7gmOKs8YzH1Rh+34WGO+VtcgcTuxaUUoJLcR4Tirg==";
      optionalDependencies = {
        "@yuuang/ffi-rs-linux-x64-gnu" = "1.3.7";
      };
    };
    "node_modules/node-addon-api" = {
      version = "8.9.2";
      integrity = "sha512-VijLXbi3UACN69I0JVXJsX4tjACjNoQDgv2gTF6sx2wWEi8tkSg2eX8p5gSIFi8z2+DL3oHmY6OyKce38SDolg==";
    };
    "node_modules/node-gyp-build" = {
      version = "4.8.4";
      integrity = "sha512-LA4ZjwlnUblHVgq0oBF3Jl/6h/Nvs5fzBLwdEF4nuxnFdsfajde4WfxtJr3CaiH+F6ewcIB/q4jQ4UzPyid+CQ==";
    };
    "node_modules/pi-add-dir" = {
      version = "1.3.1";
      integrity = "sha512-y1kLHZEgP9xkBY2PeaVhrIntJTf0mSBCOPVfzzdjiJi03mkNcqcTouDLtmLXm5aOwNl5WCjR6Kw5eaMnj2kE2g==";
    };
    "node_modules/pi-fff" = {
      version = "0.1.13";
      integrity = "sha512-poQ+jTGu6cqmWI0Xq/WlSmhTTisieUT7tYhqzUbeUM5FRYioo2tKOsYY+lHA6s+Bmj9zXRiDbljdsR9Hmv2C1g==";
      dependencies = {
        "@ff-labs/fff-node" = "^0.9.4";
        "better-result" = "^2.8.2";
      };
    };
    "node_modules/pi-herdr-subagents" = {
      version = "0.2.1";
      integrity = "sha512-6YTpUwyjnOcGxgZ6Hf7eOrLX+0rTMk47TstmLZXeDQ4wg+oZm6Et1IjCJREQ/WFRwDuX3Y0Zdq7VYCFKRNwMdA==";
    };
    "node_modules/pi-lsp-extension" = {
      version = "1.4.0";
      integrity = "sha512-FOwGIivoZt5YfVY/LGqQZf4+wPXT+73loKOQ3Lu6zeG2UAPCxelHT21zXG/qCVD32epq8FymH9dJ8EnotXkv4Q==";
      dependencies = {
        "tree-sitter-wasms" = "^0.1.13";
        "vscode-languageserver-protocol" = "^3.17.5";
        "web-tree-sitter" = "^0.24.7";
      };
    };
    "node_modules/pi-lsp-extension/node_modules/web-tree-sitter" = {
      version = "0.24.7";
      integrity = "sha512-CdC/TqVFbXqR+C51v38hv6wOPatKEUGxa39scAeFSm98wIhZxAYonhRQPSMmfZ2w7JDI0zQDdzdmgtNk06/krQ==";
    };
    "node_modules/pi-undo-redo" = {
      version = "0.1.3";
      integrity = "sha512-IV/4jSrh4YWMGj/bMIey1rmIHeRQgYDEYULwBDRtM+IT1pfWoIoy7u9BHHmrHknsuPT5DeYnlMx36CtKGuuEnA==";
    };
    "node_modules/tree-sitter-bash" = {
      version = "0.25.1";
      integrity = "sha512-7hMytuYIMoXOq24yRulgIxthE9YmggZIOHCyPTTuJcu6EU54tYD+4G39cUb28kxC6jMf/AbPfWGLQtgPTdh3xw==";
      dependencies = {
        "node-addon-api" = "^8.2.1";
        "node-gyp-build" = "^4.8.2";
      };
      hasInstallScript = true;
    };
    "node_modules/tree-sitter-wasms" = {
      version = "0.1.13";
      integrity = "sha512-wT+cR6DwaIz80/vho3AvSF0N4txuNx/5bcRKoXouOfClpxh/qqrF4URNLQXbbt8MaAxeksZcZd1j8gcGjc+QxQ==";
      dependencies = {
        "tree-sitter-wasms" = "^0.1.11";
      };
    };
    "node_modules/undici" = {
      version = "7.30.1";
      integrity = "sha512-03KrMbjIFDWQR5RNPrSw3bd1r12JpyFQl9/yxjUbJtqkjmllqC5lFjZh6ujeuJCKr8EOQvRW872Oy/az+nLYxg==";
    };
    "node_modules/vscode-jsonrpc" = {
      version = "9.0.3";
      integrity = "sha512-qETYf9PCl1lVfwR+oBmMfc4vP2nqLNA35ABxorw3j06+xlKRgDVxbLgKm4Y/xPL0YWdeDjLoI4ImICIT3nB0zQ==";
    };
    "node_modules/vscode-languageserver-protocol" = {
      version = "3.18.4";
      integrity = "sha512-CCXbyr99dafRJzJH/0Ryk7ly5T8XPmSR0//OuF2w4m+9JiOin7zcAT5iET8GRE7Z9taFBejb3GbM0a0mbjdbrg==";
      dependencies = {
        "vscode-jsonrpc" = "9.0.3";
        "vscode-languageserver-types" = "3.18.4";
      };
    };
    "node_modules/vscode-languageserver-types" = {
      version = "3.18.4";
      integrity = "sha512-nQsacoiijvl0fRf2q28uFDrAVwRhdCa3QveiF7/CX0r18mLR5FU/1WskSsCKOjmEbtteKUnY8x8Yzxop+k0zwg==";
    };
    "node_modules/web-tree-sitter" = {
      version = "0.26.13";
      integrity = "sha512-5bUZ7vbQ1kcondet96wzP974+JfCZDeQ7bTpacICm2nnvHpa5cO0ByRsoMcAhUP+743vpkb4m0BFlVSm+Ye9VA==";
    };
    "node_modules/zod" = {
      version = "4.6.7";
      integrity = "sha512-g8W2D2kU6a8untc053fX1uVBKzM7yqAxW/3zwk83+6RyF2+SKOuV+c0wBDhUwzV1PaGapmZH+rmcUzPf+3CGwg==";
    };
  };

  mkPiExtensions =
    {
      buildNpmPackage,
      linkFarm,
      writeText,
    }:
    let
      manifest = {
        name = "pi-extensions";
        version = "0";
        dependencies = piExtensionDeps;
      };
      registryUrl =
        path: version:
        let
          name = lib.last (lib.splitString "node_modules/" path);
        in
        "https://registry.npmjs.org/${name}/-/${baseNameOf name}-${version}.tgz";
    in
    buildNpmPackage {
      pname = manifest.name;
      inherit (manifest) version;
      src = linkFarm "pi-extensions-src" {
        "package.json" = writeText "package.json" (builtins.toJSON manifest);
        "package-lock.json" = writeText "package-lock.json" (
          builtins.toJSON {
            inherit (manifest) name version;
            lockfileVersion = 3;
            requires = true;
            packages = {
              "" = manifest;
            }
            // lib.mapAttrs (
              path: entry: entry // { resolved = registryUrl path entry.version; }
            ) piExtensionsLock;
          }
        );
      };
      npmDepsHash = "sha256-4eq9dPUWM/5wYXpxoCVs6Xdev7b4iDcUkHP/ysqJ6Bk=";
      npmFlags = [ "--legacy-peer-deps" ];
      dontNpmBuild = true;

      postConfigure = ''
        substituteInPlace node_modules/pi-herdr-subagents/pi-extension/subagents/subagent-done.ts \
          --replace-fail '"ctrl+j"' '"ctrl+i"' \
          --replace-fail 'Ctrl+J' 'Ctrl+I'
        substituteInPlace node_modules/pi-fff/src/fff-runtime.ts \
          --replace-fail 'async findFiles(request: FindFilesRequest): Promise<FindFilesResult> {' 'async searchPathCandidates(query: string, limit = DEFAULT_FILE_CANDIDATE_LIMIT): Promise<AppResult<FffFileCandidate[], RuntimeInitializationError | FinderOperationError>> { const finderResult = await this.ensure(); if (finderResult.isErr()) return propagateError(finderResult); const normalizedQuery = normalizePathQuery(query); if (!normalizedQuery) return Result.ok([]); const search = safeFinderCall("mixedSearch", () => finderResult.value.mixedSearch(normalizedQuery, { pageSize: Math.max(limit, DEFAULT_FILE_CANDIDATE_LIMIT) })); if (search.isErr()) return propagateError(search); return Result.ok(search.value.items.slice(0, limit).map((entry, index) => normalizeCandidate(entry.item as FileItem, search.value.scores[index]))); } async findFiles(request: FindFilesRequest): Promise<FindFilesResult> {'
        substituteInPlace node_modules/pi-fff/src/editor.ts \
          --replace-fail 'this.runtime.searchFileCandidates(rawQuery, MAX_RESULTS)' 'this.runtime.searchPathCandidates(rawQuery, MAX_RESULTS)'
        substituteInPlace node_modules/pi-lsp-extension/dist/index.js \
          --replace-fail '".php": "php"' '".php": "php", ".nix": "nix"' \
          --replace-fail 'java: { command: "jdtls", args: [] }' 'java: { command: "jdtls", args: [] }, nix: { command: "nixd", args: [] }' \
          --replace-fail 'if (!existsSync3(configPath)) return null;' 'if (!existsSync3(configPath)) { const autoStart = [...new Set([["go.mod", "go"], ["Cargo.toml", "rust"], ["flake.nix", "nix"], ["default.nix", "nix"], ["shell.nix", "nix"], ["tsconfig.json", "typescript"], ["package.json", "typescript"], ["pyproject.toml", "python"], ["setup.py", "python"], ["requirements.txt", "python"]].filter(([marker]) => existsSync3(join2(dir, marker))).map(([, lang]) => lang))]; return autoStart.length > 0 ? { autoStart } : null; }'
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r node_modules "$out/"
        runHook postInstall
      '';
    };

  bashGuardSource = /* typescript */ ''
    import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
    import { homedir } from "node:os";
    import { resolve, sep } from "node:path";

    const BANNED = new Set(["grep", "egrep", "fgrep", "rg", "find", "cat", "sed", "head", "tail"]);
    const VALUE_SHORT: Record<string, string> = {
      grep: "ABCDefgjmmtTu",
      egrep: "ABCDefgjmmtTu",
      fgrep: "ABCDefgjmmtTu",
      rg: "ABCDefgjmmtTu",
      sed: "e",
      head: "cn",
      tail: "cn",
      cat: "",
      find: "",
    };

    const REASON =
      "[bash-guard] Blocked: bash reading/searching project files is not allowed (AGENTS.md). Search: grep or aft_search tool. File content: read (startLine/endLine) or aft_zoom. Structure: aft_outline. Edits: edit tool.";

    function tokenize(command: string): string[][][] {
      const pipelines: string[][][] = [];
      let stage: string[] = [];
      let i = 0;
      const n = command.length;
      let word = "";
      let seen = false;
      let paren = 0;
      let backtick = false;
      const pushWord = () => {
        if (seen) {
          stage.push(word);
          word = "";
          seen = false;
        }
      };
      const flushStage = () => {
        pushWord();
        if (stage.length) pipelines[pipelines.length - 1]!.push(stage);
        stage = [];
      };
      const flushPipeline = () => {
        flushStage();
        pipelines.push([]);
      };
      flushPipeline();
      while (i < n) {
        const ch = command[i];
        const atTop = paren === 0 && !backtick;
        if (atTop && ch === "\\" && i + 1 < n) {
          word += command[i + 1];
          seen = true;
          i += 2;
          continue;
        }
        if (atTop && (ch === "'" || ch === '"')) {
          let j = i + 1;
          while (j < n && command[j] !== ch) j++;
          const end = Math.min(j, n);
          word += command.slice(i + 1, end);
          seen = true;
          i = Math.min(j + 1, n);
          continue;
        }
        if (atTop && ch === "|") {
          if (command[i + 1] === "|") {
            flushStage();
            flushPipeline();
            i += 2;
          } else {
            flushStage();
            i += 1;
          }
          continue;
        }
        if (atTop && (ch === "&" || ch === ";" || ch === "\n")) {
          const isRedirectAmp = ch === "&" && seen && word.endsWith(">");
          if (!isRedirectAmp) {
            if (ch === "&" && command[i + 1] === "&") i += 1;
            flushStage();
            flushPipeline();
            i += 1;
            continue;
          }
        }
        if (atTop && ch === "$" && command[i + 1] === "(") {
          word += "$(";
          seen = true;
          paren = 1;
          i += 2;
          continue;
        }
        if (backtick) {
          if (ch === "`") backtick = false;
          word += ch;
          seen = true;
          i += 1;
          continue;
        }
        if (paren > 0) {
          if (ch === "(") paren += 1;
          else if (ch === ")") {
            paren -= 1;
            if (paren === 0) {
              word += ")";
              i += 1;
              continue;
            }
          }
          word += ch;
          seen = true;
          i += 1;
          continue;
        }
        if (ch === "`") {
          backtick = true;
          word += ch;
          seen = true;
          i += 1;
          continue;
        }
        if (/\s/.test(ch)) {
          pushWord();
          i += 1;
          continue;
        }
        word += ch;
        seen = true;
        i += 1;
      }
      flushStage();
      return pipelines;
    }

    function stageArgs(tokens: string[]): string[] {
      const out: string[] = [];
      let skipNext = false;
      for (const t of tokens) {
        if (skipNext) {
          skipNext = false;
          continue;
        }
        if (/^<\(/.test(t)) continue;
        if (/^[0-9]*(>>|>|<)$/.test(t) || /^[0-9]*<</.test(t)) {
          skipNext = true;
          continue;
        }
        if (/^[0-9]*[<>]/.test(t)) continue;
        out.push(t);
      }
      return out;
    }

    export function bashGuardVerdict(command: string, root: string): string | null {
      const rootAbs = resolve(root);
      const inProject = (p: string): boolean => {
        if (p.includes("$") || p.includes("`")) return false;
        let q = p;
        if (q === "~" || q.startsWith("~/")) q = homedir() + q.slice(1);
        const glob = q.search(/[*?[]/);
        if (glob >= 0) q = q.slice(0, glob);
        const r = resolve(cwd, q);
        return r === rootAbs || r.startsWith(rootAbs + sep);
      };
      let cwd = rootAbs;
      for (const pipe of tokenize(command)) {
        for (let si = 0; si < pipe.length; si++) {
          const args = stageArgs(pipe[si]);
          let idx = 0;
          while (idx < args.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(args[idx])) idx++;
          if (idx >= args.length) continue;
          const name = args[idx].slice(args[idx].lastIndexOf("/") + 1);
          const rest = args.slice(idx + 1);
          if (name === "cd" || name === "pushd") {
            const t = rest[0];
            if (t && !t.includes("$") && !t.includes("`")) cwd = resolve(cwd, t === "~" ? homedir() : t);
            continue;
          }
          if (!BANNED.has(name)) continue;
          const fromPipe = si > 0;
          const valueChars = VALUE_SHORT[name] ?? "";
          const operands: string[] = [];
          let hasVersion = false;
          let explicitPattern = false;
          let literal = false;
          for (let k = 0; k < rest.length; k++) {
            const t = rest[k];
            if (literal) {
              operands.push(t);
              continue;
            }
            if (t === "--") {
              literal = true;
              continue;
            }
            if (t.startsWith("-") && t !== "-") {
              if (/^(--version|--help)$/.test(t) || /^-(version|help|V)$/.test(t)) hasVersion = true;
              const chars = t.slice(1).replace(/=.+$/, "");
              if (t.startsWith("--") || /^\d+$/.test(chars)) continue;
              let consumesNext = false;
              for (const c of chars) if (valueChars.includes(c) && c === chars.at(-1)) consumesNext = true;
              if (chars === "e") explicitPattern = true;
              if (consumesNext) k++;
              continue;
            }
            operands.push(t);
          }
          if (hasVersion) continue;
          if (name === "find") {
            const start = operands[0] ?? ".";
            if (inProject(start)) return REASON;
            continue;
          }
          if (name === "sed") {
            const files = explicitPattern ? operands : operands.slice(1);
            if (files.some((f) => inProject(f))) return REASON;
            continue;
          }
          if (name === "cat" || name === "head" || name === "tail") {
            if (operands.some((f) => inProject(f))) return REASON;
            continue;
          }
          const paths = explicitPattern ? operands : operands.slice(1);
          if (paths.length === 0) {
            if (!fromPipe && inProject(cwd)) return REASON;
            continue;
          }
          if (paths.some((p) => inProject(p))) return REASON;
        }
      }
      return null;
    }

    export default function (pi: ExtensionAPI) {
      pi.on("tool_call", (event, ctx) => {
        if (event.toolName !== "bash") return;
        const command = (event.input as { command?: string }).command;
        if (!command) return;
        const reason = bashGuardVerdict(command, ctx.cwd);
        if (reason) return { block: true, reason };
      });
    }
  '';

  permissionSchemaCheckSource = /* typescript */ ''
    import { unifiedConfigSchema } from "./config-schema.ts";
    import { readFileSync } from "node:fs";

    const doc = JSON.parse(readFileSync(process.argv[2], "utf8"));
    const result = unifiedConfigSchema.safeParse(doc);
    if (!result.success) {
      for (const issue of result.error.issues) {
        console.error((issue.path.join("/") || "/") + ": " + issue.message);
      }
      process.exit(1);
    }
    console.log("pi-permission-config.json is valid against the extension's zod schema");
  '';

in
{
  perSystem =
    { pkgs, pkgs-unstable, ... }:
    {
      packages.pi = pkgs-unstable.pi-coding-agent;
      packages.pi-acp = pkgs.callPackage mkPiAcp { };
      checks.pi-extensions = pkgs.callPackage mkPiExtensions { };
      checks."bash-guard" =
        let
          guard = pkgs.writeText "bash-guard.ts" bashGuardSource;
          cases = [
            "grep -n 'phone/list' services/api/protos/uc/mkd_adapter.proto"
            "grep -rn 'GetSipDomain' services/api/protos/uc/*.proto"
            "cd /home/dias/Work/core && grep -n 'PpsPhoneList\\|PpsPhone\\|SipTrunk\\|SipDomain' services/api/protos/uc/mkd_adapter.proto"
            "grep -n 'GetUsersShortInfo\\|UserInfo\\|GeneralUserInfo' services/api/protos/uc/user.proto | head -40"
            "grep -n 'company_id\\|companyName\\|Company' services/api/protos/uc/*.proto | head -60"
            "grep -n 'companyId' services/agent/... | head -30"
            "cat /home/dias/Work/core/services/mkd-lk-api-gw/internal/middleware/trace.go"
            "sed -n '515,545p' /home/dias/Work/core/docker-compose.yml"
            "sed -n '495,520p' docker-compose.yml"
            "head -20 src/config/config.go && grep -n 'company\\|Company' src/s..."
            "cd /home/dias/Work/core/services/mkd-lk-api-gw && find . -type f \\( -name 'config*.go' -o -name 'config*.yml' \\)"
            "find . -type f -not -path './swagger-api*' -not -name 'swagger.json' | head -80"
            "head -40 docker-compose.yml"
            "tail -30 services/api/protos/uc/call.proto"
            "cat services/mkd-lk-api-gw/go.mod"
            "grep -rn 'externalUserId' services/ --include='*.go' | head -20"
            "grep 'pattern'"
            "rg -n 'phone' services/"
            "sed -i 's/old/new/g' services/x/main.go"
            "grep -h '^app:' services/*/config/logs-collector.yml 2>/dev/null | sort | uniq -c"
            "git status --short --branch | head -5"
            "git status --short --branch | head -5; git -C /home/dias/Work/core branch --show-current"
            "git log --oneline -5"
            "go build ./..."
            "GO111MODULE=on go build -gcflags=all=\"-trimpath=$(go env GOMODCACHE)\" ./cmd"
            "ls docs/"
            "wc -l docs/agent-api.md"
            "make test"
            "go test ./internal/... 2>&1 | grep FAIL"
            "make build | tail -20"
            "cat /home/dias/go/pkg/mod/git.protei.ru/protei-golang/passlib/v3@v3.2.0/service/user_session_info.go"
            "grep -rn 'GetUserId' $(go env GOMODCACHE)/git.protei.ru/protei-golang/ 2>/dev/null | grep -v _test | head -15"
            "grep --version"
            "find / -name 'pi-agent' 2>/dev/null | head -5"
            "cd /home/dias/go/pkg/mod && grep -rn 'func GetLogin' . 2>/dev/null | head -5"
            "echo 'hello world' | head -1"
            "git grep -n 'companyId' services/ | head"
            "cat /etc/hostname"
            "ls -la && pwd"
            "sed -n '10,20p' /tmp/notes.txt"
            "tail -f /var/log/nginx/error.log | head"
            "git diff | head -40"
            "go vet ./... && go test -run TestCompany ./... | head"
            "head -5 /proc/cpuinfo"
          ];
          driver = pkgs.writeText "bash-guard-test.mjs" ''
            import { bashGuardVerdict } from "${guard}";
            const cases = ${builtins.toJSON cases};
            const root = "/home/dias/Work/core";
            const expect = [ "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "block", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass", "pass" ];
            let failed = 0;
            for (let i = 0; i < cases.length; i++) {
              const blocked = bashGuardVerdict(cases[i], root) !== null;
              const want = expect[i] === "block";
              if (blocked !== want) {
                console.error("FAIL want=" + expect[i] + " got=" + (blocked ? "block" : "pass") + ": " + cases[i]);
                failed++;
              }
            }
            if (failed > 0) {
              console.error(failed + " of " + cases.length + " cases failed");
              process.exit(1);
            }
            console.log("bash-guard: all " + cases.length + " cases pass");
          '';
        in
        pkgs.runCommand "bash-guard-test" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
          node ${driver}
          touch "$out"
        '';
    };

  flake.nixosModules.pi =
    { config, pkgs, ... }:
    {
      config = {
        programs.nix-ld.enable = true;

        # the extension silently drops the whole config on schema failure, so a
        # syntactically valid but schema-invalid file is indistinguishable at
        # runtime from an absent one; the check runs the extension's own zod
        # schema against the rendered file
        system.build."pi-permission-schema-check" =
          let
            ext = pkgs.callPackage mkPiExtensions { };
            extNodeModules = "${ext}/node_modules";
            pkg = "${extNodeModules}/@gotgenes/pi-permission-system";
            cfg =
              config.home-manager.users.dias.home.file.".pi/agent/extensions/pi-permission-system/config.json".source;
            checkScript = pkgs.writeText "check-permission-schema.mts" permissionSchemaCheckSource;
          in
          pkgs.runCommand "pi-permission-config-schema"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            }
            ''
              # node не снимает типы для файлов под node_modules, поэтому
              # config-schema.ts копируется наружу вместе со ссылкой на zod расширения
              mkdir -p $out/validate/node_modules
              cp ${pkg}/src/config/config-schema.ts $out/validate/
              cp ${checkScript} $out/validate/check.mts
              ln -s ${extNodeModules}/zod $out/validate/node_modules/zod
              node $out/validate/check.mts ${lib.escapeShellArg cfg}
            '';
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

      piExtensions = pkgs.callPackage mkPiExtensions { };

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
            maxTokens = 32768;
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
                maxTokens = 32768;
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
              "git+ssh://git@${config.programs.harness.internalGitHost}/qa-stuff/llm/mcp/gitlab.git"
              "gitlab-mcp-server"
            ];
            env = {
              GITLAB_URL = "https://${config.programs.harness.internalGitHost}";
              GITLAB_TOKEN = readSecret "git/gitlab_mcp_token";
            };
          };
          rag = {
            description = "Protei knowledge base search (LightRAG)";
            command = "uvx";
            args = [
              "--from"
              "git+ssh://git@${config.programs.harness.internalGitHost}/qa-stuff/llm/mcp/lightrag-mcp.git"
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
          context7 = {
            description = "Up-to-date documentation and code examples for libraries and frameworks";
            url = "https://mcp.context7.com/mcp";
          };
          codebase_memory = {
            description = "Code knowledge graph of indexed repositories";
            command = lib.getExe config.programs.harness.codebaseMemory;
            args = config.programs.harness.codebaseMemoryArgs;
            env = {
              CBM_ALLOWED_ROOT = config.home.homeDirectory;
            };
          };
          nixos = {
            description = "NixOS, Home Manager and nix-darwin packages, options and nixpkgs versions";
            command = lib.getExe config.programs.harness.mcpNixos;
            args = [ ];
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
        defaultThinkingLevel = "medium";
        defaultTools = [ "-powershell" ];
        thinkingBudgets = {
          low = 2048;
          medium = 4096;
          high = 6144;
        };
        compaction = {
          reserveTokens = 41000;
        };
        packages = map (name: "${piExtensions}/node_modules/${name}") (lib.attrNames piExtensionDeps) ++ [
          "${piPlan}"
        ];
      };

      keybindingsOverrides = {
        "app.thinking.cycle" = "alt+t";
      };

      aftConfig = {
        format_on_edit = true;
        bash.background = false;
        # callgraph-индекс выключен, инструмент aft_callgraph и так в disabled_tools
        indexes.callgraph = false;
        lsp = {
          auto_install = false;
          # LSP всех языков из ownership-таблицы отдаёт нативный LSP агентов, не aft (ADR-0002)
          disabled = lib.attrNames config.programs.harness.lspOwnership;
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
        # семантика и реранкер в корпоративном embedder, ключ в PROTEI_AI_API_KEY
        semantic = {
          backend = "openai_compatible";
          model = "giga-embeddings-instruct";
          base_url = "https://embedder.ai.protei.ru/api/";
          api_key_env = "PROTEI_AI_API_KEY";
        };
        search.rerank = {
          backend = "remote";
          model = "bge-reranker-v2-m3";
          endpoint = "https://rerank.ai.protei.ru/api/";
          api_key_env = "PROTEI_AI_API_KEY";
          top_n = 20;
        };
      };

      toJsonFile = (pkgs.formats.json { }).generate;

      modelsJsonFile = toJsonFile "pi-models.json" modelsConfig;
      mcpJsonFile = toJsonFile "pi-mcp.json" mcpConfig;
      settingsSeedFile = toJsonFile "pi-settings-seed.json" settingsSeed;
      permissionConfig =
        let
          perms = config.programs.harness.permissions;
          rules =
            action: patterns: reason:
            lib.listToAttrs (
              map (p: {
                name = p;
                value = {
                  action = action;
                  reason = reason;
                };
              }) patterns
            );
          allows =
            patterns:
            lib.listToAttrs (
              map (p: {
                name = p;
                value = "allow";
              }) patterns
            );
          asks =
            patterns:
            lib.listToAttrs (
              map (p: {
                name = p;
                value = "ask";
              }) patterns
            );
        in
        {
          "$schema" =
            "https://raw.githubusercontent.com/gotgenes/pi-packages/main/packages/pi-permission-system/schemas/permissions.schema.json";
          yoloMode = true;
          permission = {
            "*" = "allow";
            external_directory_read = {
              "*" = "allow";
            };
            external_directory_write = {
              "*" = "ask";
            };
            path = {
              "*" = "allow";
            }
            // rules "deny" perms.secretsPatterns perms.secretsReason
            // allows perms.secretsExceptions
            // {
              "/nix/store/*" = "allow";
            };
            path_write = {
              "*" = "allow";
            }
            // rules "deny" perms.protectedWritePatterns perms.protectedWriteReason
            // allows perms.protectedWriteExceptions
            // asks perms.metaFilePatterns;
            bash = {
              "*" = "ask";
            }
            // allows perms.bashAllowPatterns
            // asks perms.bashAskPatterns
            // lib.listToAttrs (
              map (d: {
                name = d.pattern;
                value = {
                  action = "deny";
                  reason = d.reason;
                };
              }) perms.bashDenyPatterns
            );
          };
          commandEffects = {
            git.subcommands = {
              log = "read";
              show = "read";
              status = "read";
              diff = "read";
              blame = "read";
              ls-files = "read";
              describe = "read";
              rev-parse = "read";
              # pathspec — read-ссылка на файлы, запись идёт в .git; сама команда под bash-правилами
              add = "read";
              commit = "read";
            };
            nix.effects = [ "read" ];
            jq.effects = [ "read" ];
          };
        };
      permissionConfigFile = toJsonFile "pi-permission-config.json" permissionConfig;
      keybindingsJsonFile = toJsonFile "pi-keybindings.json" keybindingsOverrides;
      aftJsonFile = toJsonFile "aft.jsonc" aftConfig;
      fffJsonFile = toJsonFile "pi-fff.json" {
        enabledFeatures = [ "autocomplete" ];
      };

      piPlanCmd = /* bash */ ''
        mkdir -p "$out"
        tar xzf "$src" -C "$out" --strip-components=1
        substituteInPlace "$out/src/safety.ts" \
          --replace-fail '  /^\s*bat\b/,' '  /^\s*bat\b/, /^\s*herdr\s+(status|(pane\s+(list|current|get|layout|process-info|neighbor|edges|read|wait-output)|tab\s+(list|get)|workspace\s+(list|get)|agent\s+(list|get|read|wait|explain))\b)/,'
        substituteInPlace "$out/extensions/plan/index.ts" \
          --replace-fail 'const NORMAL_MODE_TOOLS = ["read", "bash", "edit", "write"];' "" \
           --replace-fail 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls"];' 'const PLAN_MODE_TOOLS = ["read", "bash", "grep", "find", "ls", "todo", "lsp_definition", "lsp_references", "lsp_hover", "lsp_diagnostics", "aft_outline", "aft_zoom", "aft_search"];' \
            --replace-fail '- You can only use: read, bash, grep, find, ls' '- You can only use: read, bash, grep, find, ls, todo, lsp_definition, lsp_references, lsp_hover, lsp_diagnostics, aft_outline, aft_zoom, aft_search' \
          --replace-fail 'pi.setActiveTools(PLAN_MODE_TOOLS);' "" \
          --replace-fail 'pi.setActiveTools(NORMAL_MODE_TOOLS);' 'if (!pi.getActiveTools().includes("edit")) pi.setActiveTools(pi.getAllTools().filter((t) => !t.exposure || t.exposure === "direct" || t.exposure === "model-only").map((t) => t.name));' \
           --replace-fail 'if (event.toolName === "write" || event.toolName === "edit") {' 'if (!PLAN_MODE_TOOLS.includes(event.toolName) && event.toolName !== "mcp" && !event.toolName.startsWith("mcp__")) {' \
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

      proteiAutoFile = pkgs.writeText "protei-auto.ts" /* typescript */ ''
        import type { Api, Model, ModelThinkingLevel } from "@earendil-works/pi-ai";
        import type { ExtensionAPI, ExtensionContext, ModelRouteRequest } from "@earendil-works/pi-coding-agent";
        import { calculateContextTokens, estimateTokens } from "@earendil-works/pi-coding-agent";
        import type { ReadonlyFooterDataProvider, Theme } from "@earendil-works/pi-coding-agent";
        import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
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
          let lastMain = Date.now();
          let usage: { ctx: number; hit: number } | undefined;
          let liveCtx: ExtensionContext | undefined;
          let rerender: (() => void) | undefined;
          let footerInstalled = false;
            const toolCounts = new Map<string, number>(); // намерено суммарные вызовы за сессию, reset не предусмотрен

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

          const row = (width: number, left: string, center: string, right: string): string => {
            const lw = visibleWidth(left);
            const cw = visibleWidth(center);
            const rw = visibleWidth(right);
            const mid = width - lw - rw;
            if (mid < cw + 2) return truncateToWidth([left, center, right].filter(Boolean).join("  "), width, "");
            const before = Math.floor((mid - cw) / 2);
            return left + " ".repeat(Math.max(1, before)) + center + " ".repeat(Math.max(1, mid - cw - before)) + right;
          };

          const buildFooter = (width: number, theme: Theme, fd: ReadonlyFooterDataProvider): string[] => {
            const ctx = liveCtx;
            if (!ctx) return [];
            const m = ctx.model;
            const virtual = isVirtual(m);
            let name: string, mmode: string, think: string, tmode = "";
            if (virtual) {
              name = TARGETS[routed].id;
              mmode = "auto";
              think = LEVELS[level()];
              const ml = manualLeft();
              tmode = ml ? "man " + ml + "m" : "auto";
            } else {
              name = (m && m.id) || "no-model";
              mmode = "manual";
              think = (ctx.thinkingLevel as string) || "off";
            }
            const dim = (s: string) => theme.fg("dim", s);
            const cu = ctx.getContextUsage();
            const pct = cu ? cu.percent : null;
            let barText: string, barColor: "dim" | "warning" | "error";
            if (pct === null || pct === undefined) {
              barText = "░░░░░░░░░░ ?";
              barColor = "dim";
            } else {
              const filled = Math.max(0, Math.min(10, Math.round(pct / 10)));
              barText = "▓".repeat(filled) + "░".repeat(10 - filled) + " " + Math.round(pct) + "%";
              barColor = pct > 90 ? "error" : pct > 70 ? "warning" : "dim";
            }
            const st = fd.getExtensionStatuses();
            const lsp = st.get("lsp") || "";
            const modes = Array.from(st.entries()).filter(([k]) => k !== "lsp" && k !== "protei-auto").map(([, t]) => t).filter(Boolean).join(" · ");
            const tools = Array.from(toolCounts.entries()).sort(([a], [b]) => a.localeCompare(b)).map(([k, n]) => theme.fg("mdLink", k) + theme.fg("text", "×") + theme.fg("warning", n)).join(" ");
            const v = ewmaOf(backend());
            const speed = v === undefined ? "" : "⚡ " + Math.round(v) + " tok/s";
            const l1c = "🪟 ctx " + theme.fg(barColor, barText);
            const l1l = "🤖 " + theme.fg("accent", name) + " " + dim("⟨" + mmode + "⟩") + " · " + theme.fg("success", think) + (tmode ? " " + dim("⟨" + tmode + "⟩") : "") + "  " + l1c;
            const speedText = speed ? theme.fg("warning", speed) : "";
            const full = [lsp ? "🧰 " + theme.fg("mdLink", lsp) : "", speedText].filter(Boolean).join("  ");
            const l1r = visibleWidth(l1l) + visibleWidth(full) + 2 <= width ? full : speedText;
            const l2l = tools ? dim("🔧 ") + tools : "";
            return [row(width, l1l, "", l1r), row(width, l2l, "", modes)];
          };

          const installFooter = (ctx: ExtensionContext) => {
            if (footerInstalled) return;
            ctx.ui.setFooter((tui, theme, fd) => {
              rerender = () => tui.requestRender();
              footerInstalled = true;
              return {
                render(width: number) {
                  return buildFooter(width, theme, fd);
                },
                invalidate() {},
                dispose() {
                  footerInstalled = false;
                  rerender = undefined;
                },
              };
            });
          };

          const show = (ctx: ExtensionContext) => {
            if (!ctx.hasUI) return;
            liveCtx = ctx;
            installFooter(ctx);
            rerender?.();
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
            maxTokens: 32768,
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
              const sticky = request.reason === "retry" ? request.failed : request.reason === "user" ? undefined : request.previous;
              const stickyKey = sticky && keyOf(sticky.model);
              const stickyLevel = sticky?.thinkingLevel;
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
                return { model: find(routed), thinkingLevel: stickyLevel };
              }
              if (selected !== undefined && request.thinkingLevel !== selected && levelIndex(request.thinkingLevel) >= 0) {
                manual = { level: levelIndex(request.thinkingLevel), at: now };
                upCount = 0;
              }
              selected = request.thinkingLevel;
              if (auto === undefined) auto = Math.max(0, levelIndex(request.thinkingLevel));
              const strict = big || planMode(ctx) === "plan";
              if (!strict) choosePool(now);
              retarget(strict ? "strict" : pool);
              const model: Model<Api> = find(routed);
              const thinkingLevel: ModelThinkingLevel = LEVELS[level(now)];
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

            pi.on("tool_execution_start", (e) => {
            toolCounts.set(e.toolName, (toolCounts.get(e.toolName) ?? 0) + 1);
            rerender?.();
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

      gatesFile = pkgs.writeText "gates.ts" /* typescript */ ''
        import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
        import { Type } from "typebox";
        import { createHash } from "node:crypto";
        import { existsSync, readFileSync, readdirSync } from "node:fs";
        import { homedir } from "node:os";
        import { dirname, isAbsolute, join, relative, resolve } from "node:path";
        type Result = { name: string; ok: boolean; output: string };
        type Finding = { ruleId: string; severity: string; message: string; file: string; range: { start: { line: number } } };

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

          pi.on("input", () => {
            fails = 0;
            gaveUp = false;
            return { action: "continue" as const };
          });

          pi.on("agent_start", (_event, ctx) => {
            void snapshot(ctx.cwd);
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
            const out: Result[] = [];
            for (const [top, snap] of snapshots) {
              const now = await listTests(top);
              const names = new Set([...snap.keys(), ...now]);
              const moved = [...names].filter((f) => (snap.get(f) ?? "missing") !== sha(join(top, f)));
              if (moved.length) out.push({ name: `test files unchanged (''${top})`, ok: false, output: `Test files changed since the snapshot at agent start, probably through bash:\n''${moved.slice(0, 20).join("\n")}\nRestore them with git checkout -- <file> (or delete new ones) and fix the code instead.` });
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
            const results = await gate(ctx.cwd, signal);
            const ok = results.every((r) => r.ok);
            if (signal?.aborted) return undefined;
            if (ok) changed.clear();
            return { ok, results };
          };

          pi.on("agent_before_settle", async (event, ctx) => {
            if (event.outcome !== "completed" || gaveUp || fails >= MAX_FAILS || !event.context.canContinue) return;
            if (changed.size === 0 && snapshots.size === 0) return;
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
              return {
                content: [{ type: "text" as const, text: "Recorded. Do not edit any more files. Now explain to the user what blocked you, what you tried, which checks still fail and what state the files are in, then stop." }],
                details: { reason: params.reason },
              };
            },
          });
        }
      '';

      bashGuardFile = pkgs.writeText "bash-guard.ts" bashGuardSource;

      appendSystemFile = pkgs.writeText "pi-append-system.md" config.programs.harness.appendShared;
    in
    {
      config = {

        assertions = [
          {
            assertion = piExtensionDeps."@cortexkit/aft-pi" == config.programs.harness.aftVersion;
            message = "piExtensionDeps in pi.nix pins @cortexkit/aft-pi to a version other than programs.harness.aftVersion";
          }
        ];

        programs.harness.configFiles = {
          pi-settings = settingsSeedFile;
          pi-mcp = mcpJsonFile;
          pi-keybindings = keybindingsJsonFile;
          pi-permissions = permissionConfigFile;
          pi-fff = fffJsonFile;
          aft = aftJsonFile;
        };

        home.packages = [
          pkgs-unstable.pi-coding-agent
          piStats
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
          LLAMA_BASE_URL = config.programs.harness.localModelUrl;
          # каждый gopls поднимает дочерний telemetry-процесс, отключаем
          GOTELEMETRY = "off";
        };

        home.file.".pi/agent/agents/worker.md".text = ''
          ---
          name: worker
          description: general-purpose subagent for a focused task
          tools: read, grep, find, ls, bash, edit, write, aft_search, aft_outline, aft_zoom, lsp_diagnostics
          spawning: false
          auto-exit: true
          system-prompt: append
          ---
          You are worker, a general-purpose subagent started by another agent. The first user message is your task and the only context you get.

          Do the task. If it changes files, run the narrowest check that proves the change (build, test or lint) before finishing. Never ask the user questions: if the task is ambiguous, pick the smallest reasonable interpretation and state it in your answer.

          Your final message is the only thing the caller sees. At most 40 lines: the result first, then one line per change or finding with its path:line, and how it was verified. Do not paste file contents or tool output.
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

        home.file.".pi/agent/models.json".source = modelsJsonFile;
        home.file.".pi/agent/keybindings.json".source = keybindingsJsonFile;
        home.file.".pi/agent/mcp.json".source = mcpJsonFile;
        home.file.".pi/agent/APPEND_SYSTEM.md".source = appendSystemFile;
        home.file.".pi/agent/extensions/protei-auto.ts".source = proteiAutoFile;
        home.file.".pi/agent/extensions/todo-reminder.ts".source = todoReminderFile;
        home.file.".pi/agent/extensions/gates.ts".source = gatesFile;
        home.file.".pi/agent/extensions/bash-guard.ts".source = bashGuardFile;
        home.file.".pi/agent/extensions/pi-fff.json".source = fffJsonFile;
        home.file.".pi/agent/extensions/pi-permission-system/config.json".source = permissionConfigFile;

        xdg.configFile."cortexkit/aft.jsonc".source = aftJsonFile;

        home.activation.setupPi = mkAfter /* bash */ ''
          set -euo pipefail

          settings="${piAgentDir}/settings.json"

          mkdir -p "${piAgentDir}"
          if [[ -f "$settings" ]]; then
            "${lib.getExe pkgs.jq}" --slurpfile seed "${settingsSeedFile}" '. * $seed[0]' "$settings" > "$settings.tmp"
            mv "$settings.tmp" "$settings"
          else
            install -m644 "${settingsSeedFile}" "$settings"
          fi
        '';
      };
    };
}
