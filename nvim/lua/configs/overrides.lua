local M = {}

M.treesitter = {
    ensure_installed = {
        "vim",
        "lua",
        "c",
        "cpp",
        "markdown",
        "markdown_inline",
        "go",
        "typst",
    },
    highlight = {
        enable = true,
        use_languagetree = true,
    },
    indent = { enable = true },
    auto_install = true,
    sync_install = true,
}

M.mason = {
    ensure_installed = {
        "lua-language-server",
        "clangd",
        "clang-format",
        "gofumpt",
        "gopls",
        "tinymist",
    },
}

-- git support in nvimtree
M.nvimtree = {
    git = {
        enable = true,
    },
    renderer = {
        highlight_git = true,
        icons = {
            show = {
                git = true,
            },
        },
    },
    diagnostics = {
        enable = true,
        show_on_dirs = true,
    },
}

return M
