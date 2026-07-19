{ ... }:
{
  perSystem =
    { pkgs, inputs', ... }:
    let
      pkgs-go21 = inputs'.nixpkgs-go21.legacyPackages;
      pkgs-protobuf23 = inputs'.nixpkgs-protobuf23.legacyPackages;
      pkgs-protoc-gen-go-grpc = inputs'.nixpkgs-protoc-gen-go-grpc1_3_0.legacyPackages;
      pkgs-protoc-gen-go = inputs'.nixpkgs-protoc-gen-go1_36_1.legacyPackages;
      protobuf23 = pkgs-protobuf23.protobuf_23.overrideAttrs {
        version = "23.2";
        src = pkgs.fetchFromGitHub {
          owner = "protocolbuffers";
          repo = "protobuf";
          rev = "v23.2";
          hash = "sha256-DBoxJFNjEKJYWtuVPlUR0JnFcDDBONGzQ9V3G1OAXpU=";
        };
      };
      delve = pkgs-go21.buildGoModule rec {
        pname = "delve";
        version = "1.21.2";
        src = pkgs.fetchFromGitHub {
          owner = "go-delve";
          repo = "delve";
          rev = "v${version}";
          hash = "sha256-DgRqdO7ztQ57B6N9ABcI2D/SQkUVh/IUib8/xk3EeRA=";
        };
        vendorHash = null;
        subPackages = [ "cmd/dlv" ];
        CGO_ENABLED = 0;
        doCheck = false;
        postInstall = ''
          ln $out/bin/dlv $out/bin/dlv-dap
        '';
        meta = {
          description = "Debugger for the Go programming language";
          homepage = "https://github.com/go-delve/delve";
          license = pkgs.lib.licenses.mit;
          mainProgram = "dlv";
        };
      };
    in
    {
      devShells.go = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          cmake
          delve
          gcc
          gdlv
          go-mockery_2
          go-tools
          gopls
          gotestsum
          libwebp
          libxml2

          pkg-config
          pkgs-go21.go_1_21
          pkgs-go21.golangci-lint
          pkgs-protoc-gen-go-grpc.protoc-gen-go-grpc
          pkgs-protoc-gen-go.protoc-gen-go
          protobuf23
          rustc

          zstd
        ];

        shellHook = /* bash */ ''
          export GOROOT="${pkgs-go21.go_1_21}/share/go"
          export GOPATH="$HOME/go"
          export GOBIN="$GOPATH/bin"
          export PATH="$GOROOT/bin:$GOBIN:$PATH"
          export CGO_ENABLED=0
          export GO111MODULE=on
          export CGO_CFLAGS="-I${pkgs.libwebp}/include"
          export CGO_LDFLAGS="-L${pkgs.libwebp}/lib"
          export LD_LIBRARY_PATH="${pkgs.libwebp}/lib:$LD_LIBRARY_PATH"
          export PKG_CONFIG_PATH="${pkgs.libwebp}/lib/pkgconfig:$PKG_CONFIG_PATH"
          export PKG_CONFIG_PATH="${pkgs.zstd.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
          echo "Using Go version: $(go version)"
        '';
      };
    };
}
