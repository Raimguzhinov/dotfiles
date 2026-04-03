{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-amnezia.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
    niri.url = "github:sodiboo/niri-flake";
    nvf.url = "github:notashelf/nvf";
    claude-code.url = "github:sadjow/claude-code-nix";
    max-messanger.url = "github:Raimguzhinov/max-messanger-flake";
    tankionline.url = "github:Raimguzhinov/tankionline-flake";
    niri-float-sticky.url = "github:probeldev/niri-float-sticky";
    lmstudio.url = "github:Daaboulex/lmstudio-nix";
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
    disko = {
      url = "github:nix-community/disko";
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
      nixpkgs-unstable,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      hostname = "raimguzhinov";
      username = "dias";
      version = "25.11";

      installScript = import ./install.nix {
        pkgs = import nixpkgs { inherit system; };
        inherit system;
        inherit hostname;
        inherit username;
        disko = inputs.disko;
      };
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          pkgs-unstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          inherit inputs;
          inherit hostname;
          inherit username;
          inherit version;
        };
        modules = [
          ./configuration.nix
          ./overlays.nix
          inputs.home-manager.nixosModules.home-manager
          inputs.niri.nixosModules.niri
        ];
      };

      apps.${system}.install = {
        type = "app";
        program = "${installScript}/bin/install";
      };
    };
}
