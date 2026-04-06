{
  pkgs,
  inputs,
  ...
}:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (final: prev: {
      amnezia-vpn = inputs.nixpkgs-amnezia.legacyPackages.${pkgs.stdenv.hostPlatform.system}.amnezia-vpn;
    })
    (final: prev: {
      firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
    })
    inputs.claude-code.overlays.default
    inputs.niri.overlays.niri
    (final: prev: {
      niri = prev.niri.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];
}
