-- .config/nvim/lua/plugins/lsps.lua
--
-- File for LSPs
--
-- last update: 2026.02.27.

local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua

return {
	{
		"onsails/lspkind-nvim",
		config = function()
			require("lspkind").init({
				mode = "symbol_text",
				preset = "default",
				symbol_map = {
					Text = "󰉿",
					Method = "󰆧",
					Function = "󰊕",
					Constructor = "",
					Field = "󰜢",
					Variable = "󰀫",
					Class = "󰠱",
					Interface = "",
					Module = "",
					Property = "󰜢",
					Unit = "󰑭",
					Value = "󰎠",
					Enum = "",
					Keyword = "󰌋",
					Snippet = "",
					Color = "󰏘",
					File = "󰈙",
					Reference = "󰈇",
					Folder = "󰉋",
					EnumMember = "",
					Constant = "󰏿",
					Struct = "󰙅",
					Event = "",
					Operator = "󰆕",
					TypeParameter = "",
				},
			})
		end,
	},
	{
		"mason-org/mason.nvim",
		opts = {
			ui = { border = "rounded" },
		},
	},
	{
		"mason-org/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				automatic_enable = true,
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
		ft = {
			"c",
			"clojure",
			"cpp",
			"elixir",
			"erlang",
			"fennel",
			"gleam",
			"go",
			"janet",
			"lua",
			"nim",
			"python",
			"ruby",
			"rust",
			"sh",
			"zig",
		},
	},
}
