# AGENTS.md

Инструкции для AI-агентов (opencode / Claude Code / и т.п.) при работе с этим репозиторием.

## Быстрые команды

```bash
# Применить конфигурацию (основная команда)
sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov

# Собрать без применения (проверка)
sudo nixos-rebuild build --flake ~/dotfiles/nixos#raimguzhinov

# Собрать и запустить виртуальную машину (GL-дисплей)
sudo nixos-rebuild build-vm --flake ~/dotfiles/nixos#raimguzhinov
./result/bin/run-raimguzhinov-vm -device virtio-vga-gl -display gtk,gl=on

# Форматирование Nix-файлов (если установлен)
# nixfmt-rfc-style nixos/
```

## Архитектура конфигурации

Точка входа — `nixos/flake.nix`. Используется flake-parts + import-tree:
все `.nix` из `nixos/modules/` подхватываются автоматически, кроме путей с `/_`.

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

- `nixos/modules/overlays.nix` — общий nixos-модуль, который добавляет `nixpkgs.overlays` и `allowUnfree` для всех хостов.
- `nixos/modules/hosts/dell-xps-13-9320/overlays.nix` удалён (исторический файл); оверлеи живут в глобальном модуле.

### Паттерн feature-модуля

Каждый файл в `nixos/modules/features/*.nix` одновременно:
- добавляет `perSystem.packages.NAME` — standalone пакет/сборка,
- добавляет `flake.homeModules.NAME` — HM-модуль (подключается в хостовом `configuration.nix`).

### Linux-only perSystem

В `perSystem` не использовать `pkgs.stdenv.isLinux` (может вызвать рекурсию).
Использовать `system` + `builtins.elem`.

## Соглашения

- Десктопные пакеты — в `home.packages` пользователя `dias`, не в `environment.systemPackages`.
- Исключение для `environment.systemPackages`: то, что требует polkit на системном уровне.
- Коммиты только по явной просьбе.
- Коммиты должны быть подписаны (GPG signing включён): не использовать `--no-gpg-sign`/`--no-gpg-sign`.
  Если подпись не проходит (нет YubiKey/PIN prompt), остановиться и попросить пользователя запустить коммит локально.
- Стиль `inherit` в атрсетах: каждый аргумент на отдельной строке (`inherit foo;`).

## Dell XPS 13 Plus 9320 (dell-xps-13-9320)

Ключевые особенности/хелперы живут в `nixos/modules/hosts/dell-xps-13-9320/hardware.nix`.

- **Ядро**: используется `boot.kernelPackages = pkgs.linuxPackages_latest;` (актуальное ядро из nixpkgs).
- **int3472 GPIO patch**: не применяется (фикс в современных ядрах уже upstream). Это уменьшает вероятность локальной пересборки ядра при `flake update`.

### Камера (IPU6EP)

- Используется `hardware.ipu6.enable = true` + `libcamera`.
- Дефолтный `v4l2-relayd` ipu6 instance отключён: `services.v4l2-relayd.instances.ipu6.enable = lib.mkForce false`.
- Для legacy приложений используется `v4l2loopback` и ручной `camera-bridge`.

**Важно:** утверждение «камера после S4 не восстанавливается» — это наблюдение/гипотеза, а не 100% факт.
Для перепроверки добавлен best-effort сервис `xps-camera-recover` (post-resume).

### Микрофон (SoundWire rt714)

- `xps-mic-fix.service` применяет ALSA routing на буте.
- В `xps-mic-fix` есть workaround для `/var/lib/alsa/card0.conf.d/ctl-remap.conf`:
  если там оказался битый симлинк в GC’d `/nix/store`, он удаляется и создаётся пустой файл.

### Post-resume хелперы

- `xps-auth-post-resume` перезапускает `fprintd` и `polkit-soteria` после resume для снижения race-condition.

## Direnv / nix-direnv

В `nixos/modules/features/development.nix` генерируется `~/Work/.envrc`.

- Для обхода проблемы `eval-cache ... sqlite is busy` eval-cache отключается только локально:
  `export NIX_CONFIG="eval-cache = false"` внутри `~/Work/.envrc`.

## SOPS / YubiKey

- Секреты управляются `sops-nix`.
- User unit `sops-nix.service` настроен так, чтобы:
  - запускаться после поднятия сессии (`graphical-session.target`),
  - не уходить в бесконечные ретраи при отсутствии YubiKey,
  - но при наличии YubiKey иметь шанс показать PIN prompt (через `Restart=on-failure` + rate-limit).

### nixos-rebuild switch workflow

`sudo nixos-rebuild switch` требует аутентификации через терминал (fprintd/polkit-soteria).
AI-агент не может запустить команду напрямую из-за отсутствия TTY.

**Процедура:**
1. AI отправляет `notify-send "nixos-rebuild switch" "Зайди в сессию и приложи палец к сканеру отпечатка..."`
2. AI ждёт `sleep 3` (пользователь заходит в сессию)
3. Пользователь запускает команду вручную: `sudo nixos-rebuild switch --flake ~/dotfiles/nixos#raimguzhinov`

**Примечание:** `sudo -A` / `pkexec` не работают reliably — fprintd требует активного TTY.
Если AI пытается запустить `sudo nixos-rebuild switch` и получает "требуется пароль" —
попроси пользователя запустить команду вручную.

**Важно:** палец прикладывается к сканеру отпечатка пальца (fingerprint reader), НЕ к YubiKey.
YubiKey используется только для sops-дешифровки и GPG-подписи коммитов.

## NVF (Neovim)

- nvf работает как standalone решение через flake-parts: конфигурация генерируется в `/nix/store` и подключается через `$NVIM_APPNAME="nvf"` (runtimepath указывает на `/nix/store/...-mnw-configDir`).
- Конфиг не lives в `~/.config/nvf/` — это архитектурное решение.
- Проверка: `nvf-print-config` показывает сгенерированный Lua-конфиг.
- LSP маппинги привязываются через `LspAttach` autocmd (nvf 0.9+).
- Дефолтные маппинги: `<leader>lgd` — go to definition, `<leader>lh` — hover, `<leader>lS` — document symbols.
- nvim-cmp `<Tab>` по умолчанию: select_next + auto-complete. Для confirm без select: переопределить через `setupOpts.mapping`.

## Polkit

- Используется `soteria` как polkit authentication agent (это не замена gnome-keyring и не замена PAM).
