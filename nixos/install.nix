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
    disko.packages.${system}.disko
  ];
  text = ''
    REPO_URL="https://github.com/Raimguzhinov/dotfiles"
    HOSTNAME="${hostname}"
    USERNAME="${username}"
    TARGET="/mnt"
    DOTFILES_TARGET="$TARGET/home/$USERNAME/dotfiles"
    DISKO_CONFIG="${./disko.nix}"

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
    echo ">>> Generating hardware configuration..."
    nixos-generate-config --root "$TARGET"

    echo ""
    echo ">>> Cloning dotfiles..."
    mkdir -p "$DOTFILES_TARGET"
    git clone "$REPO_URL" "$DOTFILES_TARGET"

    echo ""
    echo ">>> Copying hardware configuration..."
    cp "$TARGET/etc/nixos/hardware-configuration.nix" \
      "$DOTFILES_TARGET/nixos/hardware-configuration.nix"

    chown -R 1000:1000 "$TARGET/home/$USERNAME"

    echo ""
    echo ">>> Installing NixOS..."
    nixos-install \
      --flake "$DOTFILES_TARGET/nixos#$HOSTNAME" \
      --no-root-passwd

    echo ""
    echo ">>> Set password for user $USERNAME:"
    nixos-enter --root "$TARGET" -- passwd "$USERNAME"

    echo ""
    echo "=== Done! Reboot and then: ==="
    echo ""
    echo "  cd ~/dotfiles"
    echo "  git add nixos/hardware-configuration.nix"
    echo "  git commit -m 'nixos: add hardware-configuration'"
    echo "  git remote set-url origin git@github.com:Raimguzhinov/dotfiles.git"
    echo "  mkdir -p ~/.config/nix"
    echo "  echo 'access-tokens = github.com=<token>' > ~/.config/nix/nix.conf"
    echo ""
  '';
}
