# Host: Lenovo ThinkPad T495
# Naming follows nixos-hardware convention: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
{ inputs, config, ... }:
{
  flake.nixosConfigurations.thinkpad-t495 = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      hostname = "thinkpad-t495";
      username = "nixos";
      version = "25.11";
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      homeModules = config.flake.homeModules;
    };
    modules = [
      config.flake.nixosModules.hwThinkpadT495
      config.flake.nixosModules.configThinkpadT495
      inputs.home-manager.nixosModules.home-manager
    ];
  };
}
