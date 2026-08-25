{ ... }:
{
  flake.homeModules.development =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      programs.direnv = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        nix-direnv.enable = true;
      };

      home.activation.createWorkDir =
        let
          shellsDir = "${config.home.homeDirectory}/dotfiles/nixos/devshells";
          workEnvrc = pkgs.writeText "work-envrc" /* bash */ ''
            use flake ${shellsDir}#work
          '';
        in
        config.lib.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
          mkdir -p ~/Work

          if ! diff -q ${workEnvrc} ~/Work/.envrc > /dev/null 2>&1; then
            install -m 644 ${workEnvrc} ~/Work/.envrc
          fi
        '';

      # Scripts
      home.packages =
        let
          fetch-srv-from-docker =
            pkgs.writeShellScriptBin "fetch-srv-from-docker"
              # bash
              ''
                svc_root=$(cat ${config.sops.secrets."product/services_root".path})
                echo "docker cp $(basename "$PWD"):$svc_root/$(basename "$PWD")/$(basename "$PWD") ."
                ${lib.getExe pkgs.docker} cp $(basename "$PWD"):$svc_root/$(basename "$PWD")/$(basename "$PWD") .
              '';
          ssh-setup-dlv =
            pkgs.writeShellScriptBin "ssh-setup-dlv" # bash
              ''
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
          remoteDebugRawScript =
            pkgs.writeText "remoteDebugRawScript" # bash
              ''
                svc_root=$(cat ${config.sops.secrets."product/services_root".path})
                export SERVICE_PATH=$(dirname $(dirname $(sudo find $svc_root -follow -type f -path "*/bin/$SERVICE" | grep -v -- "-[0-9]\+/" | head -1))) && \
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
          ssh-run-debugger =
            pkgs.writeShellScriptBin "ssh-run-debugger" # bash
              ''
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
          ssh-copy-vimrc =
            pkgs.writeShellScriptBin "ssh-copy-vimrc" # bash
              ''
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
                scp ${lib.getExe pkgs.yazi} "$HOST":~/
                ssh -t "$HOST" "echo 'alias nvim=vim' | sudo tee -a /root/.bashrc > /dev/null && \
                                echo 'alias clr=clear' | sudo tee -a /root/.bashrc > /dev/null && \
                                echo 'alias rr=yazi' | sudo tee -a /root/.bashrc > /dev/null && \
                                sudo mv /home/support/yazi /usr/bin/yazi > /dev/null && \
                                sudo chmod +x /usr/bin/yazi > /dev/null && \
                                echo '$VIMRC_CONTENT' | sudo tee /root/.vimrc > /dev/null"
                echo "✅ .vimrc установлен для пользователя и root на $HOST"
              '';
          # tracktime =
          #   pkgs.writeShellScriptBin "tracktime" # bash
          #     ''
          #       if [ $# -ne 1 ]; then
          #           echo "Usage   : $(basename $0) date,issue,duration,workType,description"
          #           echo "Example : $(basename $0) 2026-02-17,UC-9750,20m,Discuss,"
          #           echo
          #           echo "Unclassified tasks:"
          #           echo "UC-9750 Учет времени на запланированные митапы"
          #           echo "EDU-557 Учёт времени на переезд, перелёт, настройку ОС, фоновые задачи и саморазвитие"
          #           exit 1
          #       fi
          #       temp_file=$(mktemp --suffix=.csv)
          #       cat << EOF > $temp_file
          #       date,issue,duration,workType,description
          #       ${"$"}{@:1}
          #       EOF
          #       echo "log track entry: $temp_file"
          #       cd $HOME/Work/yt-time-tracker
          #       ./yt_time_tracker.py $temp_file
          #       cd -
          #     '';
        in
        [
          fetch-srv-from-docker
          ssh-setup-dlv
          ssh-run-debugger
          ssh-copy-vimrc
          # tracktime

          # Default Go toolchain on PATH so gopls works everywhere. Inside
          # ~/Work, direnv loads the devshell which prepends go 1.21 and wins;
          # outside ~/Work this nixpkgs Go is used.
          pkgs.go
          pkgs.nodejs
        ];
    };
}
