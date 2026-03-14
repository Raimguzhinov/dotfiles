# NixOS flake configuration with home-manager

## Обновить текущую систему

```bash
sudo nixos-rebuild switch --flake ~/dotfiles/nixos
```

---

## Установка на новое железо (с LiveCD)

1. Загрузиться с [NixOS LiveCD](https://nixos.org/download/)
2. Открыть терминал и выполнить:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:Raimguzhinov/dotfiles?dir=nixos#install
```

Скрипт спросит целевой диск, всё остальное сделает сам:
- разметит диск (GPT → EFI + swap 32G + LUKS2 → btrfs)
- сгенерирует `hardware-configuration.nix` для нового железа
- склонирует репозиторий в `/home/dias/dotfiles`
- установит NixOS
- предложит задать пароль пользователя `dias`

3. Перезагрузиться: `reboot`

---

## После первой загрузки

```bash
# Закоммитить hardware-configuration для нового железа
cd ~/dotfiles
git add nixos/hardware-configuration.nix
git commit -m "nixos: add hardware-configuration"

# Переключить remote на SSH
git remote set-url origin git@github.com:Raimguzhinov/dotfiles.git
```

> **Примечание:** swap-раздел 32G. Для гибернации он должен быть не меньше объёма RAM.
> Если нужно другое значение — поправить `size` в `nixos/disko.nix` перед установкой.
