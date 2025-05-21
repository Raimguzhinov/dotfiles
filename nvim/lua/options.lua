require "nvchad.options"

-- add yours here!

local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

local o = vim.o
o.cursorlineopt = "both" -- to enable cursorline!
o.relativenumber = true -- sets vim.opt.relativenumber
o.number = true -- sets vim.opt.number
o.spell = false -- sets vim.opt.spell
o.signcolumn = "auto" -- sets vim.opt.signcolumn to auto
o.wrap = false -- sets vim.opt.wrap
o.shiftwidth = 4
o.tabstop = 4
o.conceallevel = 2
o.clipboard = "unnamedplus"
o.colorcolumn = "140"
o.termguicolors = true

vim.g.mkdp_browserfunc = "OpenMarkdownPreview"

vim.api.nvim_create_user_command("OpenPdf", function()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath:match "%.typ$" then
        local pdf_path = filepath:gsub("%.typ$", ".pdf")
        vim.system { "open", pdf_path }
    end
end, {})
