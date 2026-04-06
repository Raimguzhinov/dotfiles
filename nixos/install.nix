{
  pkgs,
  disko,
  system,
  hostname,
  username,
}:

pkgs.writeShellApplication {
  name = "install";
  runtimeInputs = [
    pkgs.git
    pkgs.git-lfs
    pkgs.gnused
    pkgs.glow
    pkgs.systemd
    disko.packages.${system}.disko
  ];
  text = ''
    REPO_URL="https://github.com/Raimguzhinov/dotfiles"
    HOSTNAME="${hostname}"
    USERNAME="${username}"
    TARGET="/mnt"
    DOTFILES_TARGET="$TARGET/home/$USERNAME/dotfiles"
    DISKO_CONFIG="${./disko.nix}"
    README="${../README.md}"

    if [ "$(id -u)" -ne 0 ]; then
      echo "Run as root: sudo nix run ..." >&2
      exit 1
    fi

    echo "=== NixOS Install ==="

    # Detect previous partial install by partition labels (survive reboot)
    RESUME=false
    if [ -e /dev/disk/by-partlabel/disk-main-luks ]; then
      echo ""
      echo "Detected existing partition layout."
      read -rp "Resume previous install? (yes/no): " RESUME_CONFIRM
      if [ "$RESUME_CONFIRM" = "yes" ]; then
        RESUME=true
      fi
    fi

    if [ "$RESUME" = "false" ]; then
      echo ""
      echo "Available disks:"
      lsblk -dpno NAME,SIZE,MODEL | grep -v "loop\|rom"
      echo ""

      read -rp "Target disk (e.g. /dev/nvme0n1 or /dev/sda): " DISK

      if [ ! -b "$DISK" ]; then
        echo "Error: $DISK is not a block device" >&2
        exit 1
      fi

      echo ""
      echo "WARNING: ALL DATA ON $DISK WILL BE ERASED!"
      read -rp "Type 'yes' to continue: " CONFIRM
      [ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 1; }

      echo ""
      echo ">>> Partitioning $DISK..."
      disko --mode destroy,format,mount \
        --arg disk "\"$DISK\"" \
        "$DISKO_CONFIG"

      echo ""
      echo ">>> Activating swap..."
      swapon /dev/disk/by-partlabel/disk-main-swap

      echo ""
      echo ">>> Generating hardware configuration..."
      nixos-generate-config --root "$TARGET"

      echo ""
      echo ">>> Cloning dotfiles..."
      git lfs install
      mkdir -p "$DOTFILES_TARGET"
      git clone "$REPO_URL" "$DOTFILES_TARGET"

      echo ""
      echo ">>> Copying hardware configuration..."
      cp "$TARGET/etc/nixos/hardware-configuration.nix" \
        "$DOTFILES_TARGET/nixos/hardware-configuration.nix"

      chown -R 1000:1000 "$TARGET/home/$USERNAME"
    else
      echo ""
      echo ">>> Unlocking LUKS (enter passphrase)..."
      cryptsetup open /dev/disk/by-partlabel/disk-main-luks cryptroot

      echo ""
      echo ">>> Mounting filesystems..."
      mount -o subvol=/root,compress=zstd,noatime /dev/mapper/cryptroot "$TARGET"
      mkdir -p "$TARGET"/{home,nix,boot}
      mount -o subvol=/home,compress=zstd,noatime /dev/mapper/cryptroot "$TARGET/home"
      mount -o subvol=/nix,compress=zstd,noatime  /dev/mapper/cryptroot "$TARGET/nix"
      mount /dev/disk/by-partlabel/disk-main-ESP "$TARGET/boot"

      echo ""
      echo ">>> Activating swap..."
      swapon /dev/disk/by-partlabel/disk-main-swap 2>/dev/null || true

      echo ""
      echo ">>> Pulling latest dotfiles..."
      git -C "$DOTFILES_TARGET" pull
    fi

    echo ""
    echo ">>> Installing NixOS..."
    nixos-install \
      --flake "$DOTFILES_TARGET/nixos#$HOSTNAME" \
      --no-root-passwd \
      --option substituters "https://cache.nixos.org https://niri.cachix.org https://notashelf.cachix.org https://nix-community.cachix.org" \
      --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= notashelf.cachix.org-1:VTTBFNQWbfyLuRzgm2I7AWSDJdqAa11ytLXHBhrprZk= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

    echo ""
    echo ">>> Set password for user $USERNAME:"
    nixos-enter --root "$TARGET" -- passwd "$USERNAME"

    echo ""
    echo ">>> Enrolling YubiKey (FIDO2) into LUKS2..."
    echo "    Insert YubiKey and enter LUKS passphrase when prompted."
    systemd-cryptenroll \
      --fido2-device=auto \
      --fido2-with-client-pin=yes \
      /dev/disk/by-partlabel/disk-main-luks

    echo ""
    echo "=== Done! Reboot and then: ==="
    echo ""
    sed -n '/^## После первой загрузки/,$p' "$README" | glow -
  '';
}
