{ ... }:
let
  mkAiUsagebar =
    {
      lib,
      fetchFromGitHub,
      rustPlatform,
    }:
    rustPlatform.buildRustPackage (finalAttrs: {
      pname = "ai-usagebar";
      version = "1.3.1";

      src = fetchFromGitHub {
        owner = "akitaonrails";
        repo = "ai-usagebar";
        tag = "v${finalAttrs.version}";
        hash = "sha256-9PWYgcdLnBYEUGvgAOSeBRoXjsF21oA/SSAlupFwryE=";
      };
      cargoHash = "sha256-2bsiP89PhxLXCcKf1C896rcZ+OyyhUXkcw96cR1KtwE=";

      # Часть тестов ходит в живые API провайдеров.
      doCheck = false;

      meta = {
        description = "Waybar/Noctalia widget and TUI for tracking multi-provider AI plan usage";
        homepage = "https://github.com/akitaonrails/ai-usagebar";
        license = lib.licenses.mit;
        maintainers = [ ];
        mainProgram = "ai-usagebar";
      };
    });
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.aiUsagebar = pkgs.callPackage mkAiUsagebar { };
    };

  flake.homeModules.aiUsagebar =
    {
      pkgs,
      ...
    }:
    {
      home.packages = [
        (pkgs.callPackage mkAiUsagebar { })
      ];
    };
}
