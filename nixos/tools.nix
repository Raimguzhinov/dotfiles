{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "Dias B. Raimguzhinov";
      user.email = "raimguzhinov@protei-lab.ru";
      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        hist = "log --oneline --decorate --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an> %G?'%Creset --abbrev-commit --date=relative";
        hist-full = "log --oneline --decorate --graph --all";
        bcommit = "!f() { git commit -m '$(git symbolic-ref --short HEAD) $@'; }; f";
      };
      init.defaultBranch = "main";
      core.editor = "nvim";
      pull.rebase = true;
      color.ui = true;
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      url."ssh://git@git.protei.ru/" = {
        insteadOf = [ "https://git.protei.ru/" ];
      };
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      line-numbers = true;
      side-by-side = true;
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
      ];
      # theme = "robbyrussell";
    };
    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      e = "exit";
      clr = "clear";
      cat = "bat";
      tree = "eza --tree";
      pass = "gopass";
      open = "xdg-open";
      dbui = "nvim +DBUI";
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

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    package = pkgs.yazi;
    shellWrapperName = "rr";
    settings = {
      mgr = {
        show_hidden = true;
      };
      # [[plugin.prepend_previewers]]
      # url = "*.md"
      # run = 'piper -- CLICOLOR_FORCE=1 glow -w=$w -s=dark "$1"'
    };
    plugins = {
      piper = pkgs.yaziPlugins.piper;
    };
    keymap = {
      mgr.prepend_keymap = [
        {
          on = [
            "g"
            "s"
          ];
          run = "cd /home/dias/Work/core/services";
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
      ];
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

}
