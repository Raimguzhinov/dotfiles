# AGENTS.md

Инструкции для AI-агентов (opencode / Claude Code / и т.п.) при работе с этим
репозиторием.

## Быстрые команды

```bash
# Применить конфигурацию (основная команда)
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov

# Собрать без применения (проверка)
sudo nixos-rebuild build --flake ~/dotfiles/nixos#raimguzhinov

# Собрать и запустить виртуальную машину (GL-дисплей)
sudo nixos-rebuild build-vm --flake ~/dotfiles/nixos#raimguzhinov
./result/bin/run-raimguzhinov-vm -device virtio-vga-gl -display gtk,gl=on

# Форматирование Nix-файлов
nixfmt nixos/
```

## Архитектура конфигурации

Точка входа — `nixos/flake.nix`. Используется flake-parts + import-tree: все
`.nix` из `nixos/modules/` подхватываются автоматически, кроме путей с `/_`.

**flake.nix (схема):**

```nix
outputs = inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./modules);
```

- `import-tree` рекурсивно импортирует все `.nix` из `modules/`, исключая `/_`.
- Каждый `.nix` в `modules/` — flake-parts модуль.

**Структура модулей** (упрощённо):

```
nixos/
  flake.nix
  secrets.yaml / .sops.yaml
  modules/
    parts.nix
    hosts/
      dell-xps-13-9320/
        default.nix
        configuration.nix
        hardware.nix
        overlays.nix
        _disko.nix
        install.nix
    overlays.nix
    features/
      tools.nix development.nix git.nix neovim.nix niri.nix noctalia.nix
      rofi.nix chromium.nix zen-browser.nix jetbrains.nix zed-editor.nix
      thunderbird.nix claude.nix sops.nix gaming.nix
    devshells/
      go.nix
      python.nix
```

### Глобальные overlays

- `nixos/modules/overlays.nix` — общий nixos-модуль, который добавляет
  `nixpkgs.overlays` и `allowUnfree` для всех хостов.
- `nixos/modules/hosts/dell-xps-13-9320/overlays.nix` удалён (исторический
  файл); оверлеи живут в глобальном модуле.

### Паттерн feature-модуля

Каждый файл в `nixos/modules/features/*.nix` одновременно:

- добавляет `perSystem.packages.NAME` — standalone пакет/сборка,
- добавляет `flake.homeModules.NAME` — HM-модуль (подключается в хостовом
  `configuration.nix`).

### Linux-only perSystem

В `perSystem` не использовать `pkgs.stdenv.isLinux` (может вызвать рекурсию).
Использовать `system` + `builtins.elem`.

## Соглашения

- Десктопные пакеты — в `home.packages` пользователя `dias`, не в
  `environment.systemPackages`.
- Исключение для `environment.systemPackages`: то, что требует polkit на
  системном уровне.
- Коммиты только по явной просьбе.
- **Префикс сообщения коммита — строго `nixos:` и никак иначе.**
- Коммиты должны быть подписаны (GPG signing включён): не использовать
  `--no-gpg-sign`/`--no-gpg-sign`. Если подпись не проходит (нет YubiKey/PIN
  prompt), остановиться и попросить пользователя запустить коммит локально.
- Стиль `inherit` в атрсетах: каждый аргумент на отдельной строке
  (`inherit foo;`).

## Dell XPS 13 Plus 9320 (dell-xps-13-9320)

Железо (камера, микрофон, swap, PAM, тачпад, временные upstream-патчи):
`docs/agents/xps-hardware.md`. Два запрета, которые встречают сразу: не
rebind тачпада i2c-устройства и не `modprobe -r i2c_designware_*`.

## Direnv / nix-direnv

В `nixos/modules/features/development.nix` генерируется `~/Work/.envrc`.

- Для обхода проблемы `eval-cache ... sqlite is busy` eval-cache отключается
  только локально: `export NIX_CONFIG="eval-cache = false"` внутри
  `~/Work/.envrc`.

## SOPS / YubiKey

- Секреты управляются `sops-nix`.
- User unit `sops-nix.service` настроен так, чтобы:
  - запускаться после поднятия сессии (`graphical-session.target`),
  - не уходить в бесконечные ретраи при отсутствии YubiKey,
  - но при наличии YubiKey иметь шанс показать PIN prompt (через
    `Restart=on-failure` + rate-limit).

### nixos-rebuild switch workflow

`sudo nixos-rebuild switch` требует аутентификации через сканер отпечатка
(fprintd/polkit-soteria). Запускать команду самостоятельно, без просьб к
пользователю; switch допустим сразу вместо build. Конфигурацию nixos не
пересобирать иначе, если нет явного запроса запускать особым образом.

**Процедура:**

1. AI отправляет
   `notify-send "nixos-rebuild switch" "Зайди в сессию и приложи палец к сканеру отпечатка..."`
2. AI ждёт `sleep 1` (пользователь заходит в сессию)
3. AI запускает команду сам:
   `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov`
   При "требуется пароль" (fprintd не сработал): повторить процедуру с новым
   notify-send; если и второй раз не прошёл — попросить пользователя запустить
   команду вручную.

**Важно:** палец прикладывается к сканеру отпечатка пальца, не к YubiKey.
YubiKey используется только для sops-дешифровки и GPG-подписи коммитов.

## NVF (Neovim)

- nvf работает как standalone решение через flake-parts: конфигурация
  генерируется в `/nix/store` и подключается через `$NVIM_APPNAME="nvf"`
  (runtimepath указывает на `/nix/store/...-mnw-configDir`).
- Конфиг не lives в `~/.config/nvf/` — это архитектурное решение.
- Проверка: `nvf-print-config` показывает сгенерированный Lua-конфиг.
- LSP маппинги привязываются через `LspAttach` autocmd (nvf 0.9+).
- Дефолтные маппинги: `<leader>lgd` — go to definition, `<leader>lh` — hover,
  `<leader>lS` — document symbols.
- nvim-cmp `<Tab>` по умолчанию: select_next + auto-complete. Для confirm без
  select: переопределить через `setupOpts.mapping`.

### Стандарты редактирования `neovim.nix`

Впредь любые правки `nixos/modules/features/neovim.nix` вести по этим
правилам:

- **Декларативность прежде Lua.** Перед тем как писать сырой Lua (`pluginRC`,
  `lazy.plugins.*.after`, ручной `vim.lsp.config`/`vim.lsp.enable` в
  autocmd), проверить исходники nvf (store-путь инпута `nvf` из
  `nix flake archive`) на предмет готовой декларативной опции — например
  `vim.lsp.servers.<name>` вместо ручного `vim.lsp.config`, `vim.lsp.mappings`
  вместо ручных `keymaps` на `vim.lsp.buf.*`, `vim.autocomplete.nvim-cmp.mappings`
  вместо патчинга `cmp.get_config()`, `vim.languages.<lang>.extraDiagnostics`
  вместо ручного `require("lint")`. Обязательно свериться через **context7**
  (`/notashelf/nvf` и соответствующий neovim-плагин) — версии/API меняются,
  доверять памяти нельзя.
- **Комментарии — минимум.** Только для действительно неочевидного: обход
  бага апстрима, порядок инициализации, который иначе сломается, причина,
  почему код похож на мёртвый, но им не является (например, коллизия
  дефолтных маппингов между плагинами). Максимум 1-2 строки, без пересказа
  того, что и так видно из кода или имени опции. Если комментарий не мешает
  убрать его — значит, он не нужен.
- **Подсветка встроенного кода.** Каждый непустой `''...''`-блок (Lua через
  `mkLuaInline`, bash/json/markdown и т.п.) должен иметь маркер языка прямо
  перед открывающими кавычками — так `nvim-treesitter`'s comment-based
  injection (`# <lang>` → `injection.language`) подсвечивает синтаксис:
  ```nix
  on_init =
    lib.generators.mkLuaInline # lua
      ''
        function(client) ... end
      '';
  ```
  Ставить маркер только если это реальный, установленный в конфиге
  treesitter-grammar (см. `vim.treesitter.grammars`/`languages.*.enable`), а
  не самодельный DSL или plaintext-формат без грамматики.
- **Проверка headless перед тем как считать фикс готовым.** Гонять
  `nvim --headless` на реальных файлах пользователя, а не полагаться на то,
  что код «выглядит правильно» (см. `feedback_verify_and_revert_dead_fixes`
  в памяти).
- После правок обязательно прогонять `nixfmt` по изменённому файлу.

## Polkit

- Используется `soteria` как polkit authentication agent (это не замена
  gnome-keyring и не замена PAM).

## aft (code intelligence)

- Общий для pi и opencode. Версия: `programs.harness.aftVersion`
  (`harness.nix`).
- Проводка: pin и `aftConfig` в `pi.nix`, плагин и warm-up кэша в
  `opencode.nix`.
- Бинарник не из Nix, а из npm-пакетов (кэш `~/.cache/aft/bin/`).
  Индексы общие: `~/.local/share/cortexkit/aft/`, конфиг
  `~/.config/cortexkit/aft.jsonc`.
- «Обновление» при запуске это пересборка индекса, не апгрейд софта.

## Общие MCP-серверы

Пакет и аргументы в `programs.harness.*` (`harness.nix`), запись на клиента
в `pi.nix` / `opencode.nix` / `claude.nix` (у каждого своя схема: pi/claude
— `command` + `args`, opencode — список `command`).

## Мелкие правки

- Сделать правку внимательно, затем внимательно отревьюить `git diff`:
  нет дублей, отступы и синтаксис верны, изменено только то, что просили.
- После правок `nixos/` текущего хоста дефолтная проверка —
  `nixos-rebuild build` (без sudo, без применения). `switch`, `nix build`
  и сборка других веток/хостов — только по явной просьбе: они для другой
  машины.
- Если команду прервали, она могла выполниться частично: сначала смотреть
  `git diff`, потом повторять.
- flake.lock меняется только nix: `nix flake lock` /
  `nix flake lock --update-input NAME`.
- home.activation скрипты с внешними бинарниками или сетью: провал команды
  логируется WARNING и activation продолжается, set -e только для чисто
  файловых операций.
- Чтение `~/.pi` и `~/.config` — инструментами read/grep, не bash:
  guardrails home-dot-readonly блокирует bash-доступ к этим путям.
- Для чтения файлов GitHub (raw/blob URL) — `gh` CLI или gh_grep MCP:
  URL-инструменты (aft_outline, web_url_read searxng) блокируют хосты GitHub.
- Визуальные правки (цвета, layout): после второй неудачной итерации
  отрендерить текущий вывод (ANSI) в файл и свериться по рендеру, а не
  гадать по формулировке.
- Если сборку блокирует ошибка внутри внешнего flake-инпута (upstream):
  сначала проверить, нужна ли зависимость текущему изменению; если нужна —
  наша конфигурация не причём: не копать исходники зависимости и не
  собирать костыли (override, локальные патчи, перепин хешей). Отчитаться
  пользователю с вариантами: обновить вход, ждать фикс, отказаться.

## Параллельные задачи

- Несколько задач сразу: гарантированные делаю сам, не уверенные —
  сабагентам (один сабагент на задачу, своя сессия).
- В промпте сабагента указать, что другие агенты параллельно правят
  репозиторий: перед каждой правкой перечитать актуальное состояние файла
  и посмотреть `git status`, опираться на снимок с начала сессии нельзя.
- Задача уперлась в внешний блок: после двух попыток — одна строка с
  вариантами пользователю и переход к следующей задаче.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `Raimguzhinov/dotfiles` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary, label strings equal to role names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
