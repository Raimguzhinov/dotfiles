{ config, pkgs, ... }:

{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.activation.createWorkDir =
    let
      flakeRaw = ''
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
                    rev = "v${"$"}{version}";
                    hash = "sha256-CtOaaYxqa4GwfDQ1yuUwRQPy948Xyha046TLTaq526w=";
                  };
                  vendorHash = null;
                  subPackages = [ "cmd/dlv" ];
                  preCheck = ${"''"}
                    XDG_CONFIG_HOME=$(mktemp -d)
                  ${"''"};
                  preBuild = ${"''"}
                    export CGO_ENABLED=0
                    export GO111MODULE=on
                  ${"''"};
                  env = {
                    CGO_ENABLED = 0;
                    GO111MODULE = "on";
                  };
                  doCheck = true;
                  postInstall = ${"''"}
                    # add symlink for vscode golang extension
                    # https://github.com/golang/vscode-go/blob/master/docs/debugging.md#manually-installing-dlv-dap
                    ln $out/bin/dlv $out/bin/dlv-dap
                  ${"''"};
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
                    libwebp
                    pkg-config
                  ];

                  shellHook = ${"''"}
                    export GOPATH="$HOME/go"
                    export GOBIN="$GOPATH/bin"
                    export PATH="$GOBIN:$PATH"
                    export CGO_ENABLED=0
                    export GO111MODULE=on
                    export CGO_CFLAGS="-I${pkgs.libwebp}/include"
                    export CGO_LDFLAGS="-L${pkgs.libwebp}/lib"
                    export LD_LIBRARY_PATH="${pkgs.libwebp}/lib:$LD_LIBRARY_PATH"
                    export PKG_CONFIG_PATH="${pkgs.libwebp}/lib/pkgconfig:$PKG_CONFIG_PATH"
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
      envrcRaw = ''
        count=$(find . -type s -name 'mgmt.sock' -printf . | wc -c)
        if [ "$count" -gt 0 ]; then
            sudo find . -type s -name 'mgmt.sock' -delete
            echo "Cleaned up $count mgmt.sock files"
        fi
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

      cat << 'EOF' > ~/Work/.envrc.nix
      ${envrcRaw}
      EOF
    '';

  # Scripts
  home.packages =
    let
      fetch-srv-from-docker = pkgs.writeShellScriptBin "fetch-srv-from-docker" ''
        echo "docker cp $(basename "$PWD"):/home/protei/Protei-UC/$(basename "$PWD")/$(basename "$PWD") ."
        ${pkgs.docker}/bin/docker cp $(basename "$PWD"):/home/protei/Protei-UC/$(basename "$PWD")/$(basename "$PWD") .
      '';
      ssh-setup-dlv = pkgs.writeShellScriptBin "ssh-setup-dlv" ''
        if [ $# -ne 1 ]; then
            echo "Usage: $0 user@hostname"
            exit 1
        fi
        HOST="$1"
        scp $(which dlv) "$HOST":~/
        ssh -t "$HOST" "sudo mv /home/support/dlv /usr/bin/dlv > /dev/null && \
                        sudo chmod +x /usr/bin/dlv > /dev/null"
        # ssh -t "$HOST" "cd /tmp && wget https://go.dev/dl/go1.21.13.linux-amd64.tar.gz >/dev/null && \
        #     sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go1.21.13.linux-amd64.tar.gz >/dev/null && \
        #     echo 'export PATH=\$PATH:/usr/local/go/bin' | sudo tee -a /root/.bashrc > /dev/null && \
        #     echo 'export GOROOT=/home/support/go' | sudo tee -a /root/.bashrc > /dev/null && \
        #     echo 'export PATH=\$PATH:\$GOROOT/bin' | sudo tee -a /root/.bashrc > /dev/null && \
        #     echo 'export PATH=\$PATH:/usr/local/go/bin' | tee -a /home/support/.bashrc > /dev/null && \
        #     echo 'export GOROOT=/home/support/go' | tee -a /home/support/.bashrc > /dev/null && \
        #     echo 'export PATH=\$PATH:\$GOROOT/bin' | tee -a /home/support/.bashrc > /dev/null && \
        #     sudo rm /tmp/go1.21.13.linux-amd64.tar.gz && \
        #     mkdir -p /home/support/go/bin
        #     /usr/local/go/bin/go install github.com/go-delve/delve/cmd/dlv@v1.22.1"
        echo "✅ Delve для дебага настроен на $HOST."
        echo "Goland -> Run/Debug Configurations -> Add New Configuration -> Go Remote"
        echo "Далее следуйте инструкциям"
      '';
      remoteDebugRawScript = pkgs.writeText "remoteDebugRawScript" ''
        export SERVICE_PATH=$(dirname $(dirname $(sudo find /home/protei/Protei-UC -follow -type f -path "*/bin/$SERVICE" | grep -v -- "-[0-9]\+/" | head -1))) && \
        echo $SERVICE_PATH && \
        sudo mv $SERVICE_PATH/bin/$SERVICE $SERVICE_PATH/bin/$SERVICE.bak && \
        sudo mv /home/support/$SERVICE $SERVICE_PATH/bin/$SERVICE && \
        sudo chmod +x $SERVICE_PATH/bin/$SERVICE && \
        echo $SERVICE_PATH/stop && \
        (sudo $SERVICE_PATH/stop || true) && \
        echo "dlv --listen=:$PORT --headless=true --api-version=2 --accept-multiclient exec ./bin/$SERVICE" && \
        echo "✅ Delve запущен на $HOST и слушает :$PORT порт для отладки $SERVICE" && \
        sudo bash -c "cd $SERVICE_PATH && dlv --listen=:$PORT --headless=true --api-version=2 --accept-multiclient exec ./bin/$SERVICE" && \
        echo "mv $SERVICE_PATH/bin/$SERVICE.bak $SERVICE_PATH/bin/$SERVICE" && \
        sudo mv $SERVICE_PATH/bin/$SERVICE.bak $SERVICE_PATH/bin/$SERVICE && \
        (sudo $SERVICE_PATH/start || true)
      '';
      ssh-run-debugger = pkgs.writeShellScriptBin "ssh-run-debugger" ''
        if [ $# -ne 2 ]; then
            echo "Usage: $0 user@hostname <debugger-port>"
            exit 1
        fi
        HOST="$1"
        PORT="$2"
        SERVICE=$(basename "$PWD")
        CUSTOM_BUILD_FLAGS='-gcflags "all=-N -l"' make compile
        scp "$SERVICE" "$HOST":~/
        scp ${remoteDebugRawScript} "$HOST":/tmp/dlv.sh
        ssh -t "$HOST" "echo "For $SERVICE on :$PORT" && \
                        sudo chmod +x /tmp/dlv.sh && \
                        SERVICE=$SERVICE PORT=$PORT /tmp/dlv.sh"
      '';
      ssh-copy-vimrc = pkgs.writeShellScriptBin "ssh-copy-vimrc" ''
        if [ $# -ne 1 ]; then
            echo "Usage: $0 user@hostname"
            exit 1
        fi
        HOST="$1"
        VIMRC_CONTENT='let mapleader = " "
        set scrolloff=5
        set incsearch
        set number
        set relativenumber
        set clipboard=unnamedplus
        map Q gq
        vmap v V
        imap jk <Esc>
        map <leader>w :w<CR>
        map <leader>q :q<CR>
        map <leader>sv :vsplit<CR>
        map <leader>sh :split<CR>
        map <tab> :tabnext<CR>
        map <S-tab> :tabprevious<CR>
        map <leader>ff :find<space>'
        ssh "$HOST" "echo 'alias nvim=vim' >> ~/.bashrc && \
                     echo 'alias clr=clear' >> ~/.bashrc && \
                     echo 'alias rr=yazi' >> ~/.bashrc && \
                     cat > ~/.vimrc" <<< "$VIMRC_CONTENT"
        scp ${pkgs.yazi}/bin/yazi "$HOST":~/
        ssh -t "$HOST" "echo 'alias nvim=vim' | sudo tee -a /root/.bashrc > /dev/null && \
                        echo 'alias clr=clear' | sudo tee -a /root/.bashrc > /dev/null && \
                        echo 'alias rr=yazi' | sudo tee -a /root/.bashrc > /dev/null && \
                        sudo mv /home/support/yazi /usr/bin/yazi > /dev/null && \
                        sudo chmod +x /usr/bin/yazi > /dev/null && \
                        echo '$VIMRC_CONTENT' | sudo tee /root/.vimrc > /dev/null"
        echo "✅ .vimrc установлен для пользователя и root на $HOST"
      '';
    in
    [
      fetch-srv-from-docker
      ssh-setup-dlv
      ssh-run-debugger
      ssh-copy-vimrc
    ];
}
