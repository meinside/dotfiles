-- .config/nvim/lua/plugins/genai.lua
--
-- File for genai plugins
--
-- NOTE: plugins for GenAI services/applications will be placed here
--
-- last update: 2026.11.10.

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
