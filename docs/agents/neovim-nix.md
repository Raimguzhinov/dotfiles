# Editing standards for `neovim.nix`

Edit `nixos/modules/features/neovim.nix` by these rules:

- **Declarative before Lua.** Before writing raw Lua (`pluginRC`,
  `lazy.plugins.*.after`, manual `vim.lsp.config`/`vim.lsp.enable` in an
  autocmd), check the nvf sources (store path of the `nvf` input from
  `nix flake archive`) for a ready declarative option, for example
  `vim.lsp.servers.<name>` instead of manual `vim.lsp.config`, `vim.lsp.mappings`
  instead of manual `keymaps` on `vim.lsp.buf.*`, `vim.autocomplete.nvim-cmp.mappings`
  instead of patching `cmp.get_config()`, `vim.languages.<lang>.extraDiagnostics`
  instead of manual `require("lint")`. Always cross-check with **context7**
  (`/notashelf/nvf` and the relevant neovim plugin): versions/APIs change,
  do not trust memory.
- **Minimal comments.** Only for the truly non-obvious: an upstream bug
  workaround, an initialization order that would otherwise break, the reason
  code looks dead but is not (for example, a collision of default mappings
  between plugins). At most 1-2 lines, no restating what is already visible
  from the code or the option name. If removing a comment does no harm, it
  is not needed.
- **Embedded code highlighting.** Every non-empty `''...''` block (Lua via
  `mkLuaInline`, bash/json/markdown, etc.) must have a language marker right
  before the opening quotes, so `nvim-treesitter`'s comment-based
  injection (`# <lang>` → `injection.language`) highlights the syntax:
  ```nix
  on_init =
    lib.generators.mkLuaInline # lua
      ''
        function(client) ... end
      '';
  ```
  Add the marker only if it is a real treesitter grammar installed in the
  config (see `vim.treesitter.grammars`/`languages.*.enable`), not a
  homemade DSL or a plaintext format without a grammar.
- **Verify headless before considering a fix done.** Run
  `nvim --headless` on the user's real files instead of relying on the code
  "looking right" (see `feedback_verify_and_revert_dead_fixes`
  in memory).
- After edits, always run `nixfmt` on the changed file.

## How nvf is set up here

- The config is generated into `/nix/store` and loaded via
  `$NVIM_APPNAME="nvf"` (runtimepath points to `/nix/store/...-mnw-configDir`).
  It is not in `~/.config/nvf/`; this is a decision, not a bug.
- `nvf-print-config` prints the generated Lua config.
- LSP mappings are bound via a `LspAttach` autocmd (nvf 0.9+).
  Defaults: `<leader>lgd` definition, `<leader>lh` hover, `<leader>lS`
  document symbols.
- nvim-cmp `<Tab>` by default: select_next + auto-complete. Confirm without
  select is overridden via `setupOpts.mapping`.
