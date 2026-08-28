{ inputs, ... }:
let
  # nixd вычисляет рабочее дерево флейка, поэтому собственные mkOption попадают
  # в completion без пересборки. Накладывается поверх makeNvimSettings только
  # там, где хост известен — в standalone-сборке его нет.
  mkNixdSettings =
    pkgs: lib:
    {
      flakePath,
      hostname,
      username,
    }:
    let
      flake = ''(builtins.getFlake "${flakePath}")'';
      host = "${flake}.nixosConfigurations.${hostname}";
      hmType = "${host}.options.home-manager.users.type";
      # HM-модули подключены через users.<name>.imports, поэтому голый
      # getSubOptions видит только апстрим — доопределяем тип определениями
      # пользователя, чтобы в наборе оказались опции nvf/noctalia/zen и прочих.
      hmModules = ''${hmType}.getSubModules ++ builtins.catAttrs "${username}" ${host}.options.home-manager.users.definitions'';
    in
    {
      lsp.servers.nixd.settings.nixd = {
        nixpkgs.expr = "import ${flake}.inputs.nixpkgs { }";
        formatting.command = [ (lib.getExe pkgs.nixfmt) ];
        options = {
          nixos.expr = "${host}.options";
          home_manager.expr = "(${hmType}.substSubModules (${hmModules})).getSubOptions [ ]";
          flake_parts.expr = "${flake}.debug.options";
          flake_parts_persystem.expr = "${flake}.currentSystem.options";
        };
      };
    };

  sqlSources = [
    "lsp"
    "dadbod"
    "snippets"
    "buffer"
  ];

  # Общие настройки nvf для двух потребителей: standalone packages.neovim
  # (perSystem) и flake.homeModules.neovim. Рантайм-зависимости плагинов
  # объявляются здесь, в extraPackages, а не в home.packages: у
  # standalone-сборки нет ни HM, ни системы — обёрнутый nvim должен видеть
  # эти бинари в собственном PATH.
  makeNvimSettings = pkgs: lib: {
    extraPackages = with pkgs; [
      git # fugitive/gitsigns/diffview, :!git
      lazygit # toggleterm.lazygit (<leader>gg)
      lazydocker # lazydocker.nvim
      yazi # yazi-nvim
      fd # telescope find_files
      ripgrep # telescope live_grep
      golangci-lint-langserver # бинарь LSP-сервера из lsp.servers выше
      procps # opencode.nvim: pgrep-based server discovery
      lsof # opencode.nvim: port lookup for discovered servers
      # clang-tools # форматер для protobuf; включить при необходимости
    ];
    globals.loaded_netrwPlugin = 1;
    globals.opencode_opts = {
      server =
        let
          openTerminal =
            fn:
            lib.generators.mkLuaInline # lua
              ''
                function()
                  local cmd = vim.env.OPENCODE_NVIM_RESUME == "1" and "opencode --continue" or "opencode"
                  require("opencode.terminal").${fn}(cmd, {
                    split = "right",
                    width = math.floor(vim.o.columns * 0.35),
                  })
                end
              '';
        in
        {
          start = openTerminal "open";
          toggle = openTerminal "toggle";
          stop =
            lib.generators.mkLuaInline # lua
              ''
                function()
                  require("opencode.terminal").close()
                end
              '';
        };
      lsp = {
        enabled = true;
        handlers = {
          # Апстрим удалил всю lsp-фичу в v1.0.0: hover требует re-trigger,
          # который перерисовывает экран поверх чужих hover и blink.
          hover.enabled = false;
          code_action.enabled = true;
        };
      };
      events = {
        enabled = true;
        reload = true;
        permissions = {
          enabled = true;
          edits.enabled = true;
        };
      };
    };
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
      autoread = true;
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
        signatureHelp = "<C-s>";
      };
      servers = {
        gopls.before_attach =
          lib.generators.mkLuaInline # lua
            ''
              function(config)
                return vim.bo.filetype ~= "diffview"
              end
            '';
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

        sqls.on_attach = lib.mkForce null;
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
                vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                vim.bo[event.buf].indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
              end
            '';
      }
      {
        event = [ "FileType" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function(event)
                vim.bo[event.buf].indentkeys = "0{,0},0),0],:,0#,!^F,o,O,e"
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
              function(event)
                vim.bo[event.buf].tabstop = 2
                vim.bo[event.buf].shiftwidth = 2
                vim.bo[event.buf].softtabstop = 2
                vim.bo[event.buf].expandtab = true
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
        pattern = [ "OpencodeEvent:session.status" ];
        callback =
          lib.generators.mkLuaInline # lua
            ''
              function(args)
                local status = args.data.event.properties.status
                if status.type == "error" then
                  vim.notify(status.message or "error", vim.log.levels.ERROR, { title = "opencode" })
                elseif status.type == "requesting_permission" then
                  vim.notify("waiting for permission", vim.log.levels.WARN, { title = "opencode" })
                end
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
                if vim.env.OPENCODE_NVIM_RESUME == "1" then
                  return
                end
                for _, arg in ipairs(vim.v.argv) do
                  -- --headless: herdr-nvim daemon и скриптовые запуски без UI.
                  if arg == "-c" or arg == "-S" or arg == "--headless" or arg:match("^%+") then
                    return
                  end
                end
                local has_diff_flag = false
                for _, arg in ipairs(vim.v.argv) do
                  if arg == "-d" then
                    has_diff_flag = true
                    break
                  end
                end
                if has_diff_flag then
                  vim.schedule(function()
                    vim.cmd("DiffviewOpen")
                  end)
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
                if vim.env.OPENCODE_NVIM_RESUME ~= "1" then
                  return
                end
                vim.schedule(function()
                  require("opencode").toggle()
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
                local ok_lzn, lzn = pcall(require, "lz.n")
                if ok_lzn then
                  lzn.trigger_load("telescope")
                end

                local go_env_cache = {}
                local function go_env(name)
                  if go_env_cache[name] == nil then
                    local out = vim.fn.systemlist({ "go", "env", name })
                    go_env_cache[name] = (vim.v.shell_error == 0 and out[1] and out[1] ~= "") and out[1] or false
                  end
                  return go_env_cache[name] or nil
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
                          local rules = {}
                          local root = vim.fs.root(0, ".vscode")
                          if root then
                            rules[#rules + 1] = { from = root, to = "/build" }
                          end
                          local modcache = go_env("GOMODCACHE")
                          if modcache then
                            rules[#rules + 1] = { from = modcache, to = "/go/pkg/mod" }
                          end
                          local goroot = go_env("GOROOT")
                          if goroot then
                            rules[#rules + 1] = { from = goroot .. "/src", to = "/usr/local/go/src" }
                          end
                          if #rules > 0 then
                            config = vim.tbl_extend("force", config, { substitutePath = rules })
                          end
                        end
                        on_config(config)
                      end,
                    })
                    return
                  end
                  delve_adapter(function(adapter_config)
                    local dlv = vim.fn.exepath("dlv")
                    if adapter_config.executable and dlv ~= "" then
                      adapter_config.executable.command = dlv
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
              function(event)
                vim.b[event.buf].disableFormatSave = true
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
        lsp.servers = [ "nixd" ];
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.nix;
      };
      json = {
        enable = true;
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.json;
      };
      bash = {
        enable = true;
        format.enable = false;
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
      lua = {
        enable = true;
        extensions.lazydev = {
          enable = true;
          setupOpts.library = [ "nvim-dap-ui" ];
        };
        treesitter.package = pkgs.vimPlugins.nvim-treesitter.builtGrammars.lua;
      };
      sql = {
        enable = true;
        format.enable = false;
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
        setupOpts = {
          bigfile = {
            enabled = true;
            size = 2097152;
          };
          input.enabled = true;
          picker = {
            enabled = true;
            win.input.keys."<a-o>" = {
              "@" = "opencode_send";
              mode = [
                "n"
                "i"
              ];
            };
            actions.opencode_send =
              lib.generators.mkLuaInline # lua
                ''require("opencode").snacks_picker_send'';
          };
        };
      };
      motion.flash-nvim = {
        enable = true;
        setupOpts.modes.search.enabled = true;
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
          default_args.DiffviewOpen = [ "--imply-local" ];
          keymaps =
            let
              focusFiles = lib.generators.mkLuaInline ''require("diffview.actions").focus_files'';
              toggleFiles = lib.generators.mkLuaInline ''require("diffview.actions").toggle_files'';
              fileHistoryAtCursor =
                lib.generators.mkLuaInline # lua
                  ''
                    function()
                      local view = require("diffview.lib").get_current_view()
                      if not view or not view.infer_cur_file then
                        return
                      end
                      local file = view:infer_cur_file()
                      if not file then
                        return
                      end
                      vim.cmd("DiffviewFileHistory " .. vim.fn.fnameescape(file.absolute_path))
                    end
                  '';
              panelKeys = [
                [
                  "n"
                  "<leader>e"
                  focusFiles
                  {
                    desc = "Focus the file panel [diffview]";
                  }
                ]
                [
                  "n"
                  "<leader>eq"
                  toggleFiles
                  {
                    desc = "Close the file panel [diffview]";
                  }
                ]
              ];
              historyKey = [
                [
                  "n"
                  "<leader>gh"
                  fileHistoryAtCursor
                  {
                    desc = "File history (entry under cursor) [diffview]";
                  }
                ]
              ];
            in
            {
              view = panelKeys;
              file_panel = panelKeys ++ historyKey;
              file_history_panel = panelKeys ++ historyKey;
            };
          hooks =
            lib.generators.mkLuaInline # lua
              ''
                {
                  view_opened = function()
                    require("lualine").hide({ place = { "winbar" }, unhide = false })
                    vim.schedule(function()
                      pcall(vim.cmd, "DiffviewRefresh")
                      for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
                        local wins = vim.api.nvim_tabpage_list_wins(tabnr)
                        if #wins == 1 then
                          local buf = vim.api.nvim_win_get_buf(wins[1])
                          if
                            vim.bo[buf].buftype == ""
                            and vim.api.nvim_buf_get_name(buf) == ""
                            and not vim.bo[buf].modified
                          then
                            pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(tabnr))
                            pcall(vim.cmd, "bwipeout " .. buf)
                          end
                        end
                      end
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
    statusline.lualine = {
      enable = true;
      # nvim-dap-ui renders its play/step/stop controls in the dap-repl
      # window's winbar; keep lualine's breadcrumbs winbar off that window so
      # it doesn't overwrite them.
      disabledFiletypes.winbar = [ "dap-repl" ];
      extraActiveSection.z = [
        # Deferred through pcall: lz.n loads opencode.nvim after lualine's setup.
        # lua
        (''
          function()
            local ok, opencode = pcall(require, "opencode")
            return ok and opencode.statusline() or ""
          end
        '')
        # lua
        (''
          function()
            local ok, out = pcall(function()
              return require("herdr-nvim").statusline()
            end)
            return ok and out or ""
          end
        '')
      ];
    };
    telescope = {
      enable = true;
      mappings = {
        lspDefinitions = "gd";
        lspReferences = "gu";
        lspImplementations = "gi";
        lspTypeDefinitions = "gD";
      };
      setupOpts.pickers = {
        lsp_definitions.jump_type = "tab";
        lsp_references.jump_type = "tab";
        lsp_implementations.jump_type = "tab";
        lsp_type_definitions.jump_type = "tab";
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
          "<leader>a" = "AI (herdr)";
          "<leader>A" = "AI (opencode)";
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
    snippets.luasnip = {
      enable = true;
      providers = [ ];
    };
    autocomplete.blink-cmp = {
      enable = true;
      friendly-snippets.enable = true;
      mappings = {
        confirm = null;
        next = null;
        previous = null;
      };
      setupOpts = {
        keymap = {
          "<CR>" = [
            "select_and_accept"
            "fallback"
          ];
          "<Tab>" = [
            "snippet_forward"
            "accept"
            "fallback"
          ];
          "<S-Tab>" = [
            "snippet_backward"
            "select_prev"
            "fallback"
          ];
          "<Up>" = [
            "select_prev"
            "fallback"
          ];
          "<Down>" = [
            "select_next"
            "fallback"
          ];
          "<C-s>" = [
            "show_signature"
            "hide_signature"
            "fallback"
          ];
        };
        cmdline.keymap.preset = "cmdline";
        appearance.nerd_font_variant = "mono";
        completion = {
          list.selection.preselect = false;
          ghost_text.enabled = true;
          documentation.window.border = "rounded";
          menu = {
            border = "rounded";
            draw = {
              treesitter = [ "lsp" ];
              columns = [
                [ "kind_icon" ]
                [
                  "label"
                  "label_description"
                ]
                [ "kind" ]
              ];
            };
          };
        };
        signature = {
          enabled = true;
          window.border = "rounded";
        };
        sources = {
          per_filetype = {
            sql = sqlSources;
            mysql = sqlSources;
            plsql = sqlSources;
          };
          providers.dadbod = {
            name = "Dadbod";
            module = "vim_dadbod_completion.blink";
          };
        };
      };
    };
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
      mappings.toggle = null;
      mappings.focus = null;
      openOnSetup = false;
      setupOpts = {
        sync_root_with_cwd = false;
        respect_buf_cwd = false;
        prefer_startup_root = true;
        view.float = {
          enable = true;
          quit_on_focus_loss = false;
          open_win_config =
            lib.generators.mkLuaInline # lua
              ''
                function()
                  return {
                    relative = "editor",
                    border = "rounded",
                    row = 0,
                    col = 0,
                    width = 40,
                    height = vim.o.lines - vim.o.cmdheight - 2,
                  }
                end
              '';
        };
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
    debugger.nvim-dap.ui = {
      enable = true;
      setupOpts.layouts = [
        {
          position = "left";
          size = 40;
          elements = [
            {
              id = "breakpoints";
              size = 0.2;
            }
            {
              id = "stacks";
              size = 0.2;
            }
            {
              id = "watches";
              size = 0.2;
            }
            {
              id = "repl";
              size = 0.2;
            }
            {
              id = "console";
              size = 0.2;
            }
          ];
        }
        {
          position = "bottom";
          size = 20;
          elements = [
            {
              id = "scopes";
              size = 1;
            }
          ];
        }
      ];
    };
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
        key = "<leader>eq";
        mode = "n";
        silent = true;
        action = ":NvimTreeClose<CR>";
        desc = "Close filetree";
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
        key = "<leader>rf";
        mode = "n";
        lua = true;
        desc = "Fill struct [gopls]";
        action = # lua
          ''
            function()
              vim.lsp.buf.code_action({
                context = { only = { "refactor.rewrite.fillStruct" } },
                apply = true,
              })
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
        key = "<LeftMouse>";
        mode = "n";
        action = "<LeftMouse><cmd>lua if vim.bo.buftype == 'terminal' then vim.cmd.startinsert() end<CR>";
        desc = "Enter terminal mode when clicking into a terminal";
      }
      {
        key = "<Esc><Esc>";
        mode = "t";
        action = "<C-\\><C-n>";
        desc = "Leave terminal mode";
      }
      {
        key = "<leader>e";
        mode = "n";
        lua = true;
        desc = "Toggle NvimTree (floating)";
        action = # lua
          ''
            function()
              require("lz.n").trigger_load("nvim-tree-lua")
              local api = require("nvim-tree.api")
              local conf = require("nvim-tree.config")
              if api.tree.is_visible() then
                api.tree.close()
                if conf.g.view.float.enable then
                  return
                end
              end
              conf.g.view.float.enable = true
              api.tree.open()
            end
          '';
      }
      {
        key = "<leader>ef";
        mode = "n";
        lua = true;
        desc = "Focus NvimTree (split)";
        action = # lua
          ''
            function()
              require("lz.n").trigger_load("nvim-tree-lua")
              local api = require("nvim-tree.api")
              local conf = require("nvim-tree.config")
              if api.tree.is_visible() and conf.g.view.float.enable then
                api.tree.close()
              end
              conf.g.view.float.enable = false
              api.tree.open()
            end
          '';
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
      "symbol-usage.nvim" = {
        package = pkgs.vimPlugins.symbol-usage-nvim;
        setupModule = "symbol-usage";
        setupOpts = {
          vt_position = "signcolumn";
          vt_priority = 5;
          request_pending_text = false;
          references.enabled = false;
          definition.enabled = false;
          implementation.enabled = true;
          hl.link = "DiagnosticHint";
          kinds = [
            (lib.generators.mkLuaInline "vim.lsp.protocol.SymbolKind.Interface")
            (lib.generators.mkLuaInline "vim.lsp.protocol.SymbolKind.Struct")
            (lib.generators.mkLuaInline "vim.lsp.protocol.SymbolKind.Method")
          ];
          text_format =
            lib.generators.mkLuaInline # lua
              ''
                function(symbol)
                  local raw = symbol.raw_symbol
                  local has_impl = symbol.implementation and symbol.implementation > 0
                  if raw and raw.kind == vim.lsp.protocol.SymbolKind.Interface then
                    return has_impl and { { "↓", "SymbolUsageText" } } or nil
                  end
                  local overrides = vim.b[vim.api.nvim_get_current_buf()].go_override_methods
                  if raw and overrides and overrides[raw.name] then
                    return { { "↑↑", "SymbolUsageText" } }
                  end
                  return has_impl and { { "↑", "SymbolUsageText" } } or nil
                end
              '';
        };
        lazy = true;
        ft = [ "go" ];
        after = # lua
          ''
            local SymbolKind = vim.lsp.protocol.SymbolKind
            local member_cache = {}

            local function members_of(client, bufnr, uri, typename, cb)
              local key = uri .. "#" .. typename
              if member_cache[key] then
                return cb(member_cache[key])
              end
              client:request("textDocument/documentSymbol", { textDocument = { uri = uri } }, function(err, syms)
                local set = {}
                if not err then
                  local pattern = "^%(%*?" .. vim.pesc(typename) .. "%)%.(.+)$"
                  for _, s in ipairs(syms or {}) do
                    local method = s.name:match(pattern)
                    if method then
                      set[method] = true
                    end
                  end
                end
                member_cache[key] = set
                cb(set)
              end, bufnr)
            end

            local function refresh_overrides(bufnr)
              local client = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
              if not client then
                return
              end
              local td = { uri = vim.uri_from_bufnr(bufnr) }
              client:request("textDocument/documentSymbol", { textDocument = td }, function(err, syms)
                if err or not syms then
                  return
                end
                local embedded, methods = {}, {}
                for _, s in ipairs(syms) do
                  if s.kind == SymbolKind.Struct then
                    for _, f in ipairs(s.children or {}) do
                      if
                        f.kind == SymbolKind.Field
                        and f.detail
                        and (f.detail == f.name or vim.endswith(f.detail, "." .. f.name))
                      then
                        embedded[#embedded + 1] = { owner = s.name, field = f }
                      end
                    end
                  end
                  local recv, method = s.name:match("^%(%*?([%w_]+)%)%.(.+)$")
                  if recv then
                    methods[#methods + 1] = { recv = recv, method = method, id = s.name }
                  end
                end
                if #embedded == 0 or #methods == 0 then
                  vim.b[bufnr].go_override_methods = vim.empty_dict()
                  return
                end
                local found, pending = {}, #embedded
                local function finish()
                  pending = pending - 1
                  if pending > 0 then
                    return
                  end
                  vim.b[bufnr].go_override_methods = next(found) and found or vim.empty_dict()
                  if next(found) and vim.api.nvim_get_current_buf() == bufnr then
                    require("symbol-usage").refresh()
                  end
                end
                for _, e in ipairs(embedded) do
                  client:request(
                    "textDocument/definition",
                    { textDocument = td, position = e.field.selectionRange.start },
                    function(derr, dres)
                      local loc = not derr and (dres and (dres[1] or dres)) or nil
                      if not loc or not loc.uri then
                        return finish()
                      end
                      members_of(client, bufnr, loc.uri, e.field.name, function(set)
                        for _, m in ipairs(methods) do
                          if m.recv == e.owner and set[m.method] then
                            found[m.id] = true
                          end
                        end
                        finish()
                      end)
                    end,
                    bufnr
                  )
                end
              end, bufnr)
            end

            vim.api.nvim_create_autocmd({ "LspAttach", "BufWritePost" }, {
              callback = function(event)
                if vim.bo[event.buf].filetype ~= "go" then
                  return
                end
                if event.event == "BufWritePost" then
                  member_cache = {}
                end
                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(event.buf) then
                    refresh_overrides(event.buf)
                  end
                end)
              end,
            })
          '';
      };
      "opencode.nvim" = {
        package = pkgs.vimPlugins.opencode-nvim;
        # Not lazy: events, edit permissions and buffer reload must be live from
        # startup, and lualine resolves the statusline component on setup.
        lazy = false;
        keys = [
          {
            key = "<leader>Aa";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").ask() end'';
            desc = "Ask [opencode]";
          }
          {
            key = "<leader>Aa";
            mode = "x";
            lua = true;
            action = # lua
              ''function() require("opencode").ask("@this: ") end'';
            desc = "Ask about this [opencode]";
          }
          {
            key = "<leader>AA";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").ask("@this: ") end'';
            desc = "Ask about this [opencode]";
          }
          {
            key = "<leader>AA";
            mode = "x";
            lua = true;
            action = # lua
              ''function() require("opencode").ask() end'';
            desc = "Ask [opencode]";
          }
          {
            key = "<leader>Ax";
            mode = [
              "n"
              "x"
            ];
            lua = true;
            action = # lua
              ''function() require("opencode").prompt("Explain @this and its context") end'';
            desc = "Explain this [opencode]";
          }
          {
            key = "<leader>As";
            mode = [
              "n"
              "x"
            ];
            lua = true;
            action = # lua
              ''function() require("opencode").select() end'';
            desc = "Select prompt/command [opencode]";
          }
          {
            key = "<leader>At";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").toggle() end'';
            desc = "Toggle opencode terminal";
          }
          {
            key = "<leader>An";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.new") end'';
            desc = "New session [opencode]";
          }
          {
            key = "<leader>Ae";
            mode = "n";
            lua = true;
            action = # lua
              ''
                function()
                  require("opencode.ui.select_session")
                    .select_session()
                    :next(function(picked)
                      picked.server:select_session(picked.session.id)
                    end)
                    :catch(function(err)
                      if err then
                        vim.notify(err, vim.log.levels.ERROR, { title = "opencode" })
                      end
                    end)
                end
              '';
            desc = "Select session [opencode]";
          }
          {
            key = "<leader>Ac";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.compact") end'';
            desc = "Compact session [opencode]";
          }
          {
            key = "<leader>Ai";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.interrupt") end'';
            desc = "Interrupt session [opencode]";
          }
          {
            key = "<leader>Au";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.undo") end'';
            desc = "Undo session step [opencode]";
          }
          {
            key = "<leader>AR";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.redo") end'';
            desc = "Redo session step [opencode]";
          }
          {
            key = "<leader>Ag";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("agent.cycle") end'';
            desc = "Cycle agent [opencode]";
          }
          {
            key = "<C-S-u>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.half.page.up") end'';
            desc = "Scroll opencode up";
          }
          {
            key = "<C-S-d>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("opencode").command("session.half.page.down") end'';
            desc = "Scroll opencode down";
          }
          {
            key = "go";
            mode = [
              "n"
              "x"
            ];
            lua = true;
            expr = true;
            action = # lua
              ''function() return require("opencode").operator("@this ") end'';
            desc = "Append range to opencode";
          }
          {
            key = "goo";
            mode = "n";
            lua = true;
            expr = true;
            action = # lua
              ''function() return require("opencode").operator("@this ") .. "_" end'';
            desc = "Append line to opencode";
          }
        ];
      };
      "herdr-splits.nvim" = {
        package = pkgs.vimUtils.buildVimPlugin {
          pname = "herdr-splits.nvim";
          version = "0.5.3";
          src = pkgs.fetchFromGitHub {
            owner = "lmilojevicc";
            repo = "herdr-splits.nvim";
            tag = "v0.5.3";
            hash = "sha256-7rHAPSjd2n16FGOcqI/1KNHl1yCmMOVVwiJl/eEU9n8=";
          };
        };
        # Outside a herdr pane <C-h/j/k/l> must stay plain wincmd.
        enabled =
          lib.generators.mkLuaInline # lua
            ''function() return vim.env.HERDR_ENV == "1" end'';
        lazy = false;
        setupModule = "herdr-splits";
        setupOpts = {
          at_edge = "wrap";
          nav_at_edge = "wrap";
          unzoom_on_nav = true;
          ignored_filetypes = [
            "NvimTree"
            "Trouble"
            "aerial"
            "dadbod-ui"
            "dbout"
            "dbui"
            "qf"
            "snacks_picker"
            "yazi"
          ];
        };
        keys = [
          {
            key = "<C-a>h";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").move_cursor_left() end'';
            desc = "Navigate left [herdr]";
          }
          {
            key = "<C-a>j";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").move_cursor_down() end'';
            desc = "Navigate down [herdr]";
          }
          {
            key = "<C-a>k";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").move_cursor_up() end'';
            desc = "Navigate up [herdr]";
          }
          {
            key = "<C-a>l";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").move_cursor_right() end'';
            desc = "Navigate right [herdr]";
          }
          {
            key = "<M-h>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").resize_left() end'';
            desc = "Resize left [herdr]";
          }
          {
            key = "<M-j>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").resize_down() end'';
            desc = "Resize down [herdr]";
          }
          {
            key = "<M-k>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").resize_up() end'';
            desc = "Resize up [herdr]";
          }
          {
            key = "<M-l>";
            mode = "n";
            lua = true;
            action = # lua
              ''function() require("herdr-splits").resize_right() end'';
            desc = "Resize right [herdr]";
          }
        ];
      };
      "herdr-nvim" = {
        package = pkgs.vimUtils.buildVimPlugin {
          pname = "herdr-nvim";
          version = "0.2.1";
          src = pkgs.fetchFromGitHub {
            owner = "ChmaraX";
            repo = "herdr-nvim";
            tag = "v0.2.1";
            hash = "sha256-7xnhtj2ngPe/QXMN8crT3mB+QuJ7PvPFwGuS9TMNPMQ=";
          };
        };
        enabled =
          lib.generators.mkLuaInline # lua
            ''function() return vim.env.HERDR_ENV == "1" end'';
        lazy = false;
        setupModule = "herdr-nvim";
        setupOpts = {
          prefix = "<leader>a";
          keymaps = true;
          clear_after_send = true;
        };
      };
      "nvim-dap-virtual-text" = {
        package = pkgs.vimPlugins.nvim-dap-virtual-text;
        setupModule = "nvim-dap-virtual-text";
        setupOpts = {
          virt_text_pos = "eol";
          display_callback =
            lib.generators.mkLuaInline # lua
              ''
                function(variable, buf, stackframe, node, opts)
                  local value = variable.value:gsub("%s+", " ")
                  if vim.fn.strdisplaywidth(value) > 60 then
                    value = vim.fn.strcharpart(value, 0, 57) .. "…"
                  end
                  return " " .. variable.name .. " = " .. value
                end
              '';
        };
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
    {
      config,
      lib,
      pkgs,
      hostname,
      username,
      ...
    }:
    {
      home.sessionVariables.VISUAL = lib.getExe config.programs.nvf.finalPackage;

      programs.nvf = {
        enable = true;
        defaultEditor = true;
        # Не home.homeDirectory: модуль подключён и для users.root, а флейк
        # лежит в домашнем каталоге основного пользователя.
        settings.vim = pkgs.lib.recursiveUpdate (makeNvimSettings pkgs pkgs.lib) (
          mkNixdSettings pkgs pkgs.lib {
            flakePath = "/home/${username}/dotfiles/nixos";
            inherit hostname;
            inherit username;
          }
        );
      };
    };
}
