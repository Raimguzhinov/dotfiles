{
  config,
  pkgs,
  nixpkgs-unstable,
  ...
}:
{
  nixpkgs.overlays = [
    (final: prev: {
      amnezia-vpn = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}.amnezia-vpn;
    })
  ];
}
