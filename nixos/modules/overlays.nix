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
          let
            libinput =
              prev.lib.warnIf (prev.lib.versionAtLeast prev.libinput.version "1.31.901")
                "overlays.nix: libinput ${prev.libinput.version} already contains d0e6d43a (libinput#1319), drop the niri libinput override"
                prev.libinput.overrideAttrs
                (old: {
                  patches = (old.patches or [ ]) ++ [
                    (prev.fetchpatch {
                      url = "https://gitlab.freedesktop.org/libinput/libinput/-/commit/d0e6d43a78ee81f077dbd0dda98827440a3b5fc2.patch";
                      includes = [ "src/evdev-mt-touchpad.c" ];
                      hash = "sha256-7+lDNp7DIHgL4apSxHrkZAcEYvRPeH8G6SdSclxbRBY=";
                    })
                  ];
                });
          in
          prev.lib.optionalAttrs (prev ? niri) {
            niri = prev.niri.overrideAttrs (_: {
              doCheck = false;
            });
            niri-unstable = prev.niri-unstable.override {
              inherit libinput;
            };
          }
        )
      ];
    };
}
