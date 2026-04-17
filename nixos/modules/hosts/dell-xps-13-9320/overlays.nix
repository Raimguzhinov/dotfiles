{ ... }:
{
  flake.nixosModules.overlays =
    { pkgs, inputs, ... }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          amnezia-vpn = inputs.nixpkgs-amnezia.legacyPackages.${pkgs.stdenv.hostPlatform.system}.amnezia-vpn;
        })
        inputs.nix-firefox-addons.overlays.default
        inputs.claude-code.overlays.default
        inputs.niri.overlays.niri
        (final: prev: {
          niri = prev.niri.overrideAttrs (_: {
            doCheck = false;
          });
        })
      ];
    };
}
