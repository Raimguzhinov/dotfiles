{ inputs, ... }:
let
  # Shared vim settings — used both in perSystem (nvf standalone) and homeModules (nvf HM)
  makeNvimSettings = pkgs: lib: {
    extraPackages = with pkgs; [
      git
      lazygit
      lazydocker
      yazi
      fd
      ripgrep
      golangci-lint-langserver
      # clang-tools # форматер для protobuf; включить при необходимости
    ];
    globals.loaded_netrwPlugin = 1;
    filetype.extension.log = "log";
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
      # Neovim's factory default; "o"/"O" specifically govern reindenting when
      # <CR> opens a new line in insert mode (see :help indentkeys-format) —
      # without them, indentexpr is never invoked on Enter, for any language.
      indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e";

      wrap = true;
      termguicolors = true;
    };
    lsp = {
      enable = true;
      formatOnSave = true;
      inlayHints.enable = true;
      lightbulb.enable = true;
      trouble = {
        enable = true;
        mappings = {
          quickfix = "<leader>lq";
          locList = "<leader>ll";
          symbols = "<leader>lx";
        };
      };
      mappings = {
        goToDefinition = null;
        goToType = null;
        listImplementations = null;
        goToDeclaration = "gI";
        hover = "<leader>K";
        renameSymbol = "<leader>ra";
      };
      servers = {
        gopls.settings.gopls = {
          staticcheck = false; # golangci_lint_ls already runs this
          completeUnimported = true;
          usePlaceholders = true;
          symbolScope = "workspace";
          directoryFilters = [
            "-**/node_modules"
            "-**/.git"
            "-**/.direnv"
          ];
          analyses = {
            unusedparams = true;
            unusedwrite = true;
            nilness = true;
          };
          hints = {
            assignVariableTypes = false;
            compositeLiteralFields = true;
            constantValues = true;
            functionTypeParameters = false;
            ignoredError = true;
            parameterNames = false;
            rangeVariableTypes = true;
          };
        };

        golangci_lint_ls.enable = true;

        protobuf_language_server = {
          cmd = [ (lib.getExe pkgs.protobuf-language-server) ];
          filetypes = [ "proto" ];
          root_markers = [ ".git" ];
          # Formatter shells out to missing clang-format and crashes; strip the capability.
          on_init =
            lib.generators.mkLuaInline # lua
              ''
                function(client)
                  client.server_capabilities.documentFormattingProvider = false
                  client.server_capabilities.documentRangeFormattingProvider = false
                end
              '';
        };
      };
    };
    autocmds = [
      {
        # ftplugins can set their own indentexpr/indentkeys on FileType, after
        # treesitter's own FileType autocmd runs; reassert on LspAttach (fires
        # later) so per-language treesitter indent always wins.
        event = [ "LspAttach" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function(event)
                vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                vim.bo.indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
              end
            '';
      }
      {
        event = [ "FileType" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                vim.bo.indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
              end
            '';
      }
      {
        # nixfmt indents 2 spaces
        event = [ "FileType" ];
        pattern = [ "nix" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                vim.bo.tabstop = 2
                vim.bo.shiftwidth = 2
                vim.bo.softtabstop = 2
                vim.bo.expandtab = true
              end
            '';
      }
      {
        event = [ "StdinReadPre" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                vim.g.nvf_started_with_stdin = true
              end
            '';
      }
      {
        event = [ "User" ];
        pattern = [ "FugitiveChanged" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                local unmerged = vim.fn.systemlist({ "git", "diff", "--name-only", "--diff-filter=U" })
                if vim.v.shell_error ~= 0 or #unmerged == 0 then
                  return
                end
                local ok, lib = pcall(require, "diffview.lib")
                if ok and lib.get_current_view() then
                  return
                end
                vim.schedule(function()
                  vim.cmd("DiffviewOpen")
                end)
              end
            '';
      }
      {
        event = [ "VimEnter" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                if vim.fn.argc() ~= 0 or vim.g.nvf_started_with_stdin then
                  return
                end
                local unmerged = vim.fn.systemlist({ "git", "diff", "--name-only", "--diff-filter=U" })
                if vim.v.shell_error == 0 and #unmerged > 0 then
                  vim.schedule(function()
                    vim.cmd("DiffviewOpen")
                  end)
                else
                  vim.schedule(function()
                    require("yazi").yazi(nil, vim.fn.getcwd())
                  end)
                end
              end
            '';
      }
      {
        event = [ "VimEnter" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                local ok_lzn, lzn = pcall(require, "lz.n")
                if ok_lzn then
                  lzn.trigger_load("telescope")
                end

                local dap = require("dap")
                local delve_adapter = dap.adapters.go
                dap.adapters.go = function(callback, client_config)
                  if client_config.request == "attach" and client_config.mode == "remote" then
                    -- Remote attach: connect directly instead of spawning a local dlv.
                    callback({
                      type = "server",
                      host = client_config.host or "127.0.0.1",
                      port = client_config.port,
                      enrich_config = function(config, on_config)
                        if not config.substitutePath then
                          local root = vim.fs.root(0, ".vscode")
                          if root then
                            -- from/to reversed on purpose, see delve's substitutePath docs.
                            config = vim.tbl_extend("force", config, {
                              substitutePath = { { from = root, to = "/build" } },
                            })
                          end
                        end
                        on_config(config)
                      end,
                    })
                    return
                  end
                  delve_adapter(function(adapter_config)
                    if adapter_config.executable then
                      adapter_config.executable.command = "dlv"
                    end
                    callback(adapter_config)
                  end, client_config)
                end

                dap.providers.configs["dap.launch.json"] = function(bufnr)
                  local root = vim.fs.root(bufnr, ".vscode")
                  if not root then
                    return {}
                  end
                  local ok, configs = pcall(require("dap.ext.vscode").getconfigs, root .. "/.vscode/launch.json")
                  if not ok then
                    return {}
                  end
                  return configs
                end

                dap.listeners.after.event_initialized["lualine_winbar"] = function()
                  require("lualine").hide({ place = { "winbar" }, unhide = false })
                end
                dap.listeners.before.event_terminated["lualine_winbar"] = function()
                  require("lualine").hide({ place = { "winbar" }, unhide = true })
                end
                dap.listeners.before.event_exited["lualine_winbar"] = function()
                  require("lualine").hide({ place = { "winbar" }, unhide = true })
                end
              end
            '';
      }
      {
        event = [ "BufEnter" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function(args)
                if vim.bo[args.buf].buftype ~= "" then
                  return
                end
                local name = vim.api.nvim_buf_get_name(args.buf)
                if name == "" or name:match("^%w+://") then
                  return
                end
                local root = vim.fs.root(args.buf, ".git")
                if root then
                  vim.g.want_tree_root = root
                end
              end
            '';
      }
      {
        event = [ "VimEnter" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                local ok, api = pcall(require, "nvim-tree.api")
                if not ok then
                  return
                end
                api.events.subscribe(api.events.Event.TreeOpen, function()
                  local root = vim.g.want_tree_root
                  if not root then
                    return
                  end
                  local ok_core, core = pcall(require, "nvim-tree.core")
                  if ok_core then
                    local expl = core.get_explorer()
                    if expl and expl.absolute_path == root then
                      return
                    end
                  end
                  pcall(api.tree.change_root, root)
                end)
              end
            '';
      }
      {
        event = [ "FileType" ];
        pattern = [ "proto" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function()
                vim.b.disableFormatSave = true
              end
            '';
      }
    ];

    treesitter = {
      enable = true;
      highlight.enable = true;
      indent.enable = true;
      grammars = [ pkgs.vimPlugins.nvim-treesitter.builtGrammars.proto ];
    };
    languages = {
      enableDAP = true;
      enableExtraDiagnostics = true;
      enableFormat = true;
      enableTreesitter = true;
      go = {
        enable = true;
        dap.enable = true;
        format.enable = true;
        format.type = [ "goimports" ];
        extraDiagnostics.enable = false; # golangci_lint_ls (LSP, above) replaces this
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
      json = {
        enable = true;
        treesitter.jsonPackage = pkgs.vimPlugins.nvim-treesitter.builtGrammars.json;
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
        format.enable = false;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.yaml;
      };
      markdown = {
        enable = true;
        format.enable = false;
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
    formatter.conform-nvim.setupOpts.formatters.goimports.args =
      lib.generators.mkLuaInline # lua
        ''
          function(self, ctx)
            local gomod = vim.fs.find("go.mod", { upward = true, path = ctx.dirname })[1]
            if gomod then
              for line in io.lines(gomod) do
                local mod = line:match("^module%s+(%S+)")
                if mod then
                  return { "-local", mod }
                end
              end
            end
            return {}
          end
        '';
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
      lazygit = {
        enable = true;
        direction = "float";
        mappings.open = "<leader>gg";
      };
    };
    utility = {
      preview.markdownPreview = {
        enable = true;
      };
      yazi-nvim = {
        enable = true;
        mappings = {
          openYazi = "<leader>o";
          openYaziDir = "<leader>O";
          yaziToggle = null;
        };
        setupOpts.open_for_directories = true;
      };
      snacks-nvim = {
        enable = true;
        setupOpts.bigfile = {
          enabled = true;
          size = 2097152;
        };
      };
      outline.aerial-nvim.enable = true;
      diffview-nvim = {
        enable = true;
        setupOpts = {
          view.merge_tool = {
            layout = "diff3_horizontal";
            disable_diagnostics = true;
            winbar_info = true;
          };
          view.default.winbar_info = true;
          view.file_history.winbar_info = true;
          hooks =
            lib.generators.mkLuaInline # lua
              ''
                {
                  view_opened = function()
                    require("lualine").hide({ place = { "winbar" }, unhide = false })
                    vim.schedule(function()
                      pcall(vim.cmd, "DiffviewRefresh")
                    end)
                  end,
                  view_enter = function()
                    require("lualine").hide({ place = { "winbar" }, unhide = false })
                  end,
                  view_leave = function()
                    require("lualine").hide({ place = { "winbar" }, unhide = true })
                  end,
                  view_closed = function()
                    require("lualine").hide({ place = { "winbar" }, unhide = true })
                  end,
                }
              '';
        };
      };
    };
    ui = {
      noice = {
        enable = true;
        # Suppresses a harmless but recurring protobuf_language_server error popup.
        setupOpts.routes = [
          {
            filter = {
              event = "msg_show";
              find = "protobuf_language_server.*INVALID_SERVER_MESSAGE";
            };
            opts.skip = true;
          }
        ];
      };
      breadcrumbs = {
        enable = true;
        lualine.winbar.enable = true;
      };
      borders = {
        enable = true;
        globalStyle = "rounded";

        plugins.nvim-cmp.enable = false;
      };
      smartcolumn = {
        enable = true;
        setupOpts.custom_colorcolumn = {
          nix = "90";
          go = "140";
          python = "140";
        };
      };
    };
    visuals.nvim-web-devicons.enable = true;
    statusline.lualine.enable = true;
    telescope = {
      enable = true;
      mappings = {
        lspDefinitions = "gd";
        lspReferences = "gu";
        lspImplementations = "gi";
        lspTypeDefinitions = "gD";
      };
      extensions = [
        {
          name = "fzf";
          packages = [ pkgs.vimPlugins.telescope-fzf-native-nvim ];
          setup.fzf.fuzzy = true;
        }
        {
          name = "ui-select";
          packages = [ pkgs.vimPlugins.telescope-ui-select-nvim ];
          setup."ui-select" = [
            (lib.generators.mkLuaInline # lua
              ''require("telescope.themes").get_dropdown({})''
            )
          ];
        }
      ];
    };
    tabline.nvimBufferline = {
      enable = true;
      mappings = {
        cycleNext = "<Tab>";
        cyclePrevious = "<S-Tab>";
        closeCurrent = "<leader>x";
      };
      setupOpts.options.numbers = "ordinal";
    };
    notes.todo-comments.enable = true;
    binds = {
      cheatsheet.enable = true;
      whichKey = {
        enable = true;
        register = {
          "<leader>b" = "Buffers";
          "<leader>c" = "Conflict (ours/theirs/base)";
          "<leader>d" = "Debug";
          "<leader>e" = "Explorer";
          "<leader>f" = "Find";
          "<leader>fv" = "Find/Git";
          "<leader>g" = "Git";
          "<leader>l" = "LSP";
          "<leader>r" = "Run/Refactor";
          "<leader>t" = "Todo"; # overrides nvimtree's stale default for this key
          "<leader>td" = "Todo";
        };
      };
    };
    autocomplete.nvim-cmp.enable = true;
    autopairs.nvim-autopairs.enable = true;
    comments.comment-nvim = {
      enable = true;
      mappings.toggleCurrentLine = "<leader>/";
      mappings.toggleSelectedLine = "<leader>/";
    };
    git.gitsigns = {
      enable = true;
      mappings = {
        # Defaults collide with the Todo group above (<leader>tb/<leader>td)
        toggleBlame = "<leader>htb";
        toggleDeleted = "<leader>htd";
      };
    };
    git.vim-fugitive.enable = true;
    git.git-conflict.enable = true;
    filetree.nvimTree = {
      enable = true;
      mappings.findFile = "<leader>eg";
      mappings.refresh = "<leader>er";
      mappings.toggle = "<leader>eq";
      mappings.focus = "<leader>e";
      openOnSetup = false;
      setupOpts = {
        sync_root_with_cwd = false;
        respect_buf_cwd = false;
        prefer_startup_root = true;
        sort_by = "case_sensitive";
        git.enable = true;
        update_focused_file = {
          enable = true;
          update_root = false;
        };
        hijack_cursor = true;
        disable_netrw = false;
        hijack_netrw = false;
        hijack_directories.enable = false;
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
        desc = "Write file";
      }
      {
        key = "<leader>q";
        mode = "n";
        action = "<cmd>quit<CR>";
        desc = "Quit";
      }
      {
        key = "<leader>Q";
        mode = "n";
        action = "<cmd>quitall<CR>";
        desc = "Quit all";
      }
      {
        key = "<leader>wq";
        mode = "n";
        action = ":wqa<CR>";
        desc = "Write file and quit all";
      }
      {
        key = "jk";
        mode = "i";
        silent = true;
        action = "<Esc>";
        desc = "Exit insert mode";
      }
      {
        key = "vv";
        mode = "n";
        silent = true;
        action = "V";
        desc = "Select line";
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
        key = "<C-s>";
        mode = [
          "n"
          "i"
        ];
        lua = true;
        desc = "Signature help";
        action = # lua
          ''
            function()
              vim.lsp.buf.signature_help()
            end
          '';
      }
      {
        key = "<leader>gd";
        mode = "n";
        action = "<cmd>DiffviewOpen<CR>";
        desc = "Diff/merge view [diffview]";
      }
      {
        key = "<leader>gx";
        mode = "n";
        action = "<cmd>DiffviewClose<CR>";
        desc = "Close diffview";
      }
      {
        key = "<leader>gh";
        mode = "n";
        action = "<cmd>DiffviewFileHistory %<CR>";
        desc = "File history (current)";
      }
      {
        key = "<leader>gH";
        mode = "n";
        action = "<cmd>DiffviewFileHistory<CR>";
        desc = "File history (repo)";
      }
      {
        key = "<leader>gs";
        mode = "n";
        action = "<cmd>Git<CR>";
        desc = "Git status [fugitive]";
      }
    ];
    lazy.plugins = {
      nvim-cmp = {
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
      "overseer.nvim" = {
        package = pkgs.vimPlugins.overseer-nvim;
        setupModule = "overseer";
        setupOpts.task_list.direction = "bottom";
        lazy = true;
        cmd = [
          "OverseerRun"
          "OverseerToggle"
          "OverseerInfo"
          "OverseerBuild"
          "OverseerQuickAction"
          "OverseerTaskAction"
        ];
        keys = [
          {
            key = "<leader>rr";
            mode = "n";
            action = "<cmd>OverseerRun<CR>";
            desc = "Run task [overseer]";
          }
          {
            key = "<leader>rt";
            mode = "n";
            action = "<cmd>OverseerToggle<CR>";
            desc = "Toggle task panel [overseer]";
          }
        ];
        after = # lua
          ''
            local overseer = require("overseer")
            local function go_template(name, args, use_file_dir)
              return {
                name = name,
                builder = function()
                  return {
                    cmd = { "go" },
                    args = args,
                    cwd = use_file_dir and vim.fn.expand("%:p:h") or nil,
                    components = { "default" },
                  }
                end,
                condition = { filetype = { "go" } },
              }
            end
            overseer.register_template(go_template("go: run (current package)", { "run", "." }, true))
            overseer.register_template(go_template("go: test (current package)", { "test", "-v", "." }, true))
            overseer.register_template(go_template("go: build ./...", { "build", "./..." }, false))
            overseer.register_template(go_template("go: test ./...", { "test", "./..." }, false))
            overseer.register_template(go_template("go: mod tidy", { "mod", "tidy" }, false))
          '';
      };
      "lazydocker.nvim" = {
        package = pkgs.vimPlugins.lazydocker-nvim;
        setupModule = "lazydocker";
        setupOpts = { };
        lazy = true;
        keys = [
          {
            key = "<leader>D";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("lazydocker").toggle({ engine = "docker" }) end'';
            desc = "Toggle lazydocker";
          }
        ];
      };
      "nvim-dap-virtual-text" = {
        package = pkgs.vimPlugins.nvim-dap-virtual-text;
        setupModule = "nvim-dap-virtual-text";
        setupOpts = { };
        lazy = true;
        ft = [ "go" ];
      };
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
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
