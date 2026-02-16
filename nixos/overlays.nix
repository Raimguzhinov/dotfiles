{
  config,
  pkgs,
  nixpkgs-unstable,
  firefox-addons,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      amnezia-vpn = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.amnezia-vpn;
    })
    (final: prev: {
      firefox-addons = firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
    })
  ];
}
