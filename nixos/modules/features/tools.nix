{ ... }:
{
  flake.homeModules.tools =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Рецепты из https://yazi-rs.github.io/docs/tips, которых нет в
      # pkgs.yaziPlugins
      mkYaziPlugin =
        name: lua:
        pkgs.runCommand "${name}.yazi" { } ''
          mkdir -p "$out"
          install -m444 ${pkgs.writeText "${name}-main.lua" lua} "$out/main.lua"
        '';
    in
    {
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        initContent = ''
          # open commands in $EDITOR with C-g, inspired by Claude Code behavior
          autoload -z edit-command-line
          zle -N edit-command-line
          bindkey "^g" edit-command-line

          # Post-install reminder until hardware-configuration.nix is committed
          if [[ -n "$(git -C ~/dotfiles status --porcelain nixos/hardware-configuration.nix 2>/dev/null)" ]]; then
            awk 'found && /^---/{exit} /^## После первой загрузки/{found=1} found' ~/dotfiles/README.md | glow -
          fi

          tailf() {
            tail -f "$@" | bat --paging=never -l log -p
          }

          compdef _files tailf

          drestart() {
            docker restart "$@"
          }

          _drestart() {
            words=(docker restart "''
        + "$"
        + ''
          {words[@]:1}")
                      CURRENT=$((CURRENT + 1))
                      _docker
                    }

                    compdef _drestart drestart

        '';
        oh-my-zsh = {
          enable = true;
          plugins = [
            "docker"
            "docker-compose"
            "extract"
            "git"
            "sudo"
          ];
          # theme = "robbyrussell";
        };
        shellAliases = {
          e = "exit";
          ll = "ls -l";
          la = "ls -la";
          mv = "mv -iv";
          cp = "cp -riv";
          clr = "clear";
          cat = "bat -p";
          "дф" = "ls -la";
          "св" = "cd";
          "cd.." = "cd ..";
          sudo = "sudo ";
          tree = "eza --tree";
          pass = "gopass";
          fuck = "sudo !!";
          open = "xdg-open";
          ping = "ping -c 5";
          dbui = "nvim +DBUI";
          http = "xh";
          https = "xhs";
          mkdir = "mkdir -vp";
          "тмшь" = "nvim";
          nvimdiff = "nvim -d";
          review = ''nvim "+DiffviewOpen origin/HEAD...HEAD"'';
          bigreview = ''nvim "+DiffviewFileHistory --range=origin/HEAD...HEAD --right-only --no-merges"'';
          inspectstash = ''nvim "+DiffviewFileHistory -g --range=stash"'';
          genpass = "gopass generate -sc"; # 'genpass example.com/login [ field ]' with copy
          "l." = "ls -d .* --color=auto";
          unicom-debug = lib.concatStringsSep " " [
            "chromium"
            "--user-data-dir=/tmp/chrome-tls-debug"
            "--ssl-key-log-file=${config.home.homeDirectory}/.ssl-key.log"
            "https://localhost:8443"
          ];
        };
      };

      programs.zoxide = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        options = [ "--cmd cd" ];
      };

      programs.atuin = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        settings = {
          keymap_mode = "auto";
          inline_height = 20;
          enter_accept = false;
        };
      };

      programs.zellij = {
        enable = true;
        attachExistingSession = false;
        enableBashIntegration = false;
        enableZshIntegration = false;
        settings = {
          theme = "ayu_mirage"; # "ao";
          default_layout = "compact"; # Hide the bar
          # default_mode = "locked";
          copy_command = "wl-copy";
          copy_clipboard = "primary";
          default_shell = "zsh";
          simplified_ui = true;
          pane_frames = false;
          show_startup_tips = true;
          ui.pane_frames = {
            rounded_corners = true;
            hide_session_name = true;
          };
          plugins = {
            compact-bar = {
              _props = {
                location = "zellij:compact-bar";
              };
              tooltip = "F1";
            };
          };
          web_server_ip = "0.0.0.0";
          web_server_cert = "${config.home.homeDirectory}/.cert/zellij.local/zellij.crt";
          web_server_key = "${config.home.homeDirectory}/.cert/zellij.local/zellij.key";
        };
        extraConfig = ''
          keybinds clear-defaults=true {
              locked {
                  bind "Alt g" { SwitchToMode "normal"; }
              }
              pane {
                  bind "left" { MoveFocus "left"; }
                  bind "down" { MoveFocus "down"; }
                  bind "up" { MoveFocus "up"; }
                  bind "right" { MoveFocus "right"; }
                  bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
                  bind "d" { NewPane "down"; SwitchToMode "normal"; }
                  bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "normal"; }
                  bind "f" { ToggleFocusFullscreen; SwitchToMode "normal"; }
                  bind "h" { MoveFocus "left"; }
                  bind "i" { TogglePanePinned; SwitchToMode "normal"; }
                  bind "j" { MoveFocus "down"; }
                  bind "k" { MoveFocus "up"; }
                  bind "l" { MoveFocus "right"; }
                  bind "n" { NewPane; SwitchToMode "normal"; }
                  bind "p" { SwitchFocus; }
                  bind "Alt p" { SwitchToMode "normal"; }
                  bind "r" { NewPane "right"; SwitchToMode "normal"; }
                  bind "s" { NewPane "stacked"; SwitchToMode "normal"; }
                  bind "w" { ToggleFloatingPanes; SwitchToMode "normal"; }
                  bind "z" { TogglePaneFrames; SwitchToMode "normal"; }
              }
              tab {
                  bind "left" { GoToPreviousTab; }
                  bind "down" { GoToNextTab; }
                  bind "up" { GoToPreviousTab; }
                  bind "right" { GoToNextTab; }
                  bind "1" { GoToTab 1; SwitchToMode "normal"; }
                  bind "2" { GoToTab 2; SwitchToMode "normal"; }
                  bind "3" { GoToTab 3; SwitchToMode "normal"; }
                  bind "4" { GoToTab 4; SwitchToMode "normal"; }
                  bind "5" { GoToTab 5; SwitchToMode "normal"; }
                  bind "6" { GoToTab 6; SwitchToMode "normal"; }
                  bind "7" { GoToTab 7; SwitchToMode "normal"; }
                  bind "8" { GoToTab 8; SwitchToMode "normal"; }
                  bind "9" { GoToTab 9; SwitchToMode "normal"; }
                  bind "[" { BreakPaneLeft; SwitchToMode "normal"; }
                  bind "]" { BreakPaneRight; SwitchToMode "normal"; }
                  bind "b" { BreakPane; SwitchToMode "normal"; }
                  bind "h" { GoToPreviousTab; }
                  bind "j" { GoToNextTab; }
                  bind "k" { GoToPreviousTab; }
                  bind "l" { GoToNextTab; }
                  bind "n" { NewTab; SwitchToMode "normal"; }
                  bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
                  bind "s" { ToggleActiveSyncTab; SwitchToMode "normal"; }
                  bind "Alt t" { SwitchToMode "normal"; }
                  bind "x" { CloseTab; SwitchToMode "normal"; }
                  bind "tab" { ToggleTab; }
              }
              resize {
                  bind "left" { Resize "Increase left"; }
                  bind "down" { Resize "Increase down"; }
                  bind "up" { Resize "Increase up"; }
                  bind "right" { Resize "Increase right"; }
                  bind "+" { Resize "Increase"; }
                  bind "-" { Resize "Decrease"; }
                  bind "=" { Resize "Increase"; }
                  bind "H" { Resize "Decrease left"; }
                  bind "J" { Resize "Decrease down"; }
                  bind "K" { Resize "Decrease up"; }
                  bind "L" { Resize "Decrease right"; }
                  bind "h" { Resize "Increase left"; }
                  bind "j" { Resize "Increase down"; }
                  bind "k" { Resize "Increase up"; }
                  bind "l" { Resize "Increase right"; }
                  bind "Alt n" { SwitchToMode "normal"; }
              }
              move {
                  bind "left" { MovePane "left"; }
                  bind "down" { MovePane "down"; }
                  bind "up" { MovePane "up"; }
                  bind "right" { MovePane "right"; }
                  bind "h" { MovePane "left"; }
                  bind "Alt h" { SwitchToMode "normal"; }
                  bind "j" { MovePane "down"; }
                  bind "k" { MovePane "up"; }
                  bind "l" { MovePane "right"; }
                  bind "n" { MovePane; }
                  bind "p" { MovePaneBackwards; }
                  bind "tab" { MovePane; }
              }
              scroll {
                  bind "Alt left" { MoveFocusOrTab "left"; SwitchToMode "normal"; }
                  bind "Alt down" { MoveFocus "down"; SwitchToMode "normal"; }
                  bind "Alt up" { MoveFocus "up"; SwitchToMode "normal"; }
                  bind "Alt right" { MoveFocusOrTab "right"; SwitchToMode "normal"; }
                  bind "e" { EditScrollback; SwitchToMode "normal"; }
                  bind "Alt j" { MoveFocus "down"; SwitchToMode "normal"; }
                  bind "Alt k" { MoveFocus "up"; SwitchToMode "normal"; }
                  bind "Alt l" { MoveFocusOrTab "right"; SwitchToMode "normal"; }
                  bind "s" { SwitchToMode "entersearch"; SearchInput 0; }
                  bind "Alt s" { SwitchToMode "normal"; }
              }
              search {
                  bind "c" { SearchToggleOption "CaseSensitivity"; }
                  bind "n" { Search "down"; }
                  bind "o" { SearchToggleOption "WholeWord"; }
                  bind "p" { Search "up"; }
                  bind "w" { SearchToggleOption "Wrap"; }
              }
              session {
                  bind "a" {
                      LaunchOrFocusPlugin "zellij:about" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "normal"
                  }
                  bind "c" {
                      LaunchOrFocusPlugin "configuration" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "normal"
                  }
                  bind "Alt o" { SwitchToMode "normal"; }
                  bind "p" {
                      LaunchOrFocusPlugin "plugin-manager" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "normal"
                  }
                  bind "s" {
                      LaunchOrFocusPlugin "zellij:share" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "normal"
                  }
                  bind "w" {
                      LaunchOrFocusPlugin "session-manager" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "normal"
                  }
              }
              shared_among "normal" "locked" {
                  bind "Ctrl left" { MoveFocusOrTab "left"; }
                  bind "Ctrl down" { MoveFocus "down"; }
                  bind "Ctrl up" { MoveFocus "up"; }
                  bind "Ctrl right" { MoveFocusOrTab "right"; }
                  bind "Ctrl +" { Resize "Increase"; }
                  bind "Ctrl -" { Resize "Decrease"; }
                  bind "Ctrl =" { Resize "Increase"; }
                  bind "Ctrl [" { PreviousSwapLayout; }
                  bind "Ctrl ]" { NextSwapLayout; }
                  bind "Ctrl f" { ToggleFloatingPanes; }
                  bind "Ctrl h" { MoveFocusOrTab "left"; }
                  bind "Ctrl i" { MoveTab "left"; }
                  bind "Ctrl j" { MoveFocus "down"; }
                  bind "Ctrl k" { MoveFocus "up"; }
                  bind "Ctrl l" { MoveFocusOrTab "right"; }
                  bind "Ctrl n" { NewPane; }
                  bind "Ctrl Shift o" { MoveTab "right"; }
              }
              shared_except "locked" {
                  bind "Alt Shift p" { ToggleGroupMarking; }
              }
              shared_except "locked" "entersearch" "renametab" "renamepane" "move" "prompt" "tmux" {
                  bind "Alt h" { SwitchToMode "move"; }
              }
              shared_except "locked" "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Alt g" { SwitchToMode "locked"; }
                  bind "Alt q" { Quit; }
              }
              shared_except "locked" "entersearch" "renametab" "renamepane" "session" "prompt" "tmux" {
                  bind "Alt o" { SwitchToMode "session"; }
              }
              shared_except "locked" "scroll" "search" "tmux" {
                  bind "Ctrl a" { SwitchToMode "tmux"; }
              }
              shared_except "locked" "scroll" "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Alt s" { SwitchToMode "scroll"; }
              }
              shared_except "locked" "tab" "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Alt t" { SwitchToMode "tab"; }
              }
              shared_except "locked" "pane" "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Alt p" { SwitchToMode "pane"; }
              }
              shared_except "locked" "resize" "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Alt n" { SwitchToMode "resize"; }
              }
              shared_except "normal" "locked" {
                  bind "Alt +" { Resize "Increase"; }
                  bind "Alt -" { Resize "Decrease"; }
                  bind "Alt =" { Resize "Increase"; }
                  bind "Alt [" { PreviousSwapLayout; }
                  bind "Alt ]" { NextSwapLayout; }
                  bind "Alt f" { ToggleFloatingPanes; }
                  bind "Alt i" { MoveTab "left"; }
              }
              shared_except "normal" "locked" "entersearch" {
                  bind "enter" { SwitchToMode "normal"; }
              }
              shared_except "normal" "locked" "entersearch" "renametab" "renamepane" {
                  bind "esc" { SwitchToMode "normal"; }
              }
              shared_except "normal" "locked" "scroll" {
                  bind "Alt left" { MoveFocusOrTab "left"; }
                  bind "Alt down" { MoveFocus "down"; }
                  bind "Alt up" { MoveFocus "up"; }
                  bind "Alt right" { MoveFocusOrTab "right"; }
                  bind "Alt j" { MoveFocus "down"; }
                  bind "Alt k" { MoveFocus "up"; }
                  bind "Alt l" { MoveFocusOrTab "right"; }
              }
              shared_among "pane" "tmux" {
                  bind "x" { CloseFocus; SwitchToMode "normal"; }
              }
              shared_among "scroll" "search" {
                  bind "PageDown" { PageScrollDown; }
                  bind "PageUp" { PageScrollUp; }
                  bind "left" { PageScrollUp; }
                  bind "down" { ScrollDown; }
                  bind "up" { ScrollUp; }
                  bind "right" { PageScrollDown; }
                  bind "Ctrl b" { PageScrollUp; }
                  bind "Ctrl c" { ScrollToBottom; SwitchToMode "normal"; }
                  bind "d" { HalfPageScrollDown; }
                  bind "Ctrl f" { PageScrollDown; }
                  bind "h" { PageScrollUp; }
                  bind "j" { ScrollDown; }
                  bind "k" { ScrollUp; }
                  bind "l" { PageScrollDown; }
                  bind "u" { HalfPageScrollUp; }
              }
              entersearch {
                  bind "Ctrl c" { SwitchToMode "scroll"; }
                  bind "esc" { SwitchToMode "scroll"; }
                  bind "enter" { SwitchToMode "search"; }
              }
              shared_among "entersearch" "renametab" "renamepane" "prompt" "tmux" {
                  bind "Ctrl g" { SwitchToMode "locked"; }
                  bind "Ctrl h" { SwitchToMode "move"; }
                  bind "Alt h" { MoveFocusOrTab "left"; }
                  bind "Ctrl n" { SwitchToMode "resize"; }
                  bind "Alt n" { NewPane; }
                  bind "Ctrl o" { SwitchToMode "session"; }
                  bind "Alt o" { MoveTab "right"; }
                  bind "Ctrl p" { SwitchToMode "pane"; }
                  bind "Alt p" { TogglePaneInGroup; }
                  bind "Ctrl q" { Quit; }
                  bind "Ctrl s" { SwitchToMode "scroll"; }
                  bind "Ctrl t" { SwitchToMode "tab"; }
              }
              renametab {
                  bind "esc" { UndoRenameTab; SwitchToMode "tab"; }
              }
              shared_among "renametab" "renamepane" {
                  bind "Ctrl c" { SwitchToMode "normal"; }
              }
              renamepane {
                  bind "esc" { UndoRenamePane; SwitchToMode "pane"; }
              }
              shared_among "session" "tmux" {
                  bind "d" { Detach; }
              }
              tmux {
                  bind "left" { MoveFocus "left"; SwitchToMode "normal"; }
                  bind "down" { MoveFocus "down"; SwitchToMode "normal"; }
                  bind "up" { MoveFocus "up"; SwitchToMode "normal"; }
                  bind "right" { MoveFocus "right"; SwitchToMode "normal"; }
                  bind "space" { NextSwapLayout; }
                  bind "\"" { NewPane "down"; SwitchToMode "normal"; }
                  bind "%" { NewPane "right"; SwitchToMode "normal"; }
                  bind "," { SwitchToMode "renametab"; }
                  bind "[" { SwitchToMode "scroll"; }
                  bind "Ctrl a" { Write 2; SwitchToMode "normal"; }
                  bind "n" { NewTab; SwitchToMode "normal"; }
                  bind "h" { MoveFocus "left"; SwitchToMode "normal"; }
                  bind "j" { MoveFocus "down"; SwitchToMode "normal"; }
                  bind "k" { MoveFocus "up"; SwitchToMode "normal"; }
                  bind "l" { MoveFocus "right"; SwitchToMode "normal"; }
                  bind "1" { GoToNextTab; SwitchToMode "normal"; }
                  bind "2" { GoToNextTab; SwitchToMode "normal"; }
                  bind "3" { GoToNextTab; SwitchToMode "normal"; }
                  bind "4" { GoToNextTab; SwitchToMode "normal"; }
                  bind "o" { FocusNextPane; }
                  bind "p" { GoToPreviousTab; SwitchToMode "normal"; }
                  bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
              }
          }
        '';
      };

      home.packages = [
        pkgs.dragon-drop
        (pkgs.writeShellScriptBin "rr" ''
          exec ${lib.getExe pkgs.yazi} "$@"
        '')
      ];

      programs.yazi = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        shellWrapperName = "rr";
        # Архиваторы для compress.yazi; ouch добирает форматы, которых нет в
        # 7zz (rar, lz4, br, sz, bz3, lz).
        extraPackages = with pkgs; [
          bzip2
          gnutar
          gzip
          lz4
          (ouch.override { enableUnfree = true; })
          xz
          zip
          zstd
        ];
        initLua = # lua
          ''
            require("zoxide"):setup {
            	update_db = true,
            }

            Status:children_add(function()
            	local h = cx.active.current.hovered
            	if not h or ya.target_family() ~= "unix" then
            		return ""
            	end

            	return ui.Line {
            		ui.Span(ya.user_name(h.cha.uid) or tostring(h.cha.uid)):fg("magenta"),
            		":",
            		ui.Span(ya.group_name(h.cha.gid) or tostring(h.cha.gid)):fg("magenta"),
            		" ",
            	}
            end, 500, Status.RIGHT)
          '';
        settings = {
          mgr = {
            show_hidden = false;
          };
          plugin.prepend_fetchers = [
            {
              url = "*";
              run = "git";
              group = "git";
            }
            {
              url = "*/";
              run = "git";
              group = "git";
            }
          ];
          opener."extract-ouch" = [
            {
              run = ''ouch decompress -y "$@"'';
              desc = "Extract with ouch";
              for = "unix";
            }
          ];
          # Форматы, которые встроенный extract (7zz) не тянет
          open.prepend_rules = [
            {
              url = "*.{rar,cbr,lz4,tlz4,br,sz,bz3,lz,tlz}";
              use = [
                "extract-ouch"
                "reveal"
              ];
            }
          ];
        };
        plugins = {
          compress = pkgs.yaziPlugins.compress;
          git = {
            package = pkgs.yaziPlugins.git;
            setup = true;
            settings.order = 1500;
          };
          piper = pkgs.yaziPlugins.piper;
          smart-paste = pkgs.yaziPlugins.smart-paste;
          starship = {
            package = pkgs.yaziPlugins.starship;
            setup = true;
          };

          confirm-quit =
            mkYaziPlugin "confirm-quit" # lua
              ''
                local count = ya.sync(function() return #cx.tabs end)

                local function entry()
                	if count() < 2 then
                		return ya.emit("quit", {})
                	end

                	local yes = ya.confirm {
                		pos = { "center", w = 62, h = 10 },
                		title = "Quit?",
                		body = ui.Text("There are multiple tabs open. Are you sure you want to quit?"):wrap(ui.Wrap.YES),
                	}
                	if yes then
                		ya.emit("quit", {})
                	end
                end

                return { entry = entry }
              '';

          parent-arrow =
            mkYaziPlugin "parent-arrow" # lua
              ''
                --- @sync entry
                local function entry(_, job)
                	local parent = cx.active.parent
                	if not parent then return end

                	local target = parent.files[parent.cursor + 1 + job.args[1]]
                	if target and target.cha.is_dir then
                		ya.emit("cd", { target.url })
                	end
                end

                return { entry = entry }
              '';

          smart-switch =
            mkYaziPlugin "smart-switch" # lua
              ''
                --- @sync entry
                local function entry(_, job)
                	local cur = cx.active.current
                	for _ = #cx.tabs, job.args[1] do
                		ya.emit("tab_create", { cur.cwd })
                		if cur.hovered then
                			ya.emit("reveal", { cur.hovered.url })
                		end
                	end
                	ya.emit("tab_switch", { job.args[1] })
                end

                return { entry = entry }
              '';

          smart-tab =
            mkYaziPlugin "smart-tab" # lua
              ''
                --- @sync entry
                return {
                	entry = function()
                		local h = cx.active.current.hovered
                		ya.emit("tab_create", h and h.cha.is_dir and { h.url } or { current = true })
                	end,
                }
              '';
        };
        keymap = {
          mgr.prepend_keymap = [
            {
              on = "!";
              for = "unix";
              run = ''shell "env YAZI_SHELL=1 $SHELL" --block'';
              desc = "Open $SHELL here";
            }
            {
              on = [
                "c"
                "y"
              ];
              run = "shell -- ${lib.getExe pkgs.dragon-drop} -x -i -T %h";
              desc = "Drag and drop";
            }
            {
              on = [
                "c"
                "a"
              ];
              run = "shell -- herdr-send-paths \"$@\"";
              desc = "Send paths to the herdr agent";
            }
            {
              on = "p";
              run = "plugin smart-paste";
              desc = "Paste into the hovered directory or CWD";
            }
            {
              on = [
                "t"
                "t"
              ];
              run = "plugin smart-tab";
              desc = "Create a tab and enter the hovered directory";
            }
            {
              on = "{";
              run = "plugin parent-arrow -1";
              desc = "Go to the previous sibling of the parent directory";
            }
            {
              on = "}";
              run = "plugin parent-arrow 1";
              desc = "Go to the next sibling of the parent directory";
            }
            {
              on = "<Tab>";
              run = "tab_switch 1 --relative";
              desc = "Next tab";
            }
            {
              on = "<S-Tab>";
              run = "tab_switch -1 --relative";
              desc = "Previous tab";
            }
            {
              on = "i";
              run = "spot";
              desc = "Show file info";
            }
            {
              on = "q";
              run = "plugin confirm-quit";
              desc = "Quit (confirm when multiple tabs are open)";
            }
            {
              on = "<C-g>";
              run = ''shell -- rofi -show filebrowser -filebrowser-command "ya emit reveal" -filebrowser-directory "$(pwd)"'';
              desc = "Grid view";
            }
            {
              on = [
                "g"
                "r"
              ];
              run = ''shell -- ya emit cd "$(git rev-parse --show-toplevel)"'';
              desc = "Go to the root of the current Git repository";
            }
            {
              on = [
                "C"
                "z"
              ];
              run = "plugin compress zip";
              desc = "Archive: zip";
            }
            {
              on = [
                "C"
                "7"
              ];
              run = "plugin compress 7z";
              desc = "Archive: 7z";
            }
            {
              on = [
                "C"
                "g"
              ];
              run = "plugin compress tar.gz";
              desc = "Archive: tar.gz";
            }
            {
              on = [
                "C"
                "x"
              ];
              run = "plugin compress tar.xz";
              desc = "Archive: tar.xz";
            }
            {
              on = [
                "C"
                "s"
              ];
              run = "plugin compress tar.zst";
              desc = "Archive: tar.zst";
            }
            {
              on = [
                "C"
                "b"
              ];
              run = "plugin compress tar.bz2";
              desc = "Archive: tar.bz2";
            }
            {
              on = [
                "C"
                "t"
              ];
              run = "plugin compress tar";
              desc = "Archive: tar (no compression)";
            }
            {
              on = [
                "C"
                "p"
              ];
              run = "plugin compress '-p zip'";
              desc = "Archive: zip with password";
            }
            {
              on = [
                "C"
                "P"
              ];
              run = "plugin compress '-ph 7z'";
              desc = "Archive: 7z with password + encrypted header";
            }
            {
              on = [
                "C"
                "l"
              ];
              run = "plugin compress '-l zip'";
              desc = "Archive: zip with compression level";
            }
            {
              on = [
                "g"
                "w"
              ];
              run = "cd ~/Work";
              desc = "Go to ~/Work";
            }
            {
              on = [
                "g"
                "."
              ];
              run = "cd ~/dotfiles";
              desc = "Go to ~/dotfiles";
            }
            {
              on = [
                "g"
                "s"
              ];
              run = "cd ~/Work/core/services";
              desc = "Go to local Protei services";
            }
            {
              on = [
                "g"
                "S"
              ];
              run = "cd /var/lib/docker/volumes";
              desc = "Go to docker Protei services";
            }
          ]
          ++ map (i: {
            on = toString (i + 1);
            run = "plugin smart-switch ${toString i}";
            desc = "Switch to tab ${toString (i + 1)}, creating it if needed";
          }) (lib.range 0 8);
        };
      };

      # yazi как системный файловый диалог через
      # xdg-desktop-portal-termfilechooser
      xdg.configFile."xdg-desktop-portal-termfilechooser/config".text =
        let
          yaziWrapper = pkgs.writeShellApplication {
            name = "termfilechooser-yazi-wrapper";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.kitty
              pkgs.yazi
            ];
            # Порядок аргументов задаёт портал:
            # multiple directory save path out loglevel.
            # См. xdg-desktop-portal-termfilechooser(5).
            text = # bash
              ''
                directory="$2"
                out="$5"

                if [ "''${6:-0}" -ge 4 ]; then
                  set -x
                fi

                if [ "$directory" = 1 ]; then
                  set -- --chooser-file="$out" --cwd-file="$out.1" "$4"
                else
                  set -- --chooser-file="$out" "$4"
                fi

                # Отмена выбора (`Q` в yazi) — не ошибка: портал трактует
                # пустой out как cancel, поэтому код возврата игнорируем.
                kitty --class=termfilechooser --title=termfilechooser yazi "$@" || true

                if [ "$directory" = 1 ]; then
                  if [ ! -s "$out" ] && [ -s "$out.1" ]; then
                    cat "$out.1" > "$out"
                  fi
                  rm -f "$out.1"
                fi
              '';
          };
        in
        ''
          [filechooser]
          cmd=${lib.getExe yaziWrapper}
          default_dir=$HOME
          open_mode=suggested
          save_mode=suggested
        '';

      programs.mc = {
        enable = true;
        settings.Midnight-Commander = {
          skin = "yadt256";
          use_internal_view = false;
          use_internal_edit = false;
        };
      };

      programs.eza = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        colors = "auto";
        icons = "auto";
      };

      programs.starship = {
        enable = true;
        enableInteractive = true;
        enableTransience = true;
        enableZshIntegration = true;
        settings = {
          custom.yazi_shell = {
            when = ''test "$YAZI_SHELL" = "1"'';
            format = "[║══ yazi ══║](bold yellow) ";
          };
          custom.herdr = {
            when = ''test "$HERDR_ENV" = "1"'';
            format = "[󰆍 herdr](bold cyan) ";
          };
        };
      };

      programs.bat = {
        enable = true;
        extraPackages = with pkgs.bat-extras; [
          batgrep
          batman
          batpipe
          batwatch
        ];
      };

      programs.fd.enable = true;
      programs.fzf.enable = true;
      programs.ripgrep.enable = true;
      programs.lazygit.enable = true;

      programs.pgcli = {
        enable = true;
        settings = {
          main = {
            smart_completion = true;
            vi = true;
          };
          "named queries" = {
            company0 = "SET search_path TO 'company_0'"; # \n company0
            public = "SET search_path TO 'public'"; # \n public
          };
        };
      };
    };
}
