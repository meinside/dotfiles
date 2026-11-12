-- .config/nvim/lua/plugins/genai.lua
--
-- File for genai plugins
--
-- NOTE: plugins for GenAI services/applications will be placed here
--
-- last update: 2026.11.12.

------------------------------------------------
-- imports
--
local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua

------------------------------------------------
-- constants
--
-- ~/.config/gmn.nvim/config.json
local gmnConfigFilepath = "~/.config/gmn.nvim/config.json"

return {
	-- (github copilot)
	{
		"github/copilot.vim", -- :Copilot setup
		cmd = "Copilot",
		event = "InsertEnter",
		init = function()
			vim.g.copilot_no_tab_map = true -- leave <Tab> to blink.cmp

			-- enable copilot only for these file types
			-- (.env files have filetype `env`, so they are excluded)
			-- NOTE: build the table first; `vim.g.copilot_filetypes[ft] = true`
			-- would only modify a copy of the global variable
			local filetypes = { ["*"] = false }
			for _, ft in ipairs({
				"c",
				"clojure",
				"cmake",
				"cpp",
				"css",
				"elixir",
				"fennel",
				"go",
				"gomod",
				"gowork",
				"html",
				"java",
				"javascript",
				"janet",
				"lua",
				"python",
				"ruby",
				"rust",
				"sh",
				"zig",
			}) do
				filetypes[ft] = true
			end
			vim.g.copilot_filetypes = filetypes
		end,
		config = function()
			-- alt-f: accept
			vim.keymap.set("i", "<A-f>", 'copilot#Accept("")', {
				expr = true,
				replace_keycodes = false,
				desc = "Copilot: Accept suggestion",
			})
			-- alt-e: cycle through suggestions (or request one)
			vim.keymap.set("i", "<A-e>", function()
				if vim.fn["copilot#GetDisplayedSuggestion"]().text ~= "" then
					vim.fn["copilot#Next"]()
				else
					vim.fn["copilot#Suggest"]()
				end
			end, { desc = "Copilot: Cycle through suggestions" })

			-- hide suggestions while blink.cmp menu is visible
			--
			-- NOTE: b:copilot_enabled takes precedence over g:copilot_filetypes,
			-- so the previous value must be restored exactly (nil = unset);
			-- `b:copilot_hidden_by_blink` guards against repeated open events
			local group = vim.api.nvim_create_augroup("copilot_blink", { clear = true })
			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "BlinkCmpMenuOpen",
				callback = function()
					if not vim.b.copilot_hidden_by_blink then
						vim.b.copilot_hidden_by_blink = true
						vim.b.copilot_prev_enabled = vim.b.copilot_enabled
						vim.b.copilot_enabled = false
					end
					vim.fn["copilot#Dismiss"]()
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				group = group,
				pattern = "BlinkCmpMenuClose",
				callback = function()
					if vim.b.copilot_hidden_by_blink then
						vim.b.copilot_enabled = vim.b.copilot_prev_enabled
						vim.b.copilot_prev_enabled = nil
						vim.b.copilot_hidden_by_blink = nil
					end
				end,
			})
		end,

		cond = custom.features().code_assistance, -- ~/.config/nvim/lua/custom/init.lua
	},

	--------------------------------
	-- (gmn.nvim)
	{
		"meinside/gmn.nvim",
		config = function()
			require("gmn").setup({
				configFilepath = gmnConfigFilepath,
				timeout = 30 * 1000,
				model = "gemini-3.8-flash",
				safetyThreshold = "BLOCK_ONLY_HIGH",
				stripOutermostCodeblock = function()
					return vim.bo.filetype ~= "markdown"
				end,
				verbose = false, -- for debugging
			})
		end,

		-- for testing local changes
		--dir = "~/srcs/lua/gmn.nvim/",
	},
}
