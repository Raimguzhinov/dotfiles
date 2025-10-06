{ config, pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.activation.createWorkDir =
    let
      flakeRaw = # nix
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
              nixpkgs-protobuf23 = {
                url = "github:NixOS/nixpkgs/ebe4301cbd8f81c4f8d3244b3632338bbeb6d49c";
                flake = false;
              };
              nixpkgs-gen-go-grpc1_3_0 = {
                url = "github:NixOS/nixpkgs/566e53c2ad750c84f6d31f9ccb9d00f823165550";
                flake = false;
              };
            };

            outputs =
              {
                self,
                nixpkgs,
                flake-utils,
                nixpkgs-go21,
                nixpkgs-protobuf23,
                nixpkgs-gen-go-grpc1_3_0,
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
                  pkgs-protobuf23 = import nixpkgs-protobuf23 {
                    inherit system;
                    config = {
                      allowUnfree = true;
                      permittedInsecurePackages = [ ];
                    };
                  };
                  protobuf23 = pkgs-protobuf23.protobuf_23.overrideAttrs {
                    version = "23.2";
                    src = pkgs.fetchFromGitHub {
                      owner = "protocolbuffers";
                      repo = "protobuf";
                      rev = "v23.2";
                      hash = "sha256-DBoxJFNjEKJYWtuVPlUR0JnFcDDBONGzQ9V3G1OAXpU=";
                    };
                  };
                  pkgs-gen-go-grpc1_3_0 = import nixpkgs-gen-go-grpc1_3_0 {
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
                      golangci-lint
                      gotestsum
                      protobuf23
                      pkgs-go21.protoc-gen-go
                      pkgs-gen-go-grpc1_3_0.protoc-gen-go-grpc
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
      envrcRaw = # bash
        ''
          use flake
          export GOPATH="$HOME/go"
          export PATH="$GOPATH/bin:$PATH"
        '';
    in
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ~/Work

      cat << 'EOF' > ~/Work/flake.nix
      ${flakeRaw}
      EOF

      cat << 'EOF' > ~/Work/.envrc
      ${envrcRaw}
      EOF
    '';

  home.packages =
    with pkgs;
    let
      fetch-srv-from-docker = pkgs.writeShellScriptBin "fetch-srv-from-docker" ''
        echo "docker cp core-$(basename "$PWD")-1:/home/uc/services/$(basename "$PWD")/$(basename "$PWD") ."
        docker cp core-$(basename "$PWD")-1:/home/uc/services/$(basename "$PWD")/$(basename "$PWD") .
      '';
    in
    [
      fetch-srv-from-docker
    ];
}
