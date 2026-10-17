# Стандарты редактирования `neovim.nix`

Правки `nixos/modules/features/neovim.nix` вести по этим правилам:

- **Декларативность прежде Lua.** Перед тем как писать сырой Lua (`pluginRC`,
  `lazy.plugins.*.after`, ручной `vim.lsp.config`/`vim.lsp.enable` в
  autocmd), проверить исходники nvf (store-путь инпута `nvf` из
  `nix flake archive`) на предмет готовой декларативной опции — например
  `vim.lsp.servers.<name>` вместо ручного `vim.lsp.config`, `vim.lsp.mappings`
  вместо ручных `keymaps` на `vim.lsp.buf.*`, `vim.autocomplete.nvim-cmp.mappings`
  вместо патчинга `cmp.get_config()`, `vim.languages.<lang>.extraDiagnostics`
  вместо ручного `require("lint")`. Обязательно свериться через **context7**
  (`/notashelf/nvf` и соответствующий neovim-плагин) — версии/API меняются,
  доверять памяти нельзя.
- **Комментарии — минимум.** Только для действительно неочевидного: обход
  бага апстрима, порядок инициализации, который иначе сломается, причина,
  почему код похож на мёртвый, но им не является (например, коллизия
  дефолтных маппингов между плагинами). Максимум 1-2 строки, без пересказа
  того, что и так видно из кода или имени опции. Если комментарий не мешает
  убрать его — значит, он не нужен.
- **Подсветка встроенного кода.** Каждый непустой `''...''`-блок (Lua через
  `mkLuaInline`, bash/json/markdown и т.п.) должен иметь маркер языка прямо
  перед открывающими кавычками — так `nvim-treesitter`'s comment-based
  injection (`# <lang>` → `injection.language`) подсвечивает синтаксис:
  ```nix
  on_init =
    lib.generators.mkLuaInline # lua
      ''
        function(client) ... end
      '';
  ```
  Ставить маркер только если это реальный, установленный в конфиге
  treesitter-grammar (см. `vim.treesitter.grammars`/`languages.*.enable`), а
  не самодельный DSL или plaintext-формат без грамматики.
- **Проверка headless перед тем как считать фикс готовым.** Гонять
  `nvim --headless` на реальных файлах пользователя, а не полагаться на то,
  что код «выглядит правильно» (см. `feedback_verify_and_revert_dead_fixes`
  в памяти).
- После правок обязательно прогонять `nixfmt` по изменённому файлу.
