-- .config/nvim/lua/locals/lsps.sample.lua
--
-- sample LSP list
--
-- (duplicate this file with path `.config/nvim/lua/locals/lsps.lua` and edit it)
--
-- last update: 2022.12.01.

-- set value to `true` for lspconfig to configure automatically,
--              `false` for manual configuration in .config/nvim/init.lua
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
  sumneko_lua = true,

  -- python
  pylsp = true,

  -- ruby
  solargraph = true,

  -- sql
  sqlls = true,

  -- rust (will be handled by `rust-tools`)
  rust_analyzer = false,

  -- zig
  zls = true,
}

return my_lsps
