{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-amnezia.url = "github:NixOS/nixpkgs/1ebf2de9af636a5752c15b4f40e504183f0b2ec8";
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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-amnezia,
      niri,
      nvf,
      claude-code,
      max-messanger,
      niri-float-sticky,
      zen-browser,
      firefox-addons,
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
