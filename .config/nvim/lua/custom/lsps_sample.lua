-- .config/nvim/lua/custom/lsps_sample.lua
--
-- File for customized LSPs (sample)
--
-- (duplicate this file to:
--
-- ~/.config/nvim/lua/custom/lsps.lua
--
-- and edit it)
--
-- last update: 2025.11.10.

-- following lsps will be configured automatically or manually.
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
	--fennel_ls = true,

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
