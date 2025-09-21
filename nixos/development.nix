{ config, pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.activation.createWorkDir = # bash
    ''
      mkdir -p ~/Work
    '';

  home.file."Work/flake.nix".text = # nix
    ''
      {
        description = "My Flake for Golang Development!";

        inputs = {
          nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
          flake-utils.url = "github:numtide/flake-utils";
          nixpkgs-go21 = {
            url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";
            flake = false;
          };
        };

        outputs =
          {
            self,
            nixpkgs,
            flake-utils,
            nixpkgs-go21,
            ...
          }:
          flake-utils.lib.eachDefaultSystem (
            system:
            let
              pkgs = import nixpkgs { inherit system; };
              pkgs-go21 = import nixpkgs-go21 {
                inherit system;
                config = {
                  allowUnfree = true;
                  permittedInsecurePackages = [ ];
                };
              };
            in
            {
              devShells.default = pkgs.mkShell {
                NIX_HARDENING_ENABLE = "";

                packages = with pkgs; [
                  pkgs-go21.go_1_21
                  gcc
                  gopls
                  delve
                  go-tools
                ];

                shellHook = ${"''"}
                  export GOPATH="$HOME/go"
                  export GOBIN="$GOPATH/bin"
                  export PATH="$GOBIN:$PATH"
                  echo "Using Go version: $(go version)"
                ${"''"};
              };

              # Также можно определить пакеты для сборки
              # packages.default = pkgs-go21.buildGoModule {
              #   pname = "my-go-app";
              #   version = "0.1.0";
              #   src = ./.;
              #   vendorHash = null; # или "sha256-...+"
              # };
            }
          );
      }
    '';

  home.file."Work/.envrc".text = # bash
    ''
      use flake
      export GOPATH="$HOME/go"
      export PATH="$GOPATH/bin:$PATH"
    '';
}
