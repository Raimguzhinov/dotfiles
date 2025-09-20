{ config, pkgs, ... }:
{
  programs.nvf = {
    enable = true;
    settings = {
      vim.viAlias = true;
      vim.vimAlias = true;
      vim.options = {
        tabstop = 4;
        shiftwidth = 0;
      };
      vim.lsp = {
        enable = true;
        formatOnSave = true;
        inlayHints.enable = true;
        lightbulb.enable = true;
      };
      vim.languages = {
        enableDAP = true;
        enableExtraDiagnostics = true;
        enableFormat = true;
        enableTreesitter = true;
        go.enable = true;
        go.dap.enable = true;
        nix.enable = true;
        nix.format.type = "nixfmt";
        bash.enable = true;
        python.enable = true;
        yaml.enable = true;
      };
      vim.theme = {
        enable = true;
        name = "tokyonight";
        style = "night";
      };
      vim.statusline.lualine.enable = true;
      vim.telescope.enable = true;
      vim.autocomplete.nvim-cmp.enable = true;
      vim.binds.whichKey.enable = true;
      vim.utility.nix-develop.enable = true;
      vim.clipboard = {
        enable = true;
        providers.wl-copy.enable = true;
        registers = "unnamedplus";
      };
      vim.keymaps = [
        {
          key = "<leader>w";
          mode = "n";
          action = "<cmd>write<CR>";
        }
        {
          key = "<leader>q";
          mode = "n";
          action = "<cmd>quit<CR>";
        }
        {
          key = "jk";
          mode = "i";
          silent = true;
          action = "<Esc>";
        }
      ];
    };
  };
}
