-- .config/nvim/lua/plugins/genai.lua
--
-- File for genai plugins
--
-- NOTE: plugins for GenAI services/applications will be placed here
--
-- last update: 2026.04.01.

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
	-- (codeium)
	{
		"monkoose/neocodeium", -- :NeoCodeium auth
		event = "VeryLazy",
		config = function()
			local blink = require("blink.cmp")
			local neocodeium = require("neocodeium")

			neocodeium.setup({
				completion = {
					menu = {
						auto_show = function(ctx)
							return ctx.mode ~= "default"
						end,
					},
				},
				filter = function(bufnr)
					-- disable codeium for .env files (for security?)
					if vim.api.nvim_buf_get_name(bufnr):sub(-4) == ".env" then
						return false
					end

					-- enable neocodeium only for these file types
					if
						vim.tbl_contains({
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
						}, vim.bo[bufnr].filetype)
					then
						-- show suggestions only when blink.cmp menu is not visible
						return not blink.is_visible()
					end

					return false
				end,
				filetypes = {
					["."] = false,
					["dap-repl"] = false,
					DressingInput = false,
					gitcommit = false,
					gitrebase = false,
					help = false,
					TelescopePrompt = false,
				},
				root_dir = {
					".bzr",
					".git",
					".hg",
					".svn",
					"build.zig",
					"Cargo.toml",
					"Gemfile",
					"go.mod",
					"package.json",
					"project.clj",
					"project.janet",
				},
			})

			-- clear suggestions when blink.cmp menu is opened
			vim.api.nvim_create_autocmd("User", {
				pattern = "BlinkCmpMenuOpen",
				callback = function()
					neocodeium.clear()
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
				model = "gemini-2.5-flash",
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
