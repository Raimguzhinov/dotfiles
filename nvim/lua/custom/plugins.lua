local plugins = {
  {
    "rcarriga/nvim-dap-ui",
    event = "VeryLazy",
    dependencies = "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end
  },
  {
    'junegunn/goyo.vim',
    event = "VeryLazy",
  },  
  {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
      { 'tpope/vim-dadbod', event = "VeryLazy" },
      { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd = {
      'DBUI',
      'DBUIToggle',
      'DBUIAddConnection',
      'DBUIFindBuffer',
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      ensure_installed = {
        "codelldb",
        "cppdbg",
        -- "vscode-cpptools",
      },
      handlers = {
        function(config)
          require('mason-nvim-dap').default_setup(config)
        end,
        codelldb = function(config)
            config.adapters = {
	            type = "executable",
	            command = "/usr/bin/lldb",
              name = "lldb",
            }
            require('mason-nvim-dap').default_setup(config) -- don't forget this!
        end,
      },
    },
  },
  {
    "kelly-lin/ranger.nvim",
    config = function()
      require("ranger-nvim").setup({
        enable_cmds = true,
        replace_netrw = false,
        ui = {
          border = "none",
          height = 1,
          width = 1,
          x = 0.5,
          y = 0.5,
        }
      })
    end,
  },
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },
  {
    "liaozixin/nvim-cpptools",
    config = function()
      require("nvim-cpptools").setup()
    end
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function() vim.fn["mkdp#util#install"]() end,
  },
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      require("chatgpt").setup()
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
  },
  {
    "nvim-neotest/neotest",
    event = "VeryLazy",
    config = function()
      require("neotest").setup {
        adapters = {
          require "neotest-jest" {
            jestCommand = "npm test --",
            jestConfigFile = "custom.jest.config.ts",
            env = { CI = true },
            cwd = function(path)
              return vim.fn.getcwd()
            end,
          },
        },
      }
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "haydenmeade/neotest-jest",
    },
  },
    {
    "folke/neodev.nvim",
    config = function()
      require("neodev").setup {
        library = { plugins = { "nvim-dap-ui" }, types = true },
      }
    end,
  },
  {
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup {
        mapping = {"jk", "jj"}, -- a table with mappings to use
        timeout = vim.o.timeoutlen, -- the time in which the keys must be hit in ms. Use option timeoutlen by default
        clear_empty_lines = false, -- clear line after escaping if there is only whitespace
        keys = "<Esc>", -- keys used for escaping, if it is a function will use the result everytime
        -- example(recommended)
        -- keys = function()
        --   return vim.api.nvim_win_get_cursor(0)[2] > 1 and '<esc>l' or '<esc>'
        -- end,
      }
    end,
  },
  { "tpope/vim-fugitive" },
  { "rbong/vim-flog", dependencies = {
    "tpope/vim-fugitive",
  }, lazy = false },
  { "sindrets/diffview.nvim", lazy = false },
  {
    "ggandor/leap.nvim",
    lazy = false,
    config = function()
      require("leap").add_default_mappings(true)
    end,
  },
  {
    "kevinhwang91/nvim-bqf",
    lazy = false,
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = false,
    config = function()
      require("todo-comments").setup()
    end,
  },
  {
    "mfussenegger/nvim-dap",
    config = function(_, _)
      require("core.utils").load_mappings("dap")
    end
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = {
      "mfussenegger/nvim-dap",
      "rcarriga/nvim-dap-ui",
    },
    config = function(_, _)
      local path = "~/.local/share/nvim/mason/packages/debugpy/venv/bin/python"
      require("dap-python").setup(path)
      require("core.utils").load_mappings("dap_python")
    end,
  },
  {
    "jose-elias-alvarez/null-ls.nvim",
    -- event = "VeryLazy",
    ft = {"cpp", "go", "python"},
    opts = function()
      return require "custom.configs.null-ls"
    end,
  },
  {
    'saecki/crates.nvim',
    ft = {"toml"},
    config = function(_, opts)
      local crates  = require('crates')
      crates.setup(opts)
      require('cmp').setup.buffer({
        sources = { { name = "crates" }}
      })
      crates.show()
      require("core.utils").load_mappings("crates")
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "plugins.configs.lspconfig"
      require "custom.configs.lspconfig"
    end,
  },
  {
    "simrat39/rust-tools.nvim",
    ft = "rust",
    dependencies = "neovim/nvim-lspconfig",
    opts = function ()
      return require "custom.configs.rust-tools"
    end,
    config = function(_, opts)
      require('rust-tools').setup(opts)
    end
  },
  {
    "rust-lang/rust.vim",
    ft = "rust",
    init = function ()
      vim.g.rustfmt_autosave = 1
    end
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    lazy = false,
    config = function(_, _)
      require("nvim-dap-virtual-text").setup()
    end
  },
  {
    'Exafunction/codeium.vim',
    event = 'BufEnter',
    config = function ()
    -- Change '<C-g>' here to any keycode you like.
      vim.keymap.set('i', '<S-Right>', function () return vim.fn['codeium#Accept']() end, { expr = true })
      vim.keymap.set('i', '<S-Up>', function() return vim.fn['codeium#CycleCompletions'](1) end, { expr = true })
      vim.keymap.set('i', '<S-Down>', function() return vim.fn['codeium#CycleCompletions'](-1) end, { expr = true })
      vim.keymap.set('i', '<S-Left>', function() return vim.fn['codeium#Clear']() end, { expr = true })
    end,
  },
  {
    'Civitasv/cmake-tools.nvim',
    init = function ()
      require("cmake-tools").setup {
        cmake_command = "cmake", -- this is used to specify cmake command path
        cmake_regenerate_on_save = true, -- auto generate when save CMakeLists.txt
        cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" }, -- this will be passed when invoke `CMakeGenerate`
        cmake_build_options = {}, -- this will be passed when invoke `CMakeBuild`
        cmake_build_directory = "build", -- this is used to specify generate directory for cmake
        cmake_build_directory_prefix = "cmake_build_", -- when cmake_build_directory is set to "", this option will be activated
        cmake_soft_link_compile_commands = true, -- this will automatically make a soft link from compile commands file to project root dir
        cmake_compile_commands_from_lsp = false, -- this will automatically set compile commands file location using lsp, to use it, please set `cmake_soft_link_compile_commands` to false
        cmake_kits_path = nil, -- this is used to specify global cmake kits path, see CMakeKits for detailed usage
        cmake_variants_message = {
          short = { show = true }, -- whether to show short message
          long = { show = true, max_length = 40 }, -- whether to show long message
        },
        cmake_dap_configuration = { -- debug settings for cmake
          name = "cpp",
          type = "cppdbg",
          -- type = "cpptools",
          request = "launch",
          stopOnEntry = false,
          runInTerminal = true,
          console = "integratedTerminal",
        },
        cmake_executor = { -- executor to use
          name = "quickfix", -- name of the executor
          opts = {}, -- the options the executor will get, possible values depend on the executor type. See `default_opts` for possible values.
          default_opts = { -- a list of default and possible values for executors
            quickfix = {
              show = "always", -- "always", "only_on_error"
              position = "belowright", -- "bottom", "top"
              size = 10,
            },
            overseer = {
              new_task_opts = {}, -- options to pass into the `overseer.new_task` command
              on_new_task = function(task) end, -- a function that gets overseer.Task when it is created, before calling `task:start`
            },
            terminal = {}, -- terminal executor uses the values in cmake_terminal
          },
        },
        cmake_terminal = {
          name = "terminal",
          opts = {
            name = "Main Terminal",
            prefix_name = "[CMakeTools]: ", -- This must be included and must be unique, otherwise the terminals will not work. Do not use a simple spacebar " ", or any generic name
            split_direction = "vertical", -- "horizontal", "vertical"
            split_size = 46,

            -- Window handling
            single_terminal_per_instance = true, -- Single viewport, multiple windows
            single_terminal_per_tab = true, -- Single viewport per tab
            keep_terminal_static_location = true, -- Static location of the viewport if avialable

            -- Running Tasks
            start_insert_in_launch_task = true, -- If you want to enter terminal with :startinsert upon using :CMakeRun
            start_insert_in_other_tasks = true, -- If you want to enter terminal with :startinsert upon launching all other cmake tasks in the terminal. Generally set as false
            focus_on_main_terminal = true, -- Focus on cmake terminal when cmake task is launched. Only used if executor is terminal.
            focus_on_launch_terminal = true, -- Focus on cmake launch terminal when executable target in launched.
          },
         },
         cmake_notifications = {
           enabled = true, -- show cmake execution progress in nvim-notify
           spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }, -- icons used for progress display
           refresh_rate_ms = 100, -- how often to iterate icons
         },
      }
    end
  },
  {
    "loctvl842/breadcrumb.nvim",
    requires = {"nvim-tree/nvim-web-devicons"},
    init = function ()
      require("breadcrumb").setup({
      	disabled_filetype = {
      		"",
      		"help",
      	},
      	icons = {
      		Module = " ",
      		Namespace = " ",
      		Package = " ",
      		String = "󰅳 ",
      		Number = " ",
      		Boolean = "◩ ",
      		Array = " ",
      		Object = " ",
      		Null = "󰟢 ",
      		Tag = " ",
          Text = "󰦨 ",
          Method = " ",
          Function = " ",
          Constructor = " ",
          Field = " ",
          Variable = " ",
          Class = " ",
          Interface = " ",
          Property = " ",
          Unit = " ",
          Value = "󰾡 ",
          Enum = " ",
          Key = " ",
          Snippet = " ",
          Color = " ",
          File = " ",
          Reference = " ",
          Folder = " ",
          EnumMember = " ",
          Constant = " ",
          Struct = " ",
          Event = "",
          Operator = " ",
          TypeParameter = " ",
          Specifier = " ",
          Statement = "",
          Recovery = " ",
          TranslationUnit = " ",
          PackExpansion = " "

      	},
      	separator = ">",
      	depth_limit = 0,
      	depth_limit_indicator = "..",
          	color_icons = true,
      	highlight_group = {
      		component = "BreadcrumbText",
      		separator = "BreadcrumbSeparator",
      	},
      })
    end
  },
  {
    "nvim-lualine/lualine.nvim", -- status line
    event = "VeryLazy",
    config = function()
      local lualine = require("lualine")
      local cmake = require("cmake-tools")
      local icons = require("custom.configs.icons")
      local conditions = {
        buffer_not_empty = function()
          return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
        end,
        hide_in_width = function()
          return vim.fn.winwidth(0) > 80
        end,
        check_git_workspace = function()
          local filepath = vim.fn.expand("%:p:h")
          local gitdir = vim.fn.finddir(".git", filepath .. ";")
          return gitdir and #gitdir > 0 and #gitdir < #filepath
        end,
      }
      local colors = {
        normal = {
          bg       = "#202328",
          fg       = "#bbc2cf",
          yellow   = "#ECBE7B",
          cyan     = "#008080",
          darkblue = "#081633",
          green    = "#98be65",
          orange   = "#FF8800",
          violet   = "#a9a1e1",
          magenta  = "#c678dd",
          blue     = "#51afef",
          red      = "#ec5f67",
        },
        nightfly = {
          bg       = "#011627",
          fg       = "#acb4c2",
          yellow   = "#ecc48d",
          cyan     = "#7fdbca",
          darkblue = "#82aaff",
          green    = "#21c7a8",
          orange   = "#e3d18a",
          violet   = "#a9a1e1",
          magenta  = "#ae81ff",
          blue     = "#82aaff ",
          red      = "#ff5874",
        },
        light = {
          bg       = "#f6f2ee",
          fg       = "#3d2b5a",
          yellow   = "#ac5402",
          cyan     = "#287980",
          darkblue = "#2848a9",
          green    = "#396847",
          orange   = "#a5222f",
          violet   = "#8452d5",
          magenta  = "#6e33ce",
          blue     = "#2848a9",
          red      = "#b3434e",
        },
        catppuccin_mocha = {
          -- bg       = "#1E1E2E",
          fg       = "#CDD6F4",
          yellow   = "#F9E2AF",
          cyan     = "#7fdbca",
          darkblue = "#89B4FA",
          green    = "#A6E3A1",
          orange   = "#e3d18a",
          violet   = "#a9a1e1",
          magenta  = "#ae81ff",
          blue     = "#89B4FA",
          red      = "#F38BA8",
        }
      }
      colors = colors.catppuccin_mocha;
      local breadcrumb = function()
      	local breadcrumb_status_ok, breadcrumb = pcall(require, "breadcrumb")
      	if not breadcrumb_status_ok then
      		return
      	end
      	return breadcrumb.get_breadcrumb()
      end
      local config = {
        options = {
          icons_enabled = true,
          component_separators = "",
          section_separators = "",
          disabled_filetypes = { "alpha", "dashboard", "Outline", "NvimTree", "terminal", "cmake_tools_terminal", "dap-repl", "dap",
            "DAP Watches", "DAP Stacks", "DAP Breakpoints", "DAP Scopes"},
          always_divide_middle = true,
          theme = {
            -- We are going to use lualine_c an lualine_x as left and
            -- right section. Both are highlighted by c theme .  So we
            -- are just setting default looks o statusline
            normal = { c = { fg = colors.fg, bg = colors.bg } },
            inactive = { c = { fg = colors.fg, bg = colors.bg } },
          },
        },
        winbar = {
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          -- c for left
          lualine_c = {},
          -- x for right
          lualine_x = {},
        },
        inactive_winbar = {
          lualine_a = {{
            function()
              return icons.ui.Line
            end,
            color = { fg = colors.blue }, -- Sets highlighting of component
            padding = { left = 0, right = 1 }, -- We don't need space before this
          }},
      		lualine_b = {},
      		lualine_c = { breadcrumb },
      		lualine_x = {},
      		lualine_y = {},
      		lualine_z = {
            "filetype",
            {
              "o:encoding",
              fmt = string.upper,
              cond = conditions.hide_in_width,
              color = { fg = colors.red, gui = "bold" },
            },
            {
              "fileformat",
              fmt = string.upper,
              icons_enabled = false,
              cond = conditions.hide_in_width,
              color = { fg = colors.red, gui = "bold" },
            },
            {
              "filesize",
              cond = conditions.hide_in_width,
              icon = icons.documents.Filesize,
              color = { fg = colors.orange, gui = "bold" },
            },
          },
      	},
        sections = {},
        inactive_sections = {},
        tabline = {},
        extensions = {},
      }
      -- Inserts a component in lualine_c at left section
      local function ins_left(component)
        table.insert(config.winbar.lualine_c, component)
      end
      -- Inserts a component in lualine_x ot right section
      local function ins_right(component)
        table.insert(config.winbar.lualine_x, component)
      end
      ins_left {
        function()
          return icons.ui.Line
        end,
        color = { fg = colors.blue }, -- Sets highlighting of component
        padding = { left = 0, right = 1 }, -- We don't need space before this
      }
      ins_left {
        -- mode component
        function()
          return icons.kind.Event
        end,
        color = function()
          -- auto change color according to neovims mode
          local mode_color = {
            n = colors.red,
            i = colors.green,
            v = colors.blue,
            ["�"] = colors.blue,
            V = colors.blue,
            c = colors.magenta,
            no = colors.red,
            s = colors.orange,
            S = colors.orange,
            ["�"] = colors.orange,
            ic = colors.yellow,
            R = colors.violet,
            Rv = colors.violet,
            cv = colors.red,
            ce = colors.red,
            r = colors.cyan,
            rm = colors.cyan,
            ["r?"] = colors.cyan,
            ["!"] = colors.red,
            t = colors.red,
          }
          return { fg = mode_color[vim.fn.mode()] }
        end,
        -- padding = { right = 1 },
      }
      ins_left {
        -- "filename",
        breadcrumb,
        cond = conditions.buffer_not_empty,
        color = { fg = colors.magenta, gui = "bold" },
      }
      -- Insert mid section. You can make any number of sections in neovim :)
      -- for lualine it's any number greater then 2
      ins_left {
        function()
          return "%="
        end,
      }
      -- Add components to right sections
      -- ins_right {
      --   function()
      --     return icons.ui.Kit
      --   end,
      --   cond = function()
      --     return cmake.is_cmake_project() and not cmake.has_cmake_preset()
      --   end,
      --   on_click = function(n, mouse)
      --     if (n == 1) then
      --       if (mouse == "l") then
      --         vim.cmd("CMakeSelectKit")
      --       end
      --     end
      --   end
      -- }
      ins_right {
        function()
          local c_preset = cmake.get_configure_preset()
          return "CMake: [" .. (c_preset and c_preset or "X") .. "]"
        end,
        icon = icons.ui.Search,
        cond = function()
          return cmake.is_cmake_project() and cmake.has_cmake_preset()
        end,
        on_click = function(n, mouse)
          if (n == 1) then
            if (mouse == "l") then
              vim.cmd("CMakeSelectConfigurePreset")
            end
          end
        end
      }
      ins_right {
        function()
          local type = cmake.get_build_type()
          return "CMake: [" .. (type and type or "") .. "]"
        end,
        icon = icons.ui.Search,
        cond = function()
          return cmake.is_cmake_project() and not cmake.has_cmake_preset()
        end,
        on_click = function(n, mouse)
          if (n == 1) then
            if (mouse == "l") then
              vim.cmd("CMakeSelectBuildType")
            end
          end
        end
      }
      ins_right {
        function()
          return icons.ui.Hammer
        end,
        cond = cmake.is_cmake_project,
        on_click = function(n, mouse)
          if (n == 1) then
            if (mouse == "l") then
              vim.cmd("CMakeBuild")
            end
          end
        end
      }
      ins_right {
        function()
          return icons.ui.Run
        end,
        cond = cmake.is_cmake_project,
        on_click = function(n, mouse)
          if (n == 1) then
            if (mouse == "l") then
              vim.cmd("CMakeRun")
            end
          end
        end
      }
      ins_right {
        function()
          return icons.ui.Debug
        end,
        cond = cmake.is_cmake_project,
        on_click = function(n, mouse)
          if (n == 1) then
            if (mouse == "l") then
              vim.cmd("CMakeDebug")
            end
          end
        end
      }
      -- ins_right {
      --   function()
      --     local b_preset = cmake.get_build_preset()
      --     return "[" .. (b_preset and b_preset or "X") .. "]"
      --   end,
      --   icon = icons.ui.Search,
      --   cond = function()
      --     return cmake.is_cmake_project() and cmake.has_cmake_preset()
      --   end,
      --   on_click = function(n, mouse)
      --     if (n == 1) then
      --       if (mouse == "l") then
      --         vim.cmd("CMakeSelectBuildPreset")
      --       end
      --     end
      --   end
      -- }
      -- ins_right {
      --   function()
      --     local b_target = cmake.get_build_target()
      --     return "[" .. (b_target and b_target or "X") .. "]"
      --   end,
      --   cond = cmake.is_cmake_project,
      --   on_click = function(n, mouse)
      --     if (n == 1) then
      --       if (mouse == "l") then
      --         vim.cmd("CMakeSelectBuildTarget")
      --       end
      --     end
      --   end
      -- }
      -- ins_right {
      --   function()
      --     local l_target = cmake.get_launch_target()
      --     return "[" .. (l_target and l_target or "X") .. "]"
      --   end,
      --   cond = cmake.is_cmake_project,
      --   on_click = function(n, mouse)
      --     if (n == 1) then
      --       if (mouse == "l") then
      --         vim.cmd("CMakeSelectLaunchTarget")
      --       end
      --     end
      --   end
      -- }
      ins_right {
        "o:encoding", -- option component same as &encoding in viml
        fmt = string.upper, -- I'm not sure why it's upper case either ;)
        cond = conditions.hide_in_width,
        icon = icons.ui.NewFile,
        color = { fg = colors.red, gui = "bold" },
      }
      -- ins_right {
      --   "fileformat",
      --   fmt = string.upper,
      --   icons_enabled = false,
      --   color = { fg = colors.red, gui = "bold" },
      -- }
      ins_right {
        "location",
        color = { fg = colors.green, gui = "bold" },
      }
      -- ins_right {
      --   function()
      --     return vim.api.nvim_buf_get_option(0, "shiftwidth")
      --   end,
      --   icons_enabled = false,
      --   color = { fg = colors.green, gui = "bold" },
      -- }
      -- Now don't forget to initialize lualine
      lualine.setup(config)
    end
  },
  {
    'tanvirtin/vgit.nvim',
    requires = {
     'nvim-lua/plenary.nvim'
    },
    init = function()
      require('vgit').setup()
    end
  },
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "clangd",
        "clang-format",
        "codelldb",
        "black",
        "debugpy",
        "mypy",
        "ruff",
        "pyright",
        "rust-analyzer",
        "cpptools",
        "gopls",
      }
    }
  }
}
return plugins
