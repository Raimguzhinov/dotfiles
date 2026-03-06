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
        delve1_25_2 = pkgs.buildGoModule rec {
          pname = "delve";
          version = "1.25.2";
          src = pkgs.fetchFromGitHub {
            owner = "go-delve";
            repo = "delve";
            rev = "v${version}";
            hash = "sha256-CtOaaYxqa4GwfDQ1yuUwRQPy948Xyha046TLTaq526w=";
          };
          vendorHash = null;
          subPackages = [ "cmd/dlv" ];
          preCheck = ''
            XDG_CONFIG_HOME=$(mktemp -d)
          '';
          preBuild = ''
            export CGO_ENABLED=0
            export GO111MODULE=on
          '';
          env = {
            CGO_ENABLED = 0;
            GO111MODULE = "on";
          };
          doCheck = true;
          postInstall = ''
            # add symlink for vscode golang extension
            # https://github.com/golang/vscode-go/blob/master/docs/debugging.md#manually-installing-dlv-dap
            ln $out/bin/dlv $out/bin/dlv-dap
          '';
          meta = {
            description = "Debugger for the Go programming language";
            homepage = "https://github.com/go-delve/delve";
            maintainers = with pkgs.lib.maintainers; [ vdemeester ];
            license = pkgs.lib.licenses.mit;
            mainProgram = "dlv";
          };
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            pkgs-go21.go_1_21
            gcc
            gopls
            delve1_25_2
            go-tools
            go-mockery_2
            golangci-lint
            gotestsum
            protobuf23
            pkgs-go21.protoc-gen-go
            pkgs-gen-go-grpc1_3_0.protoc-gen-go-grpc
            python3
            libwebp
            pkg-config
            rustc
            cargo
            nodejs_20
            yarn
            yarn2nix
            (pkgs.python3.withPackages (python-pkgs: with python-pkgs; [
              python-dotenv
              requests
              configparser
            ]))
          ];

          shellHook = ''
            export GOPATH="$HOME/go"
            export GOBIN="$GOPATH/bin"
            export PATH="$GOBIN:$PATH"
            export CGO_ENABLED=0
            export GO111MODULE=on
            export CGO_CFLAGS="-I@libwebp@/include"
            export CGO_LDFLAGS="-L@libwebp@/lib"
            export LD_LIBRARY_PATH="@libwebp@/lib:$LD_LIBRARY_PATH"
            export PKG_CONFIG_PATH="@libwebp@/lib/pkgconfig:$PKG_CONFIG_PATH"
            echo "Using Go version: $(go version)"
          '';
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
