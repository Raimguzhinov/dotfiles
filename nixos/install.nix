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

    echo ""
    echo ">>> Increasing file descriptor limit for nix builds..."
    mkdir -p /etc/systemd/system/nix-daemon.service.d
    printf '[Service]\nLimitNOFILE=1048576\n' \
      > /etc/systemd/system/nix-daemon.service.d/limits.conf
    systemctl daemon-reload
    systemctl restart nix-daemon

    echo ""
    echo ">>> Installing NixOS..."
    nixos-install \
      --flake "$DOTFILES_TARGET/nixos#$HOSTNAME" \
      --no-root-passwd

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
