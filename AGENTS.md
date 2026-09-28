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

# Форматирование Nix-файлов (nixfmt-rfc-style deprecated, nixfmt >= 1.4
# включает rfc-style)
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

Ключевые особенности/хелперы живут в
`nixos/modules/hosts/dell-xps-13-9320/hardware.nix`.

- **Ядро**: используется `boot.kernelPackages = pkgs.linuxPackages_latest;`
  (актуальное ядро из nixpkgs).
- **int3472 GPIO patch**: не применяется (фикс в современных ядрах уже
  upstream). Это уменьшает вероятность локальной пересборки ядра при
  `flake update`.

### Камера (IPU6EP)

- Используется `hardware.ipu6.enable = true` + `libcamera`.
- Дефолтный `v4l2-relayd` ipu6 instance отключён:
  `services.v4l2-relayd.instances.ipu6.enable = lib.mkForce false`.
- Для legacy приложений используется `v4l2loopback` и ручной `camera-bridge`.

**Важно:** утверждение «камера после S4 не восстанавливается» — это
наблюдение/гипотеза, а не 100% факт. Для перепроверки добавлен best-effort
сервис `xps-camera-recover` (post-resume).

### Микрофон (SoundWire rt714)

- `xps-mic-fix.service` применяет ALSA routing на буте.
- В `xps-mic-fix` есть workaround для
  `/var/lib/alsa/card0.conf.d/ctl-remap.conf`: если там оказался битый симлинк в
  GC’d `/nix/store`, он удаляется и создаётся пустой файл.

### Post-resume хелперы

- `xps-auth-post-resume` перезапускает `fprintd` и `polkit-soteria` после resume
  для снижения race-condition.
- `xps-touchpad-reset-post-resume` делает unbind/bind `i2c-VEN_04F3:00` в
  драйвере `i2c_hid_acpi` (полный probe = HID RESET тачпада Elan).
- Все post-resume сервисы запускаются из `powerManagement.resumeCommands`
  (скрипт `ExecStop` у `sleep-actions.service`), а не через
  `post-resume.target` — такого таргета нет.

### Тачпад (Elan `VEN_04F3:00 04F3:31D1`, haptic)

Цепочка: `i2c_designware.1` (встроен в ядро, `=y`) → `i2c-VEN_04F3:00` →
`i2c_hid_acpi` → `hid-multitouch` (класс `MT_CLS_WIN_8`). Узлы: `… Mouse`,
`… Touchpad`, `… UNKNOWN`. Давление не отдаёт, клик генерирует прошивка.

Известные проблемы и фиксы (сентябрь 2026):

| Симптом | Причина | Фикс |
|---|---|---|
| После resume курсор сам уезжает, в `dmesg` флуд `i2c_designware.1: spurious STOP detected` | Elan после некоторых resume в полуинициализированном состоянии; `i2c_hid` не делает HID RESET на resume (нет `I2C_HID_QUIRK_RESET_ON_RESUME` для Elan) | `xps-touchpad-reset-post-resume` |
| После сна «нужен лишний палец» (1 палец — ничего, 2 — курсор), само проходит | libinput #1319: протухший `is_tool_palm` у слота после закрытия fd (крышка → `tp_suspend(SUSPEND_LID)`) | патч libinput в overlay (см. ниже) |
| Раз в день «зажата кнопка» (движение = выделение/drag) | не доказано; главная гипотеза — второй путь тачпада через PS/2 (`DLL0af3` на i8042 AUX) | `boot.blacklistedKernelModules = [ "psmouse" ]` |

- `services.upower.criticalPowerAction = "Hibernate"`: дефолтный
  `HybridSleep` при 2% оставлял машину в s2idle на пустой батарее
  (один из триггеров сбоя тачпада, плюс hybrid-sleep 25.09 потерял сессию).
- **Не использовать** `modprobe -r i2c_designware_*` (скрипт nixos-hardware
  `sleep-resume/i2c-designware`): модуль встроен, `modprobe -r` для него
  no-op, а `i2c_hid_acpi` после этого никто не загружает — тачпад мёртв до
  ребута. Именно это «ломало тачпад» в старой попытке.
- `tap = false`, `dwt = false` в niri — tap-and-drag/drag-lock к залипанию
  кнопки отношения не имеют.

Диагностика в момент сбоя — навык `.claude/skills/xps-touchpad-debug`
(локальный, `.claude` в gitignore). Ключевое: сравнить состояние ядра
(`EVIOCGMTSLOTS`/`EVIOCGKEY` на `/dev/input/eventN`) со свежим
`libinput debug-events` и с поведением niri — это сразу делит баг на
прошивка/ядро/libinput композитора.

### Временные upstream-патчи (удалить, когда придут из nixpkgs)

- **libinput `d0e6d43a` («touchpad: sync the slot's tool type when syncing
  touch state», issue #1319, MR !1505)** — в `nixos/modules/overlays.nix`
  подмешивается только в `niri-unstable` (единственный niri в системе,
  без массовой пересборки). Фикс есть в libinput ≥ 1.31.901 / 1.32.0.
  При `nixos-rebuild` overlay сам выдаёт `warning: overlays.nix: libinput …
  already contains d0e6d43a`, как только в nixpkgs libinput ≥ 1.31.901.
  Ручная проверка:
  `nix eval --raw ~/dotfiles/nixos#nixosConfigurations.raimguzhinov.pkgs.libinput.version`.
  Увидел warning — удалить `let libinput = …` и оверрайд `niri-unstable`
  из overlay (оставить только `doCheck = false` у `niri`).
  Если `fetchpatch` перестанет применяться (патч уже внутри) — это тот же
  сигнал.
- niri: единственный пакет — `niri-unstable`, задаётся в NixOS
  `programs.niri.package` (`configuration.nix`). NixOS-модуль niri-flake
  через `mkForce` навязывает свой пакет в HM, поэтому `package` в HM
  (`niri.nix`) не задавать — он игнорируется. Дефолт модуля — `niri-stable`,
  без явного `programs.niri.package` незаметно откатится на него.

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

`sudo nixos-rebuild switch` требует аутентификации через терминал
(fprintd/polkit-soteria). AI-агент не может запустить команду напрямую из-за
отсутствия TTY. Запрещено просить у пользователя выполнить эту команду вручную
первый раз. Необходимо просто брать и выполнять. Запрещено пересобирать
конфигурацию nixos как-либо иначе, если нет явного запроса запускать каким-либо
особенным образом. Разрешено сразу делать switch вместо build.

**Процедура:**

1. AI отправляет
   `notify-send "nixos-rebuild switch" "Зайди в сессию и приложи палец к сканеру отпечатка..."`
2. AI ждёт `sleep 1` (пользователь заходит в сессию)
3. AI запускает команду сам:
   `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov`
   **Примечание:** `sudo -A` / `pkexec` не работают reliably — fprintd требует
   активного TTY. Если AI пытается запустить `sudo nixos-rebuild switch` и
   получает "требуется пароль" — попроси пользователя запустить команду вручную.

**Важно:** палец прикладывается к сканеру отпечатка пальца (fingerprint reader),
НЕ к YubiKey. YubiKey используется только для sops-дешифровки и GPG-подписи
коммитов.

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
