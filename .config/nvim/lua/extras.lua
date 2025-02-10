-- .config/nvim/lua/extras.lua
--
-- lazyvim.plugins.extras
--
-- last update: 2025.02.10.

return {
	-- use mini.starter instead of alpha
	{ import = "lazyvim.plugins.extras.ui.mini-starter" },

	-- add jsonls and schemastore packages, and setup treesitter for json, json5 and jsonc
	{ import = "lazyvim.plugins.extras.lang.json" },
}
