{ inputs, ... }:
let
  # Shared vim settings — used both in perSystem (nvf standalone) and homeModules (nvf HM)
  makeNvimSettings = pkgs: lib: {
    extraPackages = with pkgs; [
      git
      lazygit # also used by toggleterm.lazygit integration
      lazydocker # lazydocker.nvim shells out to the `lazydocker` binary
      yazi # yazi.nvim wraps the yazi binary
      fd # faster telescope find_files on huge repos
      ripgrep # telescope live_grep
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
      trouble.enable = true; # diagnostics/references list (<leader>x*, <leader>lw*)
      # gopls tuned for large monorepos. `settings` is freeform passthrough on
      # top of the nvf gopls preset (which sets cmd/root_dir).
      servers.gopls.settings.gopls = {
        staticcheck = true;
        completeUnimported = true;
        usePlaceholders = true;
        symbolScope = "workspace"; # don't index deps for workspace/symbol
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
          # feeds vim.lsp.inlayHints (already enabled above)
          assignVariableTypes = true;
          compositeLiteralFields = true;
          constantValues = true;
          functionTypeParameters = true;
          parameterNames = true;
          rangeVariableTypes = true;
        };
      };
    };
    autocmds = [
      {
        event = [ "LspAttach" ];
        callback = lib.generators.mkLuaInline ''
          function(event)
            vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            vim.bo.indentkeys = "0"
          end
        '';
      }
      {
        event = [ "FileType" ];
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
        event = [ "FileType" ];
        pattern = [ "nix" ];
        callback = lib.generators.mkLuaInline ''
          function()
            vim.bo.tabstop = 2
            vim.bo.shiftwidth = 2
            vim.bo.softtabstop = 2
            vim.bo.expandtab = true
          end
        '';
      }
      {
        # Guard so piping into nvim (`... | nvim -`) does not trigger the
        # no-args oil startup below.
        event = [ "StdinReadPre" ];
        callback = lib.generators.mkLuaInline ''
          function()
            vim.g.nvf_started_with_stdin = true
          end
        '';
      }
      {
        # After any fugitive git command (e.g. `:Git merge`), if it left the
        # repo with unresolved conflicts, open the three-way merge tab — unless
        # we are already viewing it.
        event = [ "User" ];
        pattern = [ "FugitiveChanged" ];
        callback = lib.generators.mkLuaInline ''
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
        # `nvim` with no args → three-way merge tab if the repo has unresolved
        # conflicts (mid merge/rebase), otherwise oil at cwd.
        event = [ "VimEnter" ];
        callback = lib.generators.mkLuaInline ''
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
                require("oil").open(vim.fn.getcwd())
              end)
            end
          end
        '';
      }
      {
        # Remember the git root of the file being edited (skip special/uri
        # buffers), so nvim-tree can root there instead of the shell cwd.
        event = [ "BufEnter" ];
        callback = lib.generators.mkLuaInline ''
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
        # Root nvim-tree at the git project of the focused file, not the shell
        # cwd: `nvim ~/other-project/sub/file` shows other-project's tree from
        # its .git root. Subscribe once; fires on every tree open.
        event = [ "VimEnter" ];
        callback = lib.generators.mkLuaInline ''
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
        # goimports (not gofmt) so imports are grouped GoLand-style; the
        # `-local` prefix is injected per-project below via conform args.
        # format.enable must be explicit: it defaults off when LSP is on, which
        # would leave formatting to gopls (no -local grouping) instead.
        format.enable = true;
        format.type = [ "goimports" ];
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
    # goimports `-local <module>` gives GoLand-style import groups
    # (stdlib / third-party / local). The module path is detected from the
    # nearest go.mod at format time, so it works in any project without config.
    # gopls settings.gopls.local is intentionally left unset (can't be computed
    # statically); conform's goimports runs last on save, so grouping is correct.
    formatter.conform-nvim.setupOpts.formatters.goimports.args = lib.generators.mkLuaInline ''
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
      # Native lazygit float on <leader>gg. Git stash workflow lives in
      # lazygit's stash panel (view/diff/apply/pop/drop); quick fuzzy stash
      # browsing is telescope git_stash on <leader>fvx (nvf default mapping).
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
      # Directory buffers / `nvim .` / `nvim` (no args) → editable netrw-style
      # explorer. nvim-tree stays as the sidebar (see filetree below).
      oil-nvim = {
        enable = true;
        gitStatus.enable = true;
        setupOpts = {
          default_file_explorer = true;
          view_options.show_hidden = true;
          skip_confirm_for_simple_edits = true;
        };
      };
      yazi-nvim = {
        enable = true;
        mappings = {
          openYazi = "<leader>o"; # yazi at current file (default <leader>-)
          openYaziDir = "<leader>O"; # yazi at cwd (default <leader>cw)
          yaziToggle = null; # drop default <c-up>
        };
        setupOpts.open_for_directories = false; # oil owns directories
      };
      # snacks bigfile: files >2 MiB get ft=bigfile → treesitter/syntax/LSP off,
      # keeping million-line repos responsive.
      snacks-nvim = {
        enable = true;
        setupOpts.bigfile = {
          enabled = true;
          size = 2097152;
        };
      };
      outline.aerial-nvim.enable = true; # structure panel on gO
      # Three-way merge tool: a single tab with OURS | RESULT (center) | THEIRS.
      # Resolve with <leader>co (ours) / <leader>ct (theirs) / <leader>cb (base),
      # ]x / [x to jump between conflicts. Auto-opens on startup when the repo
      # has unresolved conflicts (see VimEnter autocmd above).
      diffview-nvim = {
        enable = true;
        setupOpts = {
          view.merge_tool = {
            layout = "diff3_horizontal";
            disable_diagnostics = true;
            winbar_info = true; # label panes: OURS (branch) / THEIRS / BASE
          };
          view.default.winbar_info = true;
          view.file_history.winbar_info = true;
          # The global navic breadcrumbs (lualine winbar) otherwise cover
          # diffview's own OURS/THEIRS winbar labels. Hide the lualine winbar
          # while a diffview tab is focused and restore it on leave — keeps
          # breadcrumbs when editing, shows branch labels when merging.
          hooks = lib.generators.mkLuaInline ''
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
      noice.enable = true;
      breadcrumbs = {
        enable = true; # navic source
        lualine.winbar.enable = true; # breadcrumbs in the winbar
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
          python = "120";
        };
      };
    };
    statusline.lualine.enable = true;
    telescope = {
      enable = true;
      # native fzf sorter — much faster fuzzy matching on large file sets
      extensions = [
        {
          name = "fzf";
          packages = [ pkgs.vimPlugins.telescope-fzf-native-nvim ];
          setup.fzf.fuzzy = true;
        }
      ];
    };
    tabline.nvimBufferline = {
      enable = true;
      mappings = {
        cycleNext = "<S-l>"; # replaces old <C-i> buffer cycling
        cyclePrevious = "<S-h>"; # replaces old <C-o> buffer cycling
      };
    };
    notes.todo-comments.enable = true; # TODO/FIXME highlights + search
    binds = {
      cheatsheet.enable = true; # :Cheatsheet — searchable keymap docs
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
          "<leader>td" = "Todo";
          "<leader>x" = "Diagnostics";
        };
      };
    };
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
    git.vim-fugitive.enable = true; # provides :Git and friends
    # Inline conflict resolution in normal buffers (same <leader>co/ct/cb keys
    # as the diffview merge tool, but for editing files directly).
    git.git-conflict.enable = true;
    filetree.nvimTree = {
      enable = true;
      mappings.findFile = "<leader>eg";
      mappings.refresh = "<leader>er";
      mappings.toggle = "<leader>eq";
      mappings.focus = "<leader>e";
      openOnSetup = false;
      setupOpts = {
        # Root pinned to the startup cwd; the current file is still revealed
        # and highlighted, but the tree root never jumps around.
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
        # Directory buffers are owned by oil.nvim now; hand netrw over.
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
        mode = [
          "n"
          "i"
        ];
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
      # Git: diffview (diff/merge tab) + fugitive status
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
      # Task runner panel (GoLand-style run/build/test). <leader>rr runs a
      # task, <leader>rt toggles the task list.
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
      # Docker TUI float on <leader>D (needs docker running).
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
      # Inline variable values during a debug session.
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
