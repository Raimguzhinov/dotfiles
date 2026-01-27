{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
    niri.url = "github:sodiboo/niri-flake";
    nvf.url = "github:notashelf/nvf";
    max-messanger.url = "github:Raimguzhinov/max-messanger-flake";
    niri-float-sticky.url = "github:probeldev/niri-float-sticky";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      niri,
      nvf,
      max-messanger,
      niri-float-sticky,
      zen-browser,
      noctalia,
      home-manager,
      ...
    }@inputs:
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
    };
}
