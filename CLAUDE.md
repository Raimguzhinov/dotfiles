# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

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

Точка входа — `nixos/flake.nix`. Использует flake-parts + import-tree: все `.nix`-файлы
из `nixos/modules/` подхватываются автоматически (кроме путей, содержащих `/_`).

**flake.nix:**

```nix
outputs = inputs:
  inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./modules);
```

- `import-tree` рекурсивно импортирует все `.nix` из `modules/`, исключая пути с `/_`
  (директории и файлы с префиксом `_`)
- Каждый `.nix`-файл в `modules/` является flake-parts модулем
- `flake.lock` содержит все inputs включая `flake-parts` и `import-tree`

**modules/parts.nix** — корневая конфигурация flake-parts:

- `systems` — список целевых архитектур (x86_64-linux, aarch64-linux, x86_64-darwin,
  aarch64-darwin)
- `config.perSystem._module.args.pkgs/pkgs-unstable` — делает `pkgs` и `pkgs-unstable`
  доступными во всех `perSystem`-модулях (с `allowUnfree = true`)
- `options.flake.homeModules` — кастомная опция типа `lazyAttrsOf unspecified` для
  аккумуляции HM-модулей из всех feature-файлов; `nixosModules` объявлять не нужно —
  оно встроено в flake-parts с типом `deferredModule`

**Структура модулей:**

```
nixos/
  flake.nix             ← flake-parts + import-tree ./modules
  secrets.yaml / .sops.yaml
  modules/
    parts.nix           ← systems + pkgs/_module.args + homeModules option
    hosts/
      dell-xps-13-9320/          ← именование по nixos-hardware
        default.nix              ← flake.nixosConfigurations.raimguzhinov
        configuration.nix        ← flake.nixosModules.configDellXps (системный уровень)
        hardware.nix             ← flake.nixosModules.hwDellXps9320 (hw-конфиг)
        overlays.nix             ← flake.nixosModules.overlays
        _disko.nix               ← standalone disko (префикс _ исключает из import-tree)
        install.nix              ← perSystem.apps.install (скрипт установки)
        intel-int3472-gpio-type.patch
      lenovo-thinkpad-t495/      ← placeholder (код закомментирован)
        default.nix
        hardware.nix
    features/           ← каждый файл = flake-parts модуль с perSystem + homeModules
      tools.nix, development.nix, git.nix, neovim.nix, niri.nix, noctalia.nix,
      rofi.nix, chromium.nix, zen-browser.nix, jetbrains.nix, zed-editor.nix,
      thunderbird.nix, claude.nix, sops.nix, gaming.nix
      jetbrains-agent.b64
    devshells/          ← flake-parts модули devShells (встроены в основной флейк)
      go.nix            ← perSystem devShells.go (Go 1.21, protobuf, delve...)
      python.nix        ← perSystem devShells.python
```

**Паттерн perSystem-пакета**: все `perSystem.packages.*` — standalone-пакеты со всеми
конфигами запечёнными внутрь (эталон — `modules/features/neovim.nix`). Общая функция
(например `makeNvimSettings pkgs`) вызывается дважды: в `perSystem` (standalone для
`nix run`) и в `flake.homeModules` (HM-интеграция). Голый `pkgs.somePackage` без конфига
в perSystem бессмыслен — только настроенный standalone.

**Паттерн feature-модуля** (пример — `rofi.nix`):

```nix
{ ... }:
{
  # Standalone-пакет для nix run/build
  perSystem = { pkgs, ... }:
  {
    packages.rofi = pkgs.rofi;
  };

  # HM-модуль для подключения в configuration.nix
  flake.homeModules.rofi =
    { config, lib, pkgs, ... }:
    {
      programs.rofi = { enable = true; ... };
    };
}
```

Каждый feature-файл одновременно:
- добавляет `perSystem.packages.NAME` — собираемый пакет (для `nix run`/`nix build`)
- добавляет `flake.homeModules.NAME` — HM-модуль (подключается в `configuration.nix`)

**Паттерны Linux-only перSystem-пакетов** (niri, noctalia, zen-browser):

```nix
perSystem = { inputs', lib, system, ... }:
lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
  packages.niri = inputs'.niri.packages.niri-unstable;
};
```

Важно: НЕ использовать `pkgs.stdenv.isLinux` в `perSystem` — `pkgs` приходит через
`_module.args` и его раннее использование вызывает бесконечную рекурсию. Использовать
`system` + `builtins.elem`.

**modules/hosts/dell-xps-13-9320/default.nix** — точка входа хоста:

```nix
{ inputs, config, ... }:
{
  flake.nixosConfigurations.raimguzhinov = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      homeModules = config.flake.homeModules;  # ← fixed-point flake-parts
      pkgs-unstable = import inputs.nixpkgs-unstable { ... };
      ...
    };
    modules = [
      config.flake.nixosModules.hwDellXps9320   # ← hardware.nix
      config.flake.nixosModules.configDellXps   # ← configuration.nix
      config.flake.nixosModules.overlays
      inputs.home-manager.nixosModules.home-manager
      inputs.niri.nixosModules.niri
    ];
  };
}
```

`config.flake.homeModules` и `config.flake.nixosModules` — fixed-point результат
flake-parts: доступны сразу все модули из всех файлов.

**modules/hosts/dell-xps-13-9320/install.nix** — flake-parts модуль:

```nix
{ inputs, ... }:
{
  perSystem = { pkgs, inputs', ... }:
  {
    apps.install = { type = "app"; program = "${installScript}/bin/install"; };
  };
}
```

Доступен как `nix run 'github:Raimguzhinov/dotfiles?dir=nixos#install'`.

**Слои конфигурации:**

- `hardware.nix` — завёрнут в `flake.nixosModules.hwDellXps9320`: hw-конфиг, ядро,
  файловые системы, SoundWire/камера, swap/LUKS UUID
- `configuration.nix` — завёрнут в `flake.nixosModules.configDellXps`: загрузчик,
  сервисы, сетевые настройки, системные пакеты, Home Manager для `root` и `dias`
- `overlays.nix` — завёрнут в `flake.nixosModules.overlays`: оверлеи nixpkgs +
  `nixpkgs.config.allowUnfree = true` для системного pkgs

**Модули Home Manager пользователя `dias`** (все в `modules/features/`,
подключаются через `homeModules.*` в `configuration.nix`):

- `tools.nix` — zsh, zoxide, atuin, zellij, yazi (`rr`), bat, eza, starship,
  lazygit, pgcli, fd, fzf, ripgrep
- `git.nix` — git, git-lfs, delta; includes для gitlab_work/github identity
- `development.nix` — direnv + nix-direnv, создаёт `~/Work/.envrc` с
  `use flake ~/dotfiles/nixos/modules/_devshells#{go,python}`, вспомогательные
  shell-скрипты (ssh-setup-dlv, ssh-run-debugger, tracktime и др.)
- `neovim.nix` — nvf (Neovim framework), LSP для Go/Nix/Python/Bash/YAML/Markdown;
  `makeNvimSettings pkgs` — общая функция для perSystem (standalone) и HM
- `niri.nix` — Wayland compositor niri: раскладки, биндинги клавиш, правила окон,
  автозапуск; perSystem только для Linux
- `noctalia.nix` — noctalia-shell (панель/уведомления); эталонная конфига:
  https://docs.noctalia.dev/getting-started/nixos/
  - `general.lockOnSuspend = true` — автоблокировка при suspend
  - `general.allowPasswordWithFprintd = false` — только отпечаток на lockscreen
- `rofi.nix` — лаунчер приложений (rofi с Wayland-поддержкой)
- `chromium.nix`, `zen-browser.nix` — браузеры с расширениями + gopass-jsonapi
  native messaging
- `jetbrains.nix` — JetBrains IDE (pkgs-unstable); `makeJetbrainsPkgs pkgs pkgs-unstable`
  — общая функция; `idea-ultimate` переименован в `idea` в nixpkgs-unstable
- `zed-editor.nix` — Zed editor
- `thunderbird.nix` — Thunderbird: `mkEmailAccount`/`mkProviderAccount` хелперы,
  провайдеры mail-ru/gmail/yandex, аккаунты с OAuth2, ru-langpack через `home.file` XPI
- `claude.nix` — `claudeWrapperMCP` враппер: подхватывает MCP-конфиг
  (demo_mcp/youtrack) если доступен `mcp_sse_url`; `claude-protei` —
  корпоративная модель через внешний litellm;
  `programs.claude-code.package = claudeWrapperMCP`
- `sops.nix` — sops-nix секреты (GPG/YubiKey): github_token, youtrack/_,
  git/github, git/gitlab_work, product/services_root, pass_store/clone_cmd,
  work_ai/_
- `gaming.nix` — stub-placeholder для будущей игровой конфигурации
  (`flake.nixosModules.gaming`)

**Модули Home Manager пользователя `root`**: `homeModules.neovim`, `homeModules.tools`

**Devshells** (`modules/devshells/`): flake-parts модули, встроенные в основной флейк.
`go.nix` — Go 1.21 (pinned), gopls, delve 1.25.2, protobuf 23.2, protoc-gen-go, libwebp;
пинированные nixpkgs (`nixpkgs-go21`, `nixpkgs-protobuf23` и др.) — inputs в основном
`flake.nix`. `python.nix` — python3 с black/mypy/ruff/pytest/requests.
`development.nix` записывает `.envrc` со ссылкой на `~/dotfiles/nixos` —
изменения в devshells подхватываются direnv без rebuild системы.

Использовать без установки системы (напрямую с GitHub):
```bash
nix develop 'github:Raimguzhinov/dotfiles?dir=nixos#go'
nix develop 'github:Raimguzhinov/dotfiles?dir=nixos#python'
```

## Dell XPS 13 Plus 9320 — особенности железа

- **Ядро**: `boot.kernelPackages = pkgs.linuxPackages_latest` — обязательно для
  ipu6ep камеры и SoundWire микрофона
- **SoundWire микрофон (rt714)**:
  - `systemd.services.xps-mic-fix` — применяет ALSA routing при загрузке: ждёт
    готовности карты 0 (цикл до 15 сек), затем устанавливает
    `rt714 ADC 22 Mux → DMIC1`, `PGA5.0 5 Master Capture Switch on,on`,
    `rt714 FU02 Capture Switch on`, `rt714 FU02 Capture Volume 70`,
    `rt714 FU0C Boost 0`
  - `PGA5.0 5 Master Capture Switch` — системный capture enable; если `off,off`
    — микрофон молчит несмотря на то что WirePlumber видит источник
  - `powerManagement.resumeCommands` — после hibernate: PCI rebind
    sof-audio-pci-intel-tgl + поллинг готовности карты (до 30с) + те же ALSA настройки
    (включая `PGA5.0 5 Master Capture Switch`) + restart pipewire затем wireplumber
    для всех сессий (pipewire первым — у него стейт устаревает после rebind)
- **Камера (IPU6EP)**:
  - `hardware.ipu6.platform = "ipu6ep"` + `libcamera` — современный подход без
    icamerasrc
  - `services.v4l2-relayd.instances.ipu6.enable = lib.mkForce false` — дефолтный
    ipu6 инстанс не работает на 9320
  - `intel-int3472-gpio-type.patch` — патч ядра: без него "GPIO type 0x02
    unknown", камера не инициализируется
  - `systemd.services.camera-bridge` — мост для браузеров: находит активное ipu6
    устройство, создаёт `/dev/camera-active` симлинк; запускается вручную:
    `systemctl start camera-bridge`
  - sudo NOPASSWD для `systemctl start/stop camera-bridge.service`
  - WirePlumber: `monitor.v4l2.disable = true` — только libcamera, без v4l2
    монитора
  - xdg-desktop-portal: `org.freedesktop.impl.portal.Access = "gtk"` (диалог
    камеры требует gtk-портала)
- **Дисплей**: eDP-1 position `x=0, y=200` в niri.nix

## GTK/Qt оформление

- GTK2/3: тема `adw-gtk3-dark` (`pkgs.adw-gtk3`); GTK4:
  `gtk-theme-name = "adw-gtk3-dark"` через `extraConfig`
- Иконки: `Papirus-Dark` (`pkgs.papirus-icon-theme`)
- Qt: `style.name = "Adwaita-Dark"` (через `adwaita-qt6`),
  `qt5ctSettings`/`qt6ctSettings` — декларативно; `kdePackages.qt6ct` в
  `environment.systemPackages`
- `adw-gtk3`, `adwaita-icon-theme`, `adwaita-qt6`, `gtk3`, `hicolor-icon-theme`
  — в `environment.systemPackages` (нужны системно для тем)

## Ключевые соглашения

- Десктопные пакеты — в `home.packages` пользователя `dias`, НЕ в
  `environment.systemPackages`
- **Исключение — в `environment.systemPackages`**:
  - Пакеты, требующие polkit (например, `kdePackages.partitionmanager`) — в HM
    polkit-правила не работают → файловые системы не монтируются
  - Игры (`kdePackages.kpat`) — тоже в `environment.systemPackages`
- `security.soteria.enable = true` — polkit authentication agent (вместо
  `niri-flake-polkit`); `systemd.user.services.niri-flake-polkit.enable = false`
- `rr` — обёртка yazi: `programs.yazi.shellWrapperName = "rr"` даёт
  shell-функцию с поддержкой `cd`; плюс `writeShellScriptBin "rr"` в
  `home.packages` как реальный бинарник для `sudo rr` (sudo не видит
  shell-функции)
- `pkgs.replaceVars` вместо `pkgs.substituteAll` (убран в nixpkgs 25.11)
- Активация dev-окружения (`~/Work/.envrc`) пишет файл только при изменении
  содержимого (`diff -q`) — иначе nix-direnv инвалидирует кэш
- Формат коммитов: `nixos: <сообщение>`
- **Коммиты только по явной просьбе**: не коммитить самостоятельно после каждого
  изменения — только когда пользователь явно говорит "сделай коммит"
- **Не делать незапрошенного**: не удалять комментарии, не рефакторить код за
  пределами просьбы, не добавлять обработку ошибок и т.п. — только то, о чём
  попросили. При малейшей неуверенности — переспросить
- **Обновление CLAUDE.md**: после добавления новой фичи/изменения архитектуры —
  обновить `CLAUDE.md`. Перед обновлением проверить последние 3 коммита
  (`git log -3`), чтобы учесть ручные изменения
- Стиль `inherit` в атрсетах: каждый аргумент на отдельной строке
  (`inherit foo;` / `inherit bar;`), НЕ группировать в одну строку
  (`inherit foo bar;`)
- `pkgs-unstable` доступен в HM-модулях через
  `extraSpecialArgs = { inherit pkgs-unstable; }` в `configuration.nix`
- `alias sudo='sudo '` в shellAliases — позволяет sudo видеть shell-алиасы;
  `security.sudo.extraConfig` с `env_keep += "PATH"` — для бинарей в
  пользовательском PATH

## Flake-parts: типичные ловушки

- **`pkgs` в `perSystem` и бесконечная рекурсия**: `pkgs` приходит через
  `_module.args`, его использование в качестве условия импорта вызывает цикл.
  Для Linux-only пакетов использовать `builtins.elem system [...]`, не
  `pkgs.stdenv.isLinux`
- **`options` + `config` в одном модуле**: если модуль объявляет `options`,
  конфигурационные атрибуты (`systems`, `perSystem`) нужно размещать внутри
  `config = { ... }`, иначе flake-parts выдаёт ошибку об "unsupported attribute"
- **`flake.nixosModules` не нужно объявлять**: оно встроено в flake-parts с типом
  `deferredModule`; повторное объявление в `parts.nix` конфликтует и ломает merge
- **`flake.homeModules` нужно объявлять**: в flake-parts нет встроенного
  `homeModules`, поэтому кастомная опция в `parts.nix` обязательна
- **Новые файлы должны быть в git**: import-tree работает с git-деревом; неиндексированные
  (`git add`) файлы не видны при `nix flake check`. Всегда делать `git add` перед проверкой
- **`nvf.lib.neovimConfiguration`** возвращает `{ neovim, config, options, pkgs }`;
  standalone-пакет — `.neovim`, не `.finalPackage`
- **`jetbrains.idea-ultimate`** переименован в `jetbrains.idea` в nixpkgs-unstable
- **`rofi-wayland`** объединён в `rofi` в nixpkgs 25.11+

## Секреты (sops-nix)

- `nixos/.sops.yaml` — GPG fingerprint YubiKey
  (`6E06AD1573F0D606704F4A32719B8382A9DBA991`), path_regex: `secrets\.yaml$`
- `nixos/secrets.yaml` — зашифрованный файл секретов
- `nixos/modules/features/sops.nix` — HM-модуль: объявление секретов, git
  identity includes, zsh env
- `sops-nix.homeManagerModules.sops` подключён через
  `home-manager.sharedModules`
- Секреты: `github_token`, `youtrack/url`, `youtrack/token`, `git/github`,
  `git/gitlab_work`, `product/services_root`, `pass_store/clone_cmd`,
  `work_ai/litellm_url`, `work_ai/litellm_api_key`, `work_ai/mcp_sse_url`
- `git/github` и `git/gitlab_work` — gitconfig-формат (`[user] name/email`),
  подключаются через `programs.git.includes`
- Git identity: github — дефолт (plain include), gitlab_work — для `~/Work/`
  (`gitdir:~/Work/`)
- `hasconfig:remote.*.url` **не работает** с SSH URL (`git@github.com:...`) —
  использовать `gitdir:` или plain include
- `pass_store/clone_cmd` — команда клонирования приватного репо паролей,
  показывается в zsh при отсутствии `~/.password-store`
- Секреты загружаются лениво через `precmd` хук (`_sops_load_secrets`): github и
  youtrack — независимые проверки, без общего `SOPS_SECRETS_LOADED` guard-а
- `sops-nix.service` настроен `After/Wants gpg-agent.service` +
  `Restart=on-failure` — автоповтор при первом запуске без YubiKey
- Редактировать секреты: `sops ./secrets.yaml` (YubiKey PIN)
- На первой загрузке без YubiKey HM activation падает — вставить YubiKey и
  повторить rebuild

## Установка на новое железо

```bash
# С LiveCD NixOS — одна команда:
sudo nix --extra-experimental-features "nix-command flakes" \
  run 'github:Raimguzhinov/dotfiles?dir=nixos#install'
```

Скрипт (`modules/hosts/dell-xps-13-9320/install.nix`, доступен как
`apps.x86_64-linux.install`) делает:

1. Спрашивает диск, запускает `disko --mode destroy,format,mount` с `_disko.nix`
   хоста
2. Генерирует `hardware.nix` (конфиг железа)
3. Клонирует репо в `/mnt/home/dias/dotfiles`, кладёт hw-конфиг в
   `modules/hosts/dell-xps-13-9320/`
4. Запускает `nixos-install --flake .../nixos#raimguzhinov --no-root-passwd`
5. Через `nixos-enter` предлагает задать пароль `dias`

## Disko (разметка диска)

`nixos/modules/hosts/dell-xps-13-9320/_disko.nix` — standalone-конфиг (параметр
`disk ? "/dev/disk/by-diskseq/1"`):

- GPT: ESP 512M (vfat, /boot) + swap 32G (resumeDevice=true) + LUKS2 остаток →
  btrfs
- btrfs subvolumes: `/root`→/, `/home`→/home, `/nix`→/nix
- Swap вне LUKS — для простой гибернации без вычисления resume_offset
- LUKS: интерактивный ввод пароля, allowDiscards=true
- Параметр `disk` нужен только при форматировании (disko CLI), для работающей
  системы не важен
- Файл имеет префикс `_` — исключён из import-tree (не является flake-parts модулем)

## Бинарные кэши

Настроены в `nix.settings` (`modules/hosts/dell-xps-13-9320/configuration.nix`):

- `cache.nixos.org` — основной
- `niri.cachix.org` — compositor niri
- `notashelf.cachix.org` — noctalia и др.
- `nix-community.cachix.org` — nvf, sops-nix и др.

## Inputs flake

| Input               | Назначение                                             |
| ------------------- | ------------------------------------------------------ |
| `nixpkgs`           | nixos-25.11                                            |
| `nixpkgs-unstable`  | нестабильные пакеты (jetbrains, telegram, amnezia-vpn) |
| `flake-parts`       | модульная система флейков                              |
| `import-tree`       | авто-импорт .nix из директории (исключает `/_`)        |
| `niri`              | Wayland compositor + оверлей                           |
| `nvf`               | Neovim framework                                       |
| `claude-code`       | Claude Code CLI                                        |
| `niri-float-sticky` | плагин niri                                            |
| `zen-browser`       | Zen Browser (beta)                                     |
| `firefox-addons`    | расширения для браузеров                               |
| `noctalia`          | shell/панель/уведомления                               |
| `disko`             | декларативная разметка диска                           |
| `home-manager`      | release-25.11                                          |
| `sops-nix`          | управление секретами                                   |

## Именование хостов

Директории под `modules/hosts/` именуются по конвенции nixos-hardware:
`<vendor>-<model>-<variant>`. Примеры: `dell-xps-13-9320`,
`lenovo-thinkpad-t495`, `apple-macbook-pro-14-1`. Эталон:
https://github.com/NixOS/nixos-hardware/blob/master/flake.nix или
https://github.com/NixOS/nixos-hardware?tab=readme-ov-file#list-of-profiles
(третий столбец)
