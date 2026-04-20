-- .config/nvim/lua/extras.lua
--
-- File for extra plugins of lazyvim
--
-- :LazyExtras
--
-- lazyvim.plugins.extras
--
-- last update: 2026.04.20.

return {
	--------
	-- lazyvim.plugins.extras.coding.*
	--
	{ import = "lazyvim.plugins.extras.coding.luasnip" }, -- NOTE: blink.cmp has built-in snippets; this adds LuaSnip engine

	--------
	-- lazyvim.plugins.extras.dap.*
	--
	{ import = "lazyvim.plugins.extras.dap.core" },

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
	{ import = "lazyvim.plugins.extras.ui.treesitter-context" },

	--------
	-- lazyvim.plugins.extras.util.*
	--
	--{ import = "lazyvim.plugins.extras.util.startuptime" },
}
