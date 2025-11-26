{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
    niri.url = "github:sodiboo/niri-flake";
    nvf.url = "github:notashelf/nvf";
    max-messanger.url = "github:Raimguzhinov/max-messanger-flake";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      niri,
      nvf,
      max-messanger,
      zen-browser,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations.raimguzhinov = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = inputs;
        modules = [
          ./configuration.nix
          (
            { config, pkgs, ... }:
            {
              nixpkgs.overlays = [
                (final: prev: {
                  amnezia-vpn = nixpkgs-unstable.legacyPackages.${prev.system}.amnezia-vpn;
                })
              ];
            }
          )
          home-manager.nixosModules.home-manager
          niri.nixosModules.niri
        ];
      };
    };
}
