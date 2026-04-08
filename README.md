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
  run --refresh 'github:Raimguzhinov/dotfiles?dir=nixos#install'
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
# Вставить YubiKey и импортировать GPG-ключ
gpg --card-edit
# В интерактивном режиме:
#   fetch
#   quit

# Импортировать SSH SK-ключи с YubiKey
mkdir -p ~/.ssh && cd ~/.ssh && ssh-keygen -K
mv ~/.ssh/id_ed25519_sk_rk ~/.ssh/id_ed25519_sk
mv ~/.ssh/id_ed25519_sk_rk.pub ~/.ssh/id_ed25519_sk.pub
chmod 600 ~/.ssh/id_ed25519_sk
chmod 644 ~/.ssh/id_ed25519_sk.pub
cd ~

# Сгенерировать обычный SSH-ключ для Git LFS
ssh-keygen -t ed25519

# Применить конфигурацию (sops-nix требует GPG-ключ)
sudo nixos-rebuild switch --flake ~/dotfiles/nixos

# Закоммитить hardware-configuration для нового железа
cd ~/dotfiles
git add nixos/hardware-configuration.nix
git commit -m "nixos: add hardware-configuration"

# Переключить remote на SSH
git remote set-url origin git@github.com:Raimguzhinov/dotfiles.git

# Зарегистрировать отпечаток пальца
sudo fprintd-enroll dias
```

> **Примечание:** swap-раздел 32G. Для гибернации он должен быть не меньше
> объёма RAM. Если нужно другое значение — поправить `size` в `nixos/disko.nix`
> перед установкой.

---

## Тестирование в virt-manager (KVM/QEMU)

### Создание VM

1. Создать VM через virt-manager, выбрать **UEFI** firmware при создании.
   - `systemd-boot` не работает с SeaBIOS — только UEFI (OVMF).
   - Firmware **нельзя сменить после создания** — только пересоздать VM.

2. В настройках Video выбрать модель **Virtio**.

3. В настройках Display выбрать **Spice**, установить **Listen type: None**,
   включить **GL** и указать rendernode (`/dev/dri/...`).
   - `Listen type: None` обязателен при включённом GL — иначе SPICE не
     запустится.

### Чёрный экран — virtio-gpu + SPICE GL

Если после запуска VM чёрный экран, убедиться что в XML включён `accel3d`:

```xml
<video>
  <model type="virtio" heads="1" primary="yes">
    <acceleration accel3d="yes"/>
  </model>
</video>
```

Через virt-manager: **View → Details → Video Virtio → XML** — добавить
`<acceleration accel3d="yes"/>` внутрь `<model>`.

Без `accel3d="yes"` virtio-gpu работает без 3D-ускорения и SPICE GL не
отображает картинку.
