{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-amnezia.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
    flake-utils.url = "github:numtide/flake-utils";
    lmstudio.url = "github:Daaboulex/lmstudio-nix";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    nix-firefox-addons = {
      url = "github:osipog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

      lib = nixpkgs.lib;

      pkgs = import nixpkgs { inherit system; };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      installScript = import ./modules/hosts/dell-xps-13-9320/install.nix {
        inherit pkgs;
        inherit system;
        inherit hostname;
        inherit username;
        disko = inputs.disko;
      };

      jbPkgs = (import ./modules/features/jetbrains.nix { inherit pkgs-unstable; }).packages;
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgs-unstable;
          inherit hostname;
          inherit username;
          inherit version;
          inherit inputs;
        };
        modules = [
          ./modules/hosts/dell-xps-13-9320
          inputs.home-manager.nixosModules.home-manager
          inputs.niri.nixosModules.niri
        ];
      };

      packages.${system} = jbPkgs;

      apps.${system} = {
        install = {
          type = "app";
          program = "${installScript}/bin/install";
        };
        goland = {
          type = "app";
          program = lib.getExe jbPkgs.goland;
        };
        pycharm = {
          type = "app";
          program = lib.getExe jbPkgs.pycharm;
        };
      };
    };
}
