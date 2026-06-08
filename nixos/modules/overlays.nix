{ ... }:
{
  # Global overlays used by all NixOS configurations.
  flake.nixosModules.overlays =
    { inputs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        inputs.nix-firefox-addons.overlays.default
        inputs.claude-code.overlays.default
        inputs.niri.overlays.niri
        (
          final: prev:
          prev.lib.optionalAttrs (prev ? niri) {
            niri = prev.niri.overrideAttrs (_: {
              doCheck = false;
            });
          }
        )
      ];
    };
}
