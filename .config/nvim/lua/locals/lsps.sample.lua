-- .config/nvim/lua/locals/lsps.sample.lua
--
-- sample LSP list
--
-- (duplicate this file to: ~/.config/nvim/lua/locals/lsps.lua
-- and edit it)
--
-- last update: 2023.04.21.

-- following lsps will be configured automatically or manually
-- in: ~/.config/nvim/lua/plugins.lua
--
-- if value is `true`, will be configured automatically with `lspconfig`.
-- otherwise (`false`), should be configured manually.
return {
  -- bash
  bashls = true,

  -- clang
  clangd = true,

  -- clojure
  clojure_lsp = true,

  -- cmake
  cmake = true,

  -- fennel
  fennel_language_server = true,

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
  rust_analyzer = false, -- will be configured automatically by `rust-tools`

  -- zig
  zls = true,
}

