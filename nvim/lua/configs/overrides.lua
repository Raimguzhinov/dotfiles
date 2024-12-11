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
    },
    indent = {
        enable = true,
    },
}

M.mason = {
    ensure_installed = {
        "lua-language-server",
        "clangd",
        "clang-format",
        "gopls",
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
