{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.typst = pkgs.mkShell {
        packages = with pkgs; [
          typst
          tinymist
          typstyle
          mitex
          pandoc
          zathura
        ];

        shellHook = /* bash */ ''
          echo "Using Typst version: $(typst --version)"
        '';
      };
    };
}
