{ ... }:
{
  flake.nixosModules.overlays =
    { pkgs, inputs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        inputs.nix-firefox-addons.overlays.default
        inputs.claude-code.overlays.default
        inputs.lmstudio.overlays.default
        inputs.niri.overlays.niri
        (final: prev: {
          niri = prev.niri.overrideAttrs (_: {
            doCheck = false;
          });
        })
      ];
    };
}
