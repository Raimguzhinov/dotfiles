{ ... }:
let
  version = "0.8.7";

  sources = {
    x86_64-linux = {
      asset = "noodle-linux-x86_64";
      hash = "sha256-8eziZmx5BU9vbBINHvt7CLFmDd3KXCtmOPOlqbvErQQ=";
    };
    aarch64-linux = {
      asset = "noodle-linux-arm64";
      hash = "sha256-N45YePnM+144aSTk0thTKxbTEFyEkV8Fg0p8UN900fE=";
    };
    aarch64-darwin = {
      asset = "noodle-macos-arm64";
      hash = "sha256-KXL4l7JaX5Am6dsQ2rMjHn44APHAVm5yu96XFullgSU=";
    };
  };

  supportedSystems = builtins.attrNames sources;

  mkNoodle =
    pkgs:
    let
      inherit (pkgs) lib;
      system = pkgs.stdenv.hostPlatform.system;
      source = sources.${system};
    in
    pkgs.stdenvNoCC.mkDerivation {
      pname = "noodle";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://github.com/wilfredinni/noodle/releases/download/v${version}/${source.asset}";
        inherit (source) hash;
      };

      dontUnpack = true;
      dontStrip = true;

      nativeBuildInputs = lib.optionals (lib.hasSuffix "-linux" system) [
        pkgs.autoPatchelfHook
      ];

      installPhase = ''
        runHook preInstall
        install -Dm755 $src $out/bin/noodle
        runHook postInstall
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        runHook preInstallCheck
        export HOME=$(mktemp -d)
        $out/bin/noodle --version | grep -F ${version}
        runHook postInstallCheck
      '';

      meta = {
        description = "A delicious REST client for your terminal";
        homepage = "https://noodlerest.dev";
        downloadPage = "https://github.com/wilfredinni/noodle/releases";
        license = lib.licenses.asl20;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        mainProgram = "noodle";
        platforms = supportedSystems;
      };
    };
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = if builtins.elem system supportedSystems then { noodle = mkNoodle pkgs; } else { };
    };

  flake.homeModules.noodle =
    { pkgs, ... }:
    {
      home.packages = [ (mkNoodle pkgs) ];
    };
}
