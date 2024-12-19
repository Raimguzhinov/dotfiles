-- EXAMPLE
local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities
local util = require "lspconfig/util"
local breadcrumb = require "breadcrumb"

local lspconfig = require "lspconfig"
local servers = { "buf_ls" }

local function organize_imports()
    local params = {
        command = "_typescript.organizeImports",
        arguments = { vim.api.nvim_buf_get_name(0) },
    }
    vim.lsp.buf.execute_command(params)
end

-- lsps with default config
for _, lsp in ipairs(servers) do
    lspconfig[lsp].setup {
        on_attach = on_attach,
        on_init = on_init,
        capabilities = capabilities,
        commands = {
            OrganizeImports = {
                organize_imports,
                description = "Organize Imports",
            },
        },
    }
end

-- lspconfig.gopls.setup {
--     on_attach = function(client, bufnr)
--         require("inlay-hints").on_attach(client, bufnr)
--         if client.server_capabilities.documentSymbolProvider then
--             breadcrumb.attach(client, bufnr)
--         end
--         client.server_capabilities.signatureHelpProvider = false
--         on_attach(client, bufnr)
--     end,
--     capabilities = capabilities,
--     cmd = { "gopls" },
--     filetypes = { "go", "gomod", "gowork", "gotmpl" },
--     root_dir = util.root_pattern("go.work", "go.mod", ".git"),
--     settings = {
--         gopls = {
--             completeUnimported = true,
--             usePlaceholders = true,
--             analyses = {
--                 unusedparams = true,
--                 shadow = true,
--             },
--             staticcheck = true,
--         },
--         hints = {
--             rangeVariableTypes = true,
--             parameterNames = true,
--             constantValues = true,
--             assignVariableTypes = true,
--             compositeLiteralFields = true,
--             compositeLiteralTypes = true,
--             functionTypeParameters = true,
--         },
--     },
-- }

lspconfig.clangd.setup {
    -- on_attach = function(client, bufnr)
        -- require("inlay-hints").on_attach(client, bufnr)
        -- if client.server_capabilities.documentSymbolProvider then
        --     breadcrumb.attach(client, bufnr)
        -- end
        -- client.server_capabilities.signatureHelpProvider = false
        -- on_attach(client, bufnr)
    -- end,
    capabilities = capabilities,
    cmd = { "clangd" },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "hpp", "h" },
    root_dir = util.root_pattern('.clangd', '.clang-tidy', '.clang-format', 'compile_commands.json', 'compile_flags.txt', 'configure.ac', '.git'),
    on_new_config = function(new_config, new_cwd)
        local status, cmake = pcall(require, "cmake-tools")
        if status then
            cmake.clangd_on_new_config(new_config)
        end
    end,
    settings = {
        clangd = {
            InlayHints = {
                Designators = true,
                Enabled = true,
                ParameterNames = true,
                DeducedTypes = true,
            },
            fallbackFlags = { "-std=c++20" },
        },
    },
}
