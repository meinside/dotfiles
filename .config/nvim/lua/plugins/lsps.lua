-- .config/nvim/lua/plugins/lsps.lua
--
-- last update: 2025.01.02.

local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua

return {
	{
		"neovim/nvim-lspconfig",
	},
	{
		"ray-x/lsp_signature.nvim",
		event = "VeryLazy",
		opts = {
			bind = true,
			handler_opts = { border = "single" },
			hi_parameter = "CurSearch",
		},
		config = function(_, opts)
			require("lsp_signature").setup(opts)
		end,
	},
	{
		"https://git.sr.ht/~whynothugo/lsp_lines.nvim",
		config = function()
			require("lsp_lines").setup()
			vim.diagnostic.config({
				virtual_text = false,
				virtual_lines = {
					only_current_line = true,
					highlight_whole_line = false,
				},
			})
			-- NOTE: https://github.com/folke/lazy.nvim/issues/620
			vim.diagnostic.config({ virtual_lines = false }, require("lazy.core.config").ns)
		end,
	},
	{
		"onsails/lspkind-nvim",
		config = function()
			-- (gray)
			vim.api.nvim_set_hl(0, "CmpItemAbbrDeprecated", {
				bg = "NONE",
				fg = "#808080",
				strikethrough = true,
			})
			-- (blue)
			vim.api.nvim_set_hl(0, "CmpItemAbbrMatch", {
				bg = "NONE",
				fg = "#569CD6",
			})
			vim.api.nvim_set_hl(0, "CmpItemAbbrMatchFuzzy", {
				bg = "NONE",
				fg = "#569CD6",
			})
			-- (light blue)
			vim.api.nvim_set_hl(0, "CmpItemKindVariable", {
				bg = "NONE",
				fg = "#9CDCFE",
			})
			vim.api.nvim_set_hl(0, "CmpItemKindInterface", {
				bg = "NONE",
				fg = "#9CDCFE",
			})
			vim.api.nvim_set_hl(0, "CmpItemKindText", {
				bg = "NONE",
				fg = "#9CDCFE",
			})
			-- (pink)
			vim.api.nvim_set_hl(0, "CmpItemKindFunction", {
				bg = "NONE",
				fg = "#C586C0",
			})
			vim.api.nvim_set_hl(0, "CmpItemKindMethod", {
				bg = "NONE",
				fg = "#C586C0",
			})
			-- (front)
			vim.api.nvim_set_hl(0, "CmpItemKindKeyword", {
				bg = "NONE",
				fg = "#D4D4D4",
			})
			vim.api.nvim_set_hl(0, "CmpItemKindProperty", {
				bg = "NONE",
				fg = "#D4D4D4",
			})
			vim.api.nvim_set_hl(0, "CmpItemKindUnit", {
				bg = "NONE",
				fg = "#D4D4D4",
			})
		end,
	},
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = custom.installable_lsp_names(), -- NOTE: ~/.config/nvim/lua/custom/lsps_sample.lua
				automatic_installation = false,
			})
		end,
	},

	-- dim unused things
	{
		"zbirenbaum/neodim",
		event = "LspAttach",
		config = function()
			require("neodim").setup({
				alpha = 0.75,
				blend_color = "#000000",
				hide = {
					signs = true,
					underline = true,
					virtual_text = true,
				},
				regex = {
					"[uU]nused",
					"[nN]ever [rR]ead",
					"[nN]ot [rR]ead",
				},
				priority = 128,
				disable = {},
			})
		end,
		ft = { "c", "clojure", "cpp", "elixir", "fennel", "go", "janet", "lua", "nim", "ruby", "rust", "sh", "zig" },
	},
}
