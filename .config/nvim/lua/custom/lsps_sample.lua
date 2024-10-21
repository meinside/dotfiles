-- .config/nvim/lua/custom/lsps_sample.lua
--
-- sample LSP list
--
-- (duplicate this file to: ~/.config/nvim/lua/custom/lsps.lua
-- and edit it)
--
-- last update: 2024.10.21.

-- following lsps will be configured automatically or manually
-- in: ~/.config/nvim/lua/plugins.lua
--
-- if value is `true`, will be configured automatically with `lspconfig`.
-- otherwise (`false`), should be configured manually.
return {
  -- bash
  bashls = true,

  -- clang
  --clangd = true,

  -- clojure
  --clojure_lsp = true,

  -- cmake
  --cmake = true,

  -- elixir
  --elixirls = true,

  -- fennel
  --fennel_language_server = true,

  -- go
  --gopls = true,

  -- json
  jsonls = true,

  -- nim
  --nimls = true,

  -- lua
  lua_ls = true,

  -- python
  --pylsp = true,

  -- ruby
  --solargraph = true,

  -- sql
  --sqlls = true,

  -- rust
  --rust_analyzer = false, -- will be configured automatically by `rustaceanvim`

  -- zig
  --zls = true,
}

