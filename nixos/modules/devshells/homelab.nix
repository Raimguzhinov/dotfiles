{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      devShells.homelab = pkgs.mkShell {
        packages = with pkgs; [
          delve
          gcc
          go
          go-tools
          golangci-lint
          gopls
          gotestsum
          pkg-config
          protobuf
          protoc-gen-go
          protoc-gen-go-grpc
        ];

        shellHook = /* bash */ ''
          export GOROOT="${pkgs.go}/share/go"
          export GOPATH="$HOME/go"
          export GOBIN="$GOPATH/bin"
          export PATH="$GOROOT/bin:$GOBIN:$PATH"
          export GO111MODULE=on
          echo "Using Go version: $(go version)"
        '';
      };
    };
}
