{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Dias B. Raimguzhinov";
    userEmail = "raimguzhinov@protei-lab.ru";
    aliases = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
      hist = "log --oneline --decorate --graph --all";
      bcommit = "!f() { git commit -m '$(git symbolic-ref --short HEAD) $@'; }; f";
    };
    lfs.enable = true;
    delta.enable = true;
    delta.options = {
      line-numbers = true;
      side-by-side = true;
    };
    signing = {
      key = "6E06AD1573F0D606704F4A32719B8382A9DBA991";
      signByDefault = true;
    };
    extraConfig = {
      core.editor = "nvim";
      init.defaultBranch = "main";
      pull.rebase = true;
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      url."ssh://git@git.protei.ru/" = {
        insteadOf = [ "https://git.protei.ru/" ];
      };
      color.ui = true;
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
    settings = {
      theme = "ao";
      # default_layout = "compact"; # Hide the bar
      default_shell = "zsh";
      simplified_ui = true;
      show_startup_tips = true;
      ui.pane_frames = {
        rounded_corners = false;
        hide_session_name = true;
      };
    };
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    shellWrapperName = "rr";
    settings = {
      mgr = {
        show_hidden = true;
      };
    };
    plugins = {
      sudo = pkgs.yaziPlugins.sudo;
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
