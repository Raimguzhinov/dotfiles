{ inputs, ... }:
let
  # Shared vim settings — used both in perSystem (nvf standalone) and homeModules (nvf HM)
  makeNvimSettings = pkgs: lib: {
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
      shiftwidth = 4;
      softtabstop = 4;
      autoindent = true;
      breakindent = true;
      indentkeys = "0";

      wrap = true;
      termguicolors = true;
    };
    lsp = {
      enable = true;
      formatOnSave = true;
      inlayHints.enable = true;
      lightbulb.enable = true;
    };
    autocmds = [
      {
        event = ["LspAttach"];
        callback = lib.generators.mkLuaInline ''
          function(event)
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            vim.bo.indentkeys = "0"
          end
        '';
      }
      {
        event = ["FileType"];
        callback = lib.generators.mkLuaInline ''
          function()
            vim.bo.indentkeys = "0"
          end
        '';
      }
      {
        # nixfmt (RFC style) uses 2-space indentation; conform passes the
        # buffer shiftwidth to `nixfmt --indent`, so keep nix at 2 spaces
        # instead of the global 4 to match the repo formatting.
        event = ["FileType"];
        pattern = ["nix"];
        callback = lib.generators.mkLuaInline ''
          function()
            vim.bo.tabstop = 2
            vim.bo.shiftwidth = 2
            vim.bo.softtabstop = 2
            vim.bo.expandtab = true
          end
        '';
      }
    ];

    treesitter = {
      enable = true;
      highlight.enable = true;
      indent.enable = true;
    };
    languages = {
      enableDAP = true;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;
      go = {
        enable = true;
        dap.enable = true;
        extensions.gopher-nvim.enable = true;
        treesitter = {
          goPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.go;
          gomodPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.gomod;
          gosumPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.gosum;
          goworkPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.gowork;
          gotmpl.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.gotmpl;
        };
      };
      nix = {
        enable = true;
        format.enable = true;
        format.type = [ "nixfmt" ];
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.nix;
      };
      bash = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.bash;
      };
      python = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.python;
      };
      yaml = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.yaml;
      };
      markdown = {
        enable = true;
        treesitter = {
          mdPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.markdown;
          mdInlinePackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.markdown_inline;
        };
      };
      typst = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.typst;
      };
      sql = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.sql;
      };
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
    lazy.plugins.nvim-cmp = {
      after = # lua
        ''
          vim.schedule(function()
            local cmp = require("cmp")
            local config = cmp.get_config()
            if config and config.mapping then
              config.mapping["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.confirm({ select = false })
                else
                  fallback()
                end
              end)
            end
          end)
        '';
    };
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
      {
        key = "<Up>";
        mode = "i";
        lua = true;
        action = # lua
          ''
            function()
              local cmp = require("cmp")
              if cmp.visible() then
                cmp.select_prev_item()
              else
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Up>", true, true, true), "n", true)
              end
            end
          '';
      }
      {
        key = "<Down>";
        mode = "i";
        lua = true;
        action = # lua
          ''
            function()
              local cmp = require("cmp")
              if cmp.visible() then
                cmp.select_next_item()
              else
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Down>", true, true, true), "n", true)
              end
            end
          '';
      }
      {
        key = "gd";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.definition()
            end
          '';
      }
      {
        key = "gi";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.implementation()
            end
          '';
      }
      {
        key = "gI";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.declaration()
            end
          '';
      }
      {
        key = "gD";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.type_definition()
            end
          '';
      }
      {
        key = "<C-s>";
        mode = ["n" "i"];
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.signature_help()
            end
          '';
      }
      {
        key = "<leader>K";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.hover()
            end
          '';
      }
      {
        key = "<leader>la";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.code_action()
            end
          '';
      }
      {
        key = "<leader>ra";
        mode = "n";
        lua = true;
        action = # lua
          ''
            function()
              vim.lsp.buf.rename()
            end
          '';
      }
      {
        key = "<C-o>";
        mode = "n";
        action = "<cmd>bprevious<CR>";
      }
      {
        key = "<C-i>";
        mode = "n";
        action = "<cmd>bnext<CR>";
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
          modules = [ { config.vim = makeNvimSettings pkgs pkgs.lib; } ];
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
        settings.vim = makeNvimSettings pkgs pkgs.lib;
      };
    };
}
