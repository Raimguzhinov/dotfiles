local options = {
    formatters_by_ft = {
        lua = { "stylua" },
        go = { "gofumpt" }, --,"goimports_reviser" }, --"golines" },
        cpp = { "clang_format" },
        typst = { "typstyle" },
        -- css = { "prettier" },
        -- html = { "prettier" },
    },
    format_on_save = {
        -- These options will be passed to conform.format()
        timeout_ms = 500,
        lsp_format = "fallback",
    },
}

require("conform").setup(options)
