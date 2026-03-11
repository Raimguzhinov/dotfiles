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
      firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
    })
    inputs.claude-code.overlays.default
    inputs.niri.overlays.niri
  ];
}
