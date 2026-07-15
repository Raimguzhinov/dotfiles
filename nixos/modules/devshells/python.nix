{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.python = pkgs.mkShell {
        packages = [
          (pkgs.python3.withPackages (
            p: with p; [
              black
              configparser
              isort
              mypy
              pip
              pytest
              python-dotenv
              requests
              ruff
              virtualenv
            ]
          ))
        ];

        shellHook = /* bash */ ''
          echo "Using Python version: $(${pkgs.python3}/bin/python3 --version)"
        '';
      };
    };
}
