require("lint").linters_by_ft = {
    go = { "golangcilint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    callback = function()
        require("lint").try_lint()
    end,
})

vim.keymap.set("n", "<leader>li", function()
    require("lint").try_lint()
end, { desc = "Trigger linting for current file" })
