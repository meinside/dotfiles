-- .config/nvim/lua/plugins/genai.lua
--
-- File for genai plugins
--
-- NOTE: plugins for GenAI services/applications will be placed here
--
-- last update: 2025.09.04.

------------------------------------------------
-- imports
--
local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua
local tools = require("tools") -- ~/.config/nvim/lua/tools.lua

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
				filter = function(bufnr)
					-- disable codeium for .env files (for security?)
					if vim.endswith(vim.api.nvim_buf_get_name(bufnr), ".env") then
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
						}, vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
					then
						return true
					end

					-- show suggestions only when blink.cmp menu is not visible
					return not blink.is_visible()
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
	-- (codecompanion)
	{
		"olimorris/codecompanion.nvim",
		opts = {},
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
		config = function()
			local gemini_api_key = tools.fs.read_json_key(vim.fn.expand(gmnConfigFilepath), "api_key")

			require("codecompanion").setup({
				-- https://codecompanion.olimorris.dev/configuration/adapters.html#configuring-adapter-settings
				adapters = {
					gemini = function()
						return require("codecompanion.adapters").extend("gemini", {
							env = {
								api_key = gemini_api_key,
							},
						})
					end,
					acp = {
						gemini_cli = function()
							return require("codecompanion.adapters").extend("gemini_cli", {
								defaults = {
									auth_method = "gemini-api-key",
									timeout = 20000, -- 20 seconds
								},
								env = {
									GEMINI_API_KEY = gemini_api_key,
								},
							})
						end,
					},
					opts = {
						show_defaults = false,
						show_model_choices = true,
					},
				},
				strategies = {
					chat = {
						adapter = "gemini_cli",
						model = "gemini-2.5-pro",
						think = true,
						---Decorate the user message before it's sent to the LLM
						---@param message string
						---@param adapter CodeCompanion.Adapter
						---@param context table
						---@return string
						prompt_decorator = function(message, adapter, context)
							return string.format([[<prompt>%s</prompt>]], message)
						end,
					},
					inline = {
						adapter = "gemini",
						model = "gemini-2.5-flash",
						think = true,
					},
				},
				display = {
					chat = {
						start_in_insert_mode = true,
					},
				},
			})
		end,
		cond = custom.features().code_assistance, -- ~/.config/nvim/lua/custom/init.lua
	},
	{
		-- for rendering in codecompanion's chat buffer
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "codecompanion" },
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
		dependencies = { { "nvim-lua/plenary.nvim" } },

		-- for testing local changes
		--dir = "~/srcs/lua/gmn.nvim/",
	},
}
