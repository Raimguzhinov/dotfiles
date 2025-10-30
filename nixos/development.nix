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
          count=$(find . -type s -name 'mgmt.sock' -printf . | wc -c)
          if [ "$count" -gt 0 ]; then
              sudo find . -type s -name 'mgmt.sock' -delete
              echo "Cleaned up $count mgmt.sock file(s)"
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

      cat << 'EOF' > ~/Work/.envrc
      ${envrcRaw}
      EOF
    '';

  # Scripts
  home.packages =
    let
      fetch-srv-from-docker = pkgs.writeShellScriptBin "fetch-srv-from-docker" ''
        echo "docker cp $(basename "$PWD"):/home/uc/services/$(basename "$PWD")/$(basename "$PWD") ."
        ${pkgs.docker}/bin/docker cp $(basename "$PWD"):/home/uc/services/$(basename "$PWD")/$(basename "$PWD") .
      '';
      ssh-setup-dlv = pkgs.writeShellScriptBin "ssh-setup-dlv" ''
        if [ $# -eq 0 ]; then
            echo "Usage: $0 user@hostname"
            exit 1
        fi
        HOST="$1"
        ssh -t "$HOST" "cd /tmp && wget https://go.dev/dl/go1.21.13.linux-amd64.tar.gz >/dev/null && \
            sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go1.21.13.linux-amd64.tar.gz >/dev/null && \
            echo '\nexport PATH=\$PATH:/usr/local/go/bin' | sudo tee -a /root/.bashrc > /dev/null && \
            echo 'export GOROOT=/home/support/go' | sudo tee -a /root/.bashrc > /dev/null && \
            echo 'export PATH=\$PATH:\$GOROOT/bin' | sudo tee -a /root/.bashrc > /dev/null && \
            echo '\nexport PATH=\$PATH:/usr/local/go/bin' | tee -a /home/support/.bashrc > /dev/null && \
            echo 'export GOROOT=/home/support/go' | tee -a /home/support/.bashrc > /dev/null && \
            echo 'export PATH=\$PATH:\$GOROOT/bin' | tee -a /home/support/.bashrc > /dev/null && \
            sudo rm /tmp/go1.21.13.linux-amd64.tar.gz && \
            mkdir -p /home/support/go/bin
            /usr/local/go/bin/go install github.com/go-delve/delve/cmd/dlv@v1.22.1"
        echo "✅ delve для дебага настроен на $HOST."
        echo "Goland -> Run/Debug Configurations -> Add New Configuration -> Go Remote"
        echo "Далее следуйте инструкциям"
      '';
      ssh-copy-vimrc = pkgs.writeShellScriptBin "ssh-copy-vimrc" ''
        if [ $# -eq 0 ]; then
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
        ssh "$HOST" "echo '\nalias nvim=vim' >> ~/.bashrc && \
                     echo 'alias clr=clear' >> ~/.bashrc && \
                     echo 'alias rr=lf' >> ~/.bashrc && \
                     cat > ~/.vimrc" <<< "$VIMRC_CONTENT"
        scp ${pkgs.lf}/bin/lf "$HOST":~/
        ssh -t "$HOST" "echo '\nalias nvim=vim' | sudo tee -a /root/.bashrc > /dev/null && \
                        echo 'alias clr=clear' | sudo tee -a /root/.bashrc > /dev/null && \
                        echo 'alias rr=lf' | sudo tee -a /root/.bashrc > /dev/null && \
                        sudo mv /home/support/lf /usr/bin/lf > /dev/null && \
                        sudo chmod +x /usr/bin/lf > /dev/null && \
                        echo '$VIMRC_CONTENT' | sudo tee /root/.vimrc > /dev/null"
        echo "✅ .vimrc установлен для пользователя и root на $HOST"
      '';
      ssh-run-debugger = pkgs.writeShellScriptBin "ssh-run-debugger" ''
        if [ $# -eq 0 ]; then
            echo "Usage: $0 user@hostname"
            exit 1
        fi
        HOST="$1"
      '';
    in
    [
      fetch-srv-from-docker
      ssh-setup-dlv
      ssh-copy-vimrc
      ssh-run-debugger
    ];
}
