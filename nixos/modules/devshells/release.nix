{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      fonts = pkgs.symlinkJoin {
        name = "release-fonts";
        paths = with pkgs; [
          inter
          jetbrains-mono
        ];
      };
    in
    {
      devShells.release = pkgs.mkShell {
        packages = with pkgs; [
          git
          python3
          typst
        ];

        TYPST_FONT_PATHS = "${fonts}/share/fonts";
      };
    };
}
