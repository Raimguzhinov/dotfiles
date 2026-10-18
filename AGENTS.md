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
nixfmt nixos/modules/
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
- Сообщение коммита на английском, формат `nixos: <файл>: описание`; и язык, и формат проверяет commit-msg хук (scripts/check_commit_msg.sh).
- Если GPG-подпись не проходит (нет YubiKey/PIN prompt), остановиться и
  попросить пользователя запустить коммит локально.
- Issue с комментарием, ссылающимся на коммит, закрывать только после
  пуша этого коммита.
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

- Секреты управляются `sops-nix`. Рендер секрета: файл
  `~/.config/sops-nix/secrets/<имя>`, Nix-значение
  `config.sops.secrets.<имя>.path`.
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

Правки `nixos/modules/features/neovim.nix` вести по правилам из
`docs/agents/neovim-nix.md`.

## Polkit

- Используется `soteria` как polkit authentication agent (это не замена
  gnome-keyring и не замена PAM).

## aft (code intelligence)

- Общий для pi и opencode. Версия: `programs.harness.aftVersion`
  (`harness.nix`).
- Проводка: pin и `aftConfig` в `pi.nix`, плагин в `opencode.nix`.
- Бинарник не из Nix, а из npm-пакетов (кэш `~/.cache/aft/bin/`).
  Индексы общие: `~/.local/share/cortexkit/aft/`, конфиг
  `~/.config/cortexkit/aft.jsonc`.
- «Обновление» при запуске это пересборка индекса, не апгрейд софта.

## Общие MCP-серверы

Пакет и аргументы в `programs.harness.*` (`harness.nix`), запись на клиента
в `pi.nix` / `opencode.nix` / `claude.nix` (у каждого своя схема: pi/claude
— `command` + `args`, opencode — список `command`).

## Модель прав

Операции классифицируются по ADR-0006: read-only проходит, разрушительное блокируется с причиной, среднее в pi проходит без вопроса (yoloMode), в opencode спрашивает. Источник правил — `programs.harness.permissions` (`harness.nix`); pi рендерит `config.json` для `@gotgenes/pi-permission-system`, opencode — нативную permission-карту.

- bash: read-only и git проходят.
- Блокируется: рекурсивный rm и `find -delete` (удаление делает пользователь), `git checkout/restore/stash drop/branch -D/reset --hard`, force-push, `mkfs`, `dd` в /dev.
- Секреты запрещены читать и писать (.env, ~/.ssh, ~/.gnupg, ключи, *.pem, дампы).
- Только-чтение (запись запрещена, чтение свободно): ~/.pi, ~/.config, лок-файлы, артефакты сборки, мета-файлы (README, .git, CI, Dockerfiles).

## Мелкие правки

- Удаление каталогов, которое система прав отклоняет (рекурсивный rm, find -delete), выполняет пользователь: спросить, а не обходить.
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
- Запись в `~/.pi` и `~/.config` запрещена (пишут pi.nix и opencode.nix): меняй декларативный конфиг, а не файлы. Чтение свободно.
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
