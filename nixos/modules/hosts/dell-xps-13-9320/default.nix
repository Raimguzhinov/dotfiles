# Host: Dell XPS 13 9320
# Naming follows nixos-hardware convention: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
{ inputs, config, ... }:
{
  flake.nixosConfigurations.raimguzhinov = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      hostname = "raimguzhinov";
      username = "dias";
      version = "26.05";
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      homeModules = config.flake.homeModules;
    };
    modules = [
      config.flake.nixosModules.hwDellXps9320
      config.flake.nixosModules.configDellXps
      config.flake.nixosModules.overlays
      config.flake.nixosModules.llamaCpp
      config.flake.nixosModules.pi
      inputs.home-manager.nixosModules.home-manager
      inputs.niri.nixosModules.niri
    ];
  };
}
