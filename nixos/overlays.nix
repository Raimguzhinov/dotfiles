{
  config,
  pkgs,
  nixpkgs-amnezia,
  firefox-addons,
  claude-code,
  niri,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      amnezia-vpn = nixpkgs-amnezia.legacyPackages.${prev.stdenv.hostPlatform.system}.amnezia-vpn;
    })
    (final: prev: {
      firefox-addons = firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
    })
    claude-code.overlays.default
    niri.overlays.niri
  ];
}
