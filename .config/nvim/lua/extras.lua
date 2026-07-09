-- .config/nvim/lua/extras.lua
--
-- File for extra plugins of lazyvim
--
-- :LazyExtras
--
-- lazyvim.plugins.extras
--
-- last update: 2026.07.09.

local tools = require("tools") -- ~/.config/nvim/lua/tools.lua
local low_perf = tools.system.low_perf()

local spec = {
	--------
	-- lazyvim.plugins.extras.coding.*
	--
	{ import = "lazyvim.plugins.extras.coding.luasnip" }, -- NOTE: blink.cmp has built-in snippets; this adds LuaSnip engine

	--------
	-- lazyvim.plugins.extras.editor.*
	--
	{ import = "lazyvim.plugins.extras.editor.fzf" },
	--{ import = "lazyvim.plugins.extras.editor.snacks_picker" },

	--------
	-- lazyvim.plugins.extras.lang.*
	--
	--{ import = "lazyvim.plugins.extras.lang.clojure" },
	--{ import = "lazyvim.plugins.extras.lang.cmake" },
	--{ import = "lazyvim.plugins.extras.lang.elixir" },
	--{ import = "lazyvim.plugins.extras.lang.erlang" },
	--{ import = "lazyvim.plugins.extras.lang.gleam" },
	{ import = "lazyvim.plugins.extras.lang.git" },
	--{ import = "lazyvim.plugins.extras.lang.go" },
	--{ import = "lazyvim.plugins.extras.lang.java" },
	{ import = "lazyvim.plugins.extras.lang.json" },
	{ import = "lazyvim.plugins.extras.lang.markdown" },
	--{ import = "lazyvim.plugins.extras.lang.python" },
	--{ import = "lazyvim.plugins.extras.lang.ruby" },
	--{ import = "lazyvim.plugins.extras.lang.rust" },
	--{ import = "lazyvim.plugins.extras.lang.sql" },
	{ import = "lazyvim.plugins.extras.lang.toml" },
	{ import = "lazyvim.plugins.extras.lang.yaml" },
	--{ import = "lazyvim.plugins.extras.lang.zig" },

	--------
	-- lazyvim.plugins.extras.ui.*
	--
	{ import = "lazyvim.plugins.extras.ui.mini-indentscope" }, -- NOTE: optional in v15 (snacks.scope is core default)
	{ import = "lazyvim.plugins.extras.ui.mini-starter" },

	--------
	-- lazyvim.plugins.extras.util.*
	--
	--{ import = "lazyvim.plugins.extras.util.startuptime" },
}

-- extras that are too heavy for low-performance machines
if not low_perf then
	vim.list_extend(spec, {
		-- lazyvim.plugins.extras.dap.*
		{ import = "lazyvim.plugins.extras.dap.core" },
		-- lazyvim.plugins.extras.ui.*
		{ import = "lazyvim.plugins.extras.ui.treesitter-context" },
	})
end

return spec
