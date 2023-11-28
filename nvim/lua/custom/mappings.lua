local M = {}

M.general = {

  n = {
    ["<C-h>"] = { "<cmd> TmuxNavigateLeft <CR>", "window left" },
    ["<C-j>"] = { "<cmd> TmuxNavigateDown <CR>", "window down" },
    ["<C-k>"] = { "<cmd> TmuxNavigateUp <CR>", "window up" },
    ["<C-l>"] = { "<cmd> TmuxNavigateRight <CR>", "window right" },
    ["<leader>ch"] = { "<cmd>lua require(\"cpptool\").create_file()<CR>" },
    ["<leader>cf"] = { "<cmd>lua require(\"cpptool\").create_func_def()<CR>" },
    ["<leader>o"] = { "<cmd>lua require(\"ranger-nvim\").open(true)<CR>" },
    ["<leader>cg"] = {
      ":ChatGPTCompleteCode<CR>",
      "Step over",
    },
    ["<leader>gl"] = {
      ":Flog<CR>",
      "Git Log",
    },
    ["<leader>gf"] = {
      ":DiffviewFileHistory<CR>",
      "Git File History",
    },
    ["<leader>gc"] = {
      ":DiffviewOpen HEAD~2<CR>",
      "Git Last Commit",
    },
    ["<leader>gt"] = {
      ":DiffviewToggleFile<CR>",
      "Git Last Commit",
    },
  },
  v = {
    ["v"] = { "V" },
    ["<leader><up>"] = {
      "<cmd>lua require('cpptool').move_lines(\"up\")<CR>",
      "cpptool-up-lines",
    },
    ["<leader><down>"] = {
      "<cmd>lua require('cpptool').move_lines(\"down\")<CR>",
      "cpptool-down-lines",
    },
  }
}

M.dap = {
  plugin = true,
  n = {
    ["<leader>db"] = {
      "<cmd> DapToggleBreakpoint <CR>",
      "Add breakpoint at line",
    },
    ["<leader>dr"] = {
      "<cmd> DapContinue <CR>",
      "Start or continue the debugger",
    },
    ["<leader>du"] = {
      function()
        require('dapui').toggle()
      end,      
      "Debug UI",
    },
    ["<leader>dd"] = {
      function()
        require('dap').continue()
      end,
      "Continue",
    }
  }
}

M.dap_python = {
  plugin = true,
  n = {
    ["<leader>dpr"] = {
      function()
        require('dap-python').test_method()
      end
    }
  }
}

M.crates = {
  plugin = true,
  n = {
    ["<leader>rcu"] = {
      function ()
        require('crates').upgrade_all_crates()
      end,
      "update crates"
    }
  }
}
vim.g.codeium_disable_bindings = 1

return M
