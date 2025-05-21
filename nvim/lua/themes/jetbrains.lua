-- Credits to original https://github.com/Everblush/nvim
-- This is modified version of it
---@type Base46Table
local M = {}

M.base_30 = {
    white = "#dadada",
    darker_black = "#10171a",
    black = "#141b1e", -- nvim bg
    black2 = "#1a2124",
    one_bg = "#1e2528",
    one_bg2 = "#272e31",
    one_bg3 = "#2f3639",
    grey = "#3c4346",
    grey_fg = "#464d50",
    grey_fg2 = "#50575a",
    light_grey = "#50575a",
    red = "#e57474",
    baby_pink = "#f48383",
    pink = "#ee9cdd",
    line = "#22292b", -- for lines like vertsplit
    green = "#8ccf7e",
    vibrant_green = "#86d988",
    nord_blue = "#5aa3db",
    blue = "#67b0e8",
    yellow = "#e5c76b",
    sun = "#edcf73",
    orange = "#fcb163",
    dark_purple = "#b570c6",
    teal = "#9bdead",
    purple = "#c47fd5",
    cyan = "#6cbfbf",
    statusline_bg = "#181f22",
    lightbg = "#262d30",
    lightbg2 = "#1f2629",
    pmenu_bg = "#8ccf7e",
    folder_bg = "#71baf2",
}

M.base_16 = {
    base00 = "#141b1e",
    base01 = "#1e2528",
    base02 = "#282f32",
    base03 = "#2d3437",
    base04 = "#3c4346",
    base05 = "#dadada",
    base06 = "#e4e4e4",
    base07 = "#dadada",
    base08 = "#e57474",
    base09 = "#c47fd5",
    base0A = "#e5c76b",
    base0B = "#8ccf7e",
    base0C = "#6cbfbf",
    base0D = "#67b0e8",
    base0E = "#fcb163",
    base0F = "#ef7d7d",
}

M.polish_hl = {
    defaults = {
        Comment = {
            bg = "#ffffff", -- or M.base_30.cyan
            italic = true,
        },
    },

    treesitter = {
        ["@variable.parameter"] = { fg = M.base_16.base05 },
        -- ["@attribute"] = { fg = M.base_16.base0C },
        -- ["@keyword"] = { fg = M.base_30.orange },
        -- ["@function"] = { fg = M.base_30.blue },
    },
}

M.type = "dark"

M = require("base46").override_theme(M, "everblush")

return M
