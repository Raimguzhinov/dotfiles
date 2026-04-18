{ inputs, ... }:
let
  # Shared vim settings — used both in perSystem (nvf standalone) and homeModules (nvf HM)
  makeNvimSettings = pkgs: {
    extraPackages = with pkgs; [
      git
      lazygit
    ];
    viAlias = true;
    vimAlias = true;
    withNodeJs = false;
    withRuby = false;
    enableLuaLoader = true;
    hideSearchHighlight = true;
    searchCase = "smart";
    undoFile.enable = true;
    options = {
      mouse = "a";
      cursorlineopt = "both";
      signcolumn = "auto";
      colorcolumn = "140";
      encoding = "utf-8";
      number = true;
      relativenumber = true;
      tabstop = 4;
      autoindent = true;
      shiftwidth = 0;
      softtabstop = 2;
      wrap = true;
      termguicolors = true;
    };
    lsp = {
      enable = true;
      formatOnSave = true;
      inlayHints.enable = true;
      lightbulb.enable = true;
    };
    languages = {
      enableDAP = true;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;
      go.enable = true;
      go.dap.enable = true;
      nix.enable = true;
      nix.format.enable = true;
      nix.format.type = [ "nixfmt" ];
      bash.enable = true;
      python.enable = true;
      yaml.enable = true;
      markdown.enable = true;
      typst.enable = true;
      sql.enable = true;
    };
    theme = {
      enable = true;
      name = "tokyonight";
      style = "night";
      transparent = true;
    };
    terminal.toggleterm = {
      enable = true;
      mappings.open = ''<leader>"'';
      setupOpts = {
        direction = "horizontal";
      };
    };
    utility = {
      preview.markdownPreview = {
        enable = true;
      };
    };
    ui = {
      noice.enable = true;
      borders = {
        enable = true;
        globalStyle = "rounded";

        plugins.nvim-cmp.enable = false;
      };
      smartcolumn = {
        enable = true;
        setupOpts.custom_colorcolumn = {
          nix = "90";
          python = "120";
        };
      };
    };
    statusline.lualine.enable = true;
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;
    autopairs.nvim-autopairs.enable = true;
    comments.comment-nvim = {
      enable = true;
      mappings.toggleCurrentLine = "<leader>/";
      mappings.toggleSelectedLine = "<leader>/";
    };
    git.gitsigns.enable = true;
    filetree.nvimTree = {
      enable = true;
      mappings.findFile = "<leader>eg";
      mappings.refresh = "<leader>er";
      mappings.toggle = "<leader>eq";
      mappings.focus = "<leader>e";
      openOnSetup = false;
      setupOpts = {
        sync_root_with_cwd = false;
        respect_buf_cwd = true;
        sort_by = "case_sensitive";
        git.enable = true;
        update_focused_file = {
          enable = true;
          update_root = true;
        };
        hijack_cursor = true;
        disable_netrw = true;
        renderer = {
          group_empty = true;
          full_name = true;
          indent_markers.enable = true;
          icons = {
            show = {
              file = true;
              folder = true;
              folder_arrow = true;
            };
            glyphs = {
              default = "󰈚";
              symlink = "";
              folder = {
                default = "";
                empty = "";
                empty_open = "";
                open = "";
                symlink = "";
                symlink_open = "";
                arrow_open = "";
                arrow_closed = "";
              };
              git = {
                untracked = "";
                staged = "";
                deleted = "";
                unstaged = "󰜀";
                renamed = "";
                ignored = "◌";
                unmerged = "";
              };
            };
          };
        };
        filters = {
          dotfiles = true;
        };
        diagnostics = {
          enable = true;
          show_on_dirs = true;
        };
      };
    };
    binds.whichKey.enable = true;
    utility.nix-develop.enable = true;
    debugger.nvim-dap.ui.enable = true;
    clipboard = {
      enable = true;
      providers.wl-copy.enable = true;
      registers = "unnamedplus";
    };
    keymaps = [
      {
        key = "<leader>w";
        mode = "n";
        action = "<cmd>write<CR>";
      }
      {
        key = "<leader>q";
        mode = "n";
        action = "<cmd>quitall<CR>";
      }
      {
        key = "<leader>wq";
        mode = "n";
        action = ":wqa<CR>";
      }
      {
        key = "jk";
        mode = "i";
        silent = true;
        action = "<Esc>";
      }
      {
        key = "vv";
        mode = "n";
        silent = true;
        action = "V";
      }
    ];
    lazy.plugins = {
      vim-dadbod-ui = {
        package = pkgs.vimPlugins.vim-dadbod-ui;
        lazy = true;
        cmd = [
          "DBUI"
          "DBUIToggle"
          "DBUIAddConnection"
          "DBUIFindBuffer"
        ];
        after = # lua
          ''
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_win_position = "right"
          '';
      };
      vim-dadbod-completion = {
        package = pkgs.vimPlugins.vim-dadbod-completion;
        lazy = true;
        ft = [
          "sql"
          "mysql"
          "plsql"
        ];
      };
      nvim-web-devicons = {
        package = pkgs.vimPlugins.nvim-web-devicons;
        lazy = false;
      };
      "lazygit.nvim" = {
        package = pkgs.vimPlugins.lazygit-nvim;
        lazy = true;
        cmd = [
          "LazyGit"
          "LazyGitConfig"
          "LazyGitCurrentFile"
          "LazyGitFilter"
          "LazyGitFilterCurrentFile"
        ];
      };
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      # Standalone nvf package with all settings baked in — for nix run/build
      neovimPkg =
        (inputs.nvf.lib.neovimConfiguration {
          inherit pkgs;
          modules = [ { config.vim = makeNvimSettings pkgs; } ];
        }).neovim;
    in
    {
      packages.neovim = neovimPkg;
    };

  flake.homeModules.neovim =
    { pkgs, ... }:
    {
      programs.nvf = {
        enable = true;
        defaultEditor = true;
        settings.vim = makeNvimSettings pkgs;
      };
    };
}
