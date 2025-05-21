require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

-- cross-platform pasting
vim.cmd "inoremap <C-v> <C-r>+"
vim.cmd [[
function OpenMarkdownPreview (url)
  execute "silent ! firefox --private-window " . a:url
endfunction
]]

-- General
map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("n", "vv", "V")
map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
map("n", "<leader>q", ":q <CR>", { desc = "Exit" })
map("n", "<leader>wq", ":wqa <CR>", { desc = "Exit and save" })
map("n", "<leader>w", ":w <CR>", { desc = "Save file" })
map("n", "<leader>wa", ":wa <CR>", { desc = "Save all" })
map("n", "<leader>cx", function()
    require("nvchad.tabufline").closeAllBufs()
end, { desc = "Close All Buffers" })
-- switch between windows
map("n", "th", "<C-w>h", { desc = "Window left" })
map("n", "tl", "<C-w>l", { desc = "Window right" })
map("n", "tj", "<C-w>j", { desc = "Window down" })
map("n", "tk", "<C-w>k", { desc = "Window up" })
map("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find Todo" })
map("n", "\\", "<cmd>:vsplit <CR>", { desc = "Vertical Split" })
map("n", "<c-l>", "<cmd>:TmuxNavigateRight<cr>", { desc = "Tmux Right" })
map("n", "<c-h>", "<cmd>:TmuxNavigateLeft<cr>", { desc = "Tmux Left" })
map("n", "<c-k>", "<cmd>:TmuxNavigateUp<cr>", { desc = "Tmux Up" })
map("n", "<c-j>", "<cmd>:TmuxNavigateDown<cr>", { desc = "Tmux Down" })

-- Trouble
map("n", "<leader>qx", "<cmd>TroubleToggle<CR>", { desc = "Open Trouble" })
map("n", "<leader>qw", "<cmd>TroubleToggle workspace_diagnostics<CR>", { desc = "Open Workspace Trouble" })
map("n", "<leader>qd", "<cmd>TroubleToggle document_diagnostics<CR>", { desc = "Open Document Trouble" })
map("n", "<leader>qq", "<cmd>TroubleToggle quickfix<CR>", { desc = "Open Quickfix" })
map("n", "<leader>ql", "<cmd>TroubleToggle loclist<CR>", { desc = "Open Location List" })
map("n", "<leader>qt", "<cmd>TodoTrouble<CR>", { desc = "Open Todo Trouble" })

-- GoLang
map("n", "<leader>i", ":GoIfErr<CR>", { desc = "GoIfErr" })
map("n", "<leader>+", ":GoRun<CR>", { desc = "GoRun" })
map("n", "<leader>+t", ":GoTest -F<CR>", { desc = "GoTest" })
map("n", "<leader>++", ":CMakeRun<CR>", { desc = "CMakeRun" })
map("n", "<leader>k", ":GoDoc<CR>", { desc = "GoDoc" })
map("n", "<leader>l", ":GoLint<CR>", { desc = "GoLint" })
-- map("n", "<leader>ra", ":GoRename<CR>", { desc = "GoRename" })

-- Debug
map("n", "<leader>db", function()
    require("dap").toggle_breakpoint()
end, { desc = "Toggle Breakpoint" })
map("n", "<leader>ds", function()
    require("dap").continue()
end, { desc = "Start" })
map("n", "<leader>dn", function()
    require("dap").step_over()
end, { desc = "Step Over" })

-- Git
map("n", "<leader>gl", ":Flog<CR>", { desc = "Git Log" })
map("n", "<leader>gf", ":DiffviewFileHistory<CR>", { desc = "Git File History" })
map("n", "<leader>gc", ":DiffviewOpen HEAD~1<CR>", { desc = "Git Last Commit" })
map("n", "<leader>gt", ":DiffviewToggleFile<CR>", { desc = "Git File History Toogle" })

-- Terminal
map("n", "<C-]>", function()
    require("nvchad.term").toggle { pos = "vsp", size = 0.4 }
end, { desc = "Toogle Terminal Vertical" })
map("n", "<C-\\>", function()
    require("nvchad.term").toggle { pos = "sp", size = 0.4 }
end, { desc = "Toogle Terminal Horizontal" })
map("n", "<C-f>", function()
    require("nvchad.term").toggle { pos = "float" }
end, { desc = "Toogle Terminal Float" })
map("t", "<C-]>", function()
    require("nvchad.term").toggle { pos = "vsp" }
end, { desc = "Toogle Terminal Vertical" })
map("t", "<C-\\>", function()
    require("nvchad.term").toggle { pos = "sp" }
end, { desc = "Toogle Terminal Horizontal" })
map("t", "<C-f>", function()
    require("nvchad.term").toggle { pos = "float" }
end, { desc = "Toogle Terminal Float" })
