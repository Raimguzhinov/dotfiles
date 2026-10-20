{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.nodejs = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          yarn
        ];

        shellHook = /* bash */ ''
          echo "Using Node version: $(node --version)"
        '';
      };
    };
}
