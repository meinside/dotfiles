-- .config/nvim/lua/locals/lsps.sample.lua
--
-- sample LSP list
--
-- (duplicate this file with path `.config/nvim/lua/locals/lsps.lua` and edit it)
--
-- last update: 2023.02.13.

-- following lsps will be configured automatically or manually
-- in `.config/nvim/lua/plugins.lua`.
--
-- if value is `true`, will be configured automatically with `lspconfig`.
-- otherwise (`false`), should be configured manually.
local my_lsps = {
  -- bash
  bashls = true,

  -- clang
  clangd = true,

  -- clojure
  clojure_lsp = true,

  -- go
  gopls = true,

  -- haskell
  hls = true,

  -- json
  jsonls = true,

  -- nim
  nimls = true,

  -- lua
  lua_ls = true,

  -- python
  pylsp = true,

  -- ruby
  solargraph = true,

  -- sql
  sqlls = true,

  -- rust
  rust_analyzer = false, -- will be handled by `rust-tools`

  -- zig
  zls = true,
}

return my_lsps
