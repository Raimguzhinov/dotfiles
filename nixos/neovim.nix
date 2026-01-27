{ config, pkgs, ... }:
{
  programs.nvf = {
    enable = true;
    defaultEditor = true;
    settings = {
      vim.viAlias = true;
      vim.vimAlias = true;
      vim.withNodeJs = false;
      vim.withRuby = false;
      vim.enableLuaLoader = true;
      vim.hideSearchHighlight = true;
      vim.searchCase = "smart";
      vim.undoFile.enable = true;
      vim.options = {
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
      vim.lsp = {
        enable = true;
        formatOnSave = true;
        inlayHints.enable = true;
        lightbulb.enable = true;
      };
      vim.languages = {
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
      vim.theme = {
        enable = true;
        name = "tokyonight";
        style = "night";
        transparent = true;
      };
      vim.terminal.toggleterm = {
        enable = true;
        mappings.open = ''<leader>"'';
        setupOpts = {
          direction = "horizontal";
        };
      };
      vim.utility = {
        preview.markdownPreview = {
          enable = true;
        };
      };
      vim.ui = {
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
      vim.statusline.lualine.enable = true;
      vim.telescope.enable = true;
      vim.autocomplete.nvim-cmp.enable = true;
      vim.autopairs.nvim-autopairs.enable = true;
      vim.comments.comment-nvim = {
        enable = true;
        mappings.toggleCurrentLine = "<leader>/";
        mappings.toggleSelectedLine = "<leader>/";
      };
      vim.git.gitsigns.enable = true;
      vim.filetree.nvimTree = {
        enable = true;
        mappings.findFile = "<leader>eg";
        mappings.refresh = "<leader>er";
        mappings.toggle = "<leader>eq";
        mappings.focus = "<leader>e";
        openOnSetup = true;
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
                symlink = "";
                folder = {
                  default = "";
                  empty = "";
                  empty_open = "";
                  open = "";
                  symlink = "";
                  symlink_open = "";
                  arrow_open = "";
                  arrow_closed = "";
                };
                git = {
                  untracked = "";
                  staged = "";
                  deleted = "";
                  unstaged = "󰜀";
                  renamed = "";
                  ignored = "◌";
                  unmerged = "";
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
      vim.binds.whichKey.enable = true;
      vim.utility.nix-develop.enable = true;
      vim.debugger.nvim-dap.ui.enable = true;
      vim.clipboard = {
        enable = true;
        providers.wl-copy.enable = true;
        registers = "unnamedplus";
      };
      vim.keymaps = [
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
      vim.lazy.plugins = {
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
  };
}
