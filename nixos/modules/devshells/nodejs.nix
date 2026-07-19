{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.nodejs = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_20
          yarn
          yarn2nix
        ];

        shellHook = /* bash */ ''
          echo "Using Node version: $(node --version)"
        '';
      };
    };
}