-- .config/nvim/lua/extras.lua
--
-- lazyvim.plugins.extras
--
-- last update: 2025.02.14.

return {
	--------
	-- lazyvim.plugins.extras.coding.*
	--
	{ import = "lazyvim.plugins.extras.coding.luasnip" },

	--------
	-- lazyvim.plugins.extras.dap.*
	--
	{ import = "lazyvim.plugins.extras.dap.core" },

	--------
	-- lazyvim.plugins.extras.editor.*
	--
	{ import = "lazyvim.plugins.extras.editor.mini-files" },
	{ import = "lazyvim.plugins.extras.editor.telescope" },

	--------
	-- lazyvim.plugins.extras.lang.*
	--
	--{ import = "lazyvim.plugins.extras.lang.clojure" },
	--{ import = "lazyvim.plugins.extras.lang.cmake" },
	--{ import = "lazyvim.plugins.extras.lang.elixir" },
	--{ import = "lazyvim.plugins.extras.lang.erlang" },
	{ import = "lazyvim.plugins.extras.lang.git" },
	--{ import = "lazyvim.plugins.extras.lang.go" },
	--{ import = "lazyvim.plugins.extras.lang.java" },
	{ import = "lazyvim.plugins.extras.lang.json" },
	{ import = "lazyvim.plugins.extras.lang.markdown" },
	--{ import = "lazyvim.plugins.extras.lang.ruby" },
	--{ import = "lazyvim.plugins.extras.lang.rust" },
	{ import = "lazyvim.plugins.extras.lang.toml" },
	{ import = "lazyvim.plugins.extras.lang.yaml" },
	--{ import = "lazyvim.plugins.extras.lang.zig" },

	--------
	-- lazyvim.plugins.extras.ui.*
	--
	{ import = "lazyvim.plugins.extras.ui.indent-blankline" },
	{ import = "lazyvim.plugins.extras.ui.mini-starter" },
	{ import = "lazyvim.plugins.extras.ui.treesitter-context" },

	--------
	-- lazyvim.plugins.extras.util.*
	--
	--{ import = "lazyvim.plugins.extras.util.startuptime" },
}
