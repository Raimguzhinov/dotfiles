{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-amnezia.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri.url = "github:sodiboo/niri-flake";
    nvf.url = "github:notashelf/nvf";
    claude-code.url = "github:sadjow/claude-code-nix";
    max-messanger.url = "github:Raimguzhinov/max-messanger-flake";
    niri-float-sticky.url = "github:probeldev/niri-float-sticky";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-amnezia,
      disko,
      niri,
      nvf,
      claude-code,
      max-messanger,
      niri-float-sticky,
      zen-browser,
      firefox-addons,
      noctalia,
      home-manager,
      sops-nix,
      ...
    }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      installScript = pkgs.writeShellApplication {
        name = "install";
        runtimeInputs = with pkgs; [
          git
          disko.packages.x86_64-linux.disko
        ];
        text = ''
          REPO_URL="https://github.com/Raimguzhinov/dotfiles"
          HOSTNAME="raimguzhinov"
          TARGET="/mnt"
          DOTFILES_TARGET="$TARGET/home/dias/dotfiles"
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

          chown -R 1000:1000 "$TARGET/home/dias"

          echo ""
          echo ">>> Installing NixOS..."
          nixos-install \
            --flake "$DOTFILES_TARGET/nixos#$HOSTNAME" \
            --no-root-passwd

          echo ""
          echo ">>> Set password for user dias:"
          nixos-enter --root "$TARGET" -- passwd dias

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
      };
    in
    {
      nixosConfigurations.raimguzhinov = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          ./overlays.nix
          home-manager.nixosModules.home-manager
          niri.nixosModules.niri
        ];
      };

      apps.x86_64-linux.install = {
        type = "app";
        program = "${installScript}/bin/install";
      };
    };
}
