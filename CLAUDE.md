# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Применение конфигурации

```bash
# Применить конфигурацию (основная команда)
sudo nixos-rebuild switch --flake ~/dotfiles/nixos

# Собрать без применения (проверка)
sudo nixos-rebuild build --flake ~/dotfiles/nixos

# Собрать и запустить виртуальную машину (GL-дисплей)
sudo nixos-rebuild build-vm --flake ~/dotfiles/nixos
./result/bin/run-raimguzhinov-vm -device virtio-vga-gl -display gtk,gl=on

# Форматирование Nix-файлов
nixfmt-rfc-style nixos/
```

## Архитектура конфигурации

Точка входа — `nixos/flake.nix`. Определяет один хост `raimguzhinov` (x86_64-linux) и подключает все inputs.

**flake.nix:**
- `outputs = { self, nixpkgs, ... }@inputs:` — минимальная деструктуризация, остальное через `inputs.`
- `specialArgs = { inherit inputs hostname username version; pkgs-unstable = ...; }` — передаёт в модули
- `version`, `hostname`, `username` — let-переменные, используются в `system.stateVersion` и HM
- `pkgs-unstable` — создаётся через `import nixpkgs-unstable { config.allowUnfree = true; }` в specialArgs
- Скрипт установки вынесен в `install.nix`

**Слои конфигурации:**
- `configuration.nix` — системный уровень: загрузчик, сервисы, сетевые настройки, системные пакеты, Home Manager для пользователей `root` и `dias`
- `overlays.nix` — оверлеи nixpkgs + `nixpkgs.config.allowUnfree = true` для системного pkgs
- `install.nix` — скрипт установки на новое железо (импортируется в flake.nix)

**Модули Home Manager пользователя `dias`** (все импортируются в `configuration.nix`):
- `tools.nix` — zsh, git, delta, zoxide, atuin, zellij, yazi (`rr`), bat, eza, starship, lazygit, pgcli, fd, fzf, ripgrep
- `development.nix` — direnv + nix-direnv, Go devshell активация (записывает `~/Work/flake.nix` и `~/Work/.envrc`), вспомогательные shell-скрипты (ssh-setup-dlv, ssh-run-debugger, tracktime и др.)
- `neovim.nix` — nvf (Neovim framework), LSP для Go/Nix/Python/Bash/YAML/Markdown
- `niri.nix` — Wayland compositor niri: раскладки, биндинги клавиш, правила окон, автозапуск
- `noctalia.nix` — noctalia-shell (панель/уведомления)
- `rofi.nix` — лаунчер приложений
- `chromium.nix`, `zen-browser.nix` — браузеры с расширениями
- `jetbrains.nix` — JetBrains IDE (pkgs-unstable)
- `zed-editor.nix` — Zed editor
- `sops.nix` — sops-nix секреты (GPG/YubiKey): github_token, youtrack/*, git/private, product/services-root

**Модули Home Manager пользователя `root`**: `neovim.nix`, `tools.nix`

**Go devshell** (`go-devshell.nix`): флейк для `~/Work/` с Go 1.21, gopls, delve, protobuf, grpc-gen. `libwebp.dev`/`libwebp.out` используются напрямую через Nix-интерполяцию в shellHook (`${pkgs.libwebp.dev}`, `${pkgs.libwebp.out}`).

## Ключевые соглашения

- Десктопные пакеты — в `home.packages` пользователя `dias`, НЕ в `environment.systemPackages`
- `rr` — обёртка yazi: `programs.yazi.shellWrapperName = "rr"` даёт shell-функцию с поддержкой `cd`; плюс `writeShellScriptBin "rr"` в `home.packages` как реальный бинарник для `sudo rr` (sudo не видит shell-функции)
- `pkgs.replaceVars` вместо `pkgs.substituteAll` (убран в nixpkgs 25.11)
- Активация dev-окружения (`~/Work/flake.nix`, `~/Work/.envrc`) пишет файлы только при изменении содержимого (`diff -q`) — иначе nix-direnv инвалидирует кэш
- Формат коммитов: `nixos: <сообщение>`; после каждого коммита обновить `CLAUDE.md` при необходимости (изменились соглашения, архитектура, ключевые решения)
- Стиль `inherit` в атрсетах: каждый аргумент на отдельной строке (`inherit foo;` / `inherit bar;`), НЕ группировать в одну строку (`inherit foo bar;`)
- `pkgs-unstable` доступен в HM модулях через `extraSpecialArgs = { inherit pkgs-unstable; }` в configuration.nix
- `alias sudo='sudo '` в shellAliases — позволяет sudo видеть shell-алиасы; `security.sudo.extraConfig` с `env_keep += "PATH"` — для бинарей в пользовательском PATH

## Секреты (sops-nix)

- `nixos/.sops.yaml` — GPG fingerprint YubiKey, path_regex: `secrets\.yaml$`
- `nixos/secrets.yaml` — зашифрованный файл секретов
- `nixos/sops.nix` — HM модуль: объявление секретов и их использование в zsh/git
- `sops-nix.homeManagerModules.sops` подключён через `home-manager.sharedModules`
- Секреты: `github_token`, `youtrack/url`, `youtrack/token`, `git/private`, `product/services-root`, `pass-store/clone-cmd`
- `pass-store/clone-cmd` — команда клонирования приватного репо паролей, показывается в zsh при отсутствии `~/.password-store`
- Секреты загружаются лениво через `precmd` хук (`_sops_load_secrets`), только если файл существует и `$SOPS_SECRETS_LOADED` не выставлен — избегает ошибок при старте без YubiKey
- `sops-nix.service` настроен `After/Wants gpg-agent.service` + `Restart=on-failure` — автоповтор при первом запуске без YubiKey
- Редактировать секреты: `sops ./secrets.yaml` (YubiKey PIN)
- На первой загрузке без YubiKey HM activation падает — вставить YubiKey и повторить rebuild

## Установка на новое железо

```bash
# С LiveCD NixOS — одна команда:
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:Raimguzhinov/dotfiles?dir=nixos#install
```

Скрипт (`nixos/install.nix`, доступен как `apps.x86_64-linux.install`) делает:
1. Спрашивает диск, запускает `disko --mode destroy,format,mount` с `nixos/disko.nix`
2. Генерирует `hardware-configuration.nix`
3. Клонирует репо в `/mnt/home/dias/dotfiles`, копирует hw-config туда
4. Запускает `nixos-install --flake .../nixos#raimguzhinov --no-root-passwd`
5. Через `nixos-enter` предлагает задать пароль `dias`

## Disko (разметка диска)

`nixos/disko.nix` — NixOS-модуль И standalone-конфиг (параметр `disk ? "/dev/disk/by-diskseq/1"`):
- GPT: ESP 512M (vfat, /boot) + swap 32G (resumeDevice=true) + LUKS2 остаток → btrfs
- btrfs subvolumes: `/root`→/, `/home`→/home, `/nix`→/nix
- Swap вне LUKS — для простой гибернации без вычисления resume_offset
- LUKS: интерактивный ввод пароля, allowDiscards=true
- Параметр `disk` нужен только при форматировании (disko CLI), для работающей системы не важен

## Бинарные кэши

Настроены в `nix.settings` (`configuration.nix`):
- `cache.nixos.org` — основной
- `niri.cachix.org` — compositor niri
- `notashelf.cachix.org` — noctalia и др.
- `nix-community.cachix.org` — nvf, sops-nix и др.

## Inputs flake

| Input | Назначение |
|---|---|
| `nixpkgs` | nixos-25.11 |
| `nixpkgs-unstable` | нестабильные пакеты (jetbrains, telegram, amnezia-vpn) |
| `niri` | Wayland compositor + оверлей |
| `nvf` | Neovim framework |
| `claude-code` | Claude Code CLI |
| `max-messanger` | корпоративный мессенджер |
| `niri-float-sticky` | плагин niri |
| `zen-browser` | Zen Browser (beta) |
| `firefox-addons` | расширения для браузеров |
| `noctalia` | shell/панель/уведомления |
| `disko` | декларативная разметка диска |
| `home-manager` | release-25.11 |
| `sops-nix` | управление секретами |
