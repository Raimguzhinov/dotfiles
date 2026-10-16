# Общий харнесс агентов (pi, claude-code, opencode): единый store скиллов
# ~/.agents/skills и общий фрагмент system prompt. Агент-специфика остаётся
# в своих модулях (pi.nix, claude.nix, opencode.nix).
{ inputs, ... }:
{
  flake.homeModules.harness =
    {
      config,
      lib,
      pkgs,
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

      sharedAppend = pkgs.writeText "agents-append-shared.md" /* markdown */ ''
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
        type = lib.types.path;
        default = sharedAppend;
        description = "Common system-prompt fragment shared by all agents";
      };

      options.programs.harness.aftVersion = lib.mkOption {
        type = lib.types.str;
        default = "0.59.0";
        description = "aft version shared by pi and opencode, both write the same storage";
      };

      options.programs.harness.magicContextVersion = lib.mkOption {
        type = lib.types.str;
        default = "0.49.2";
        description = "magic-context version shared by pi and opencode, both write the same store";
      };

      options.programs.harness.codebaseMemory = lib.mkOption {
        type = lib.types.package;
        # non-UI: UI-сборка тянет graph-ui, у которого протух npmDepsHash
        default = inputs.codebase-memory-mcp.packages.${pkgs.stdenv.hostPlatform.system}.default;
        description = "codebase-memory-mcp package shared by pi, opencode and claude-code";
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
