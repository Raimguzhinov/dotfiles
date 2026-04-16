# Host: Dell XPS 13 9320
# Naming follows nixos-hardware convention: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
{ ... }:
{
  imports = [
    ./configuration.nix
    ./overlays.nix
  ];
}
