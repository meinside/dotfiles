-- .config/nvim/lua/plugins/development.lua
--
-- last update: 2025.02.20.

------------------------------------------------
-- imports
--
local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua

------------------------------------------------
-- global variables
--
-- (for all lispy languages)
local lisps = { "fennel", "janet" }
-- (for conjure)
vim.g["conjure#filetypes"] = lisps
vim.g["conjure#filetype#fennel"] = "conjure.client.fennel.stdio" -- for fennel
-- (for nvim-parinfer)
vim.g["parinfer_filetypes"] = lisps
-- (for guns/vim-sexp)
vim.g["sexp_enable_insert_mode_mappings"] = 0 -- '"' key works weirdly in insert mode
vim.g["sexp_filetypes"] = table.concat(lisps, ",")

return {
	--------------------------------
	--
	-- tools for development
	--

	-- code generation & completion
	--
	-- (github copilot)
	-- NOTE: enable 'ai.copilot' with :LazyExtras
	--
	-- (codeium)
	{
		"monkoose/neocodeium", -- :NeoCodeium auth
		event = "VeryLazy",
		config = function()
			local blink = require("blink.cmp")
			require("neocodeium").setup({
				filter = function(bufnr)
					-- NOTE: enable neocodeium only for these file types
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

			-- create an autocommand which closes nvim-cmp when completions are displayed
			vim.api.nvim_create_autocmd("User", {
				pattern = "NeoCodeiumCompletionDisplayed",
				callback = blink.cancel,
			})
		end,
		cond = custom.features().codeium, -- ~/.config/nvim/lua/custom/init.lua
	},

	-- screenshot codeblocks
	{
		"michaelrommel/nvim-silicon",
		lazy = true,
		cmd = "Silicon",
		config = function()
			require("silicon").setup({
				-- NOTE: $ silicon --list-fonts
				font = "JetBrainsMono Nerd Font Mono=20;Nanum Gothic;Noto Color Emoji",
				-- NOTE: $ silicon --list-themes
				theme = "Visual Studio Dark+",
				background = "#000000",
				no_round_corner = true,
				no_window_controls = true,
				tab_width = 2,
				shadow_blur_radius = 0,
				output = function()
					return "./silicon_" .. os.date("!%Y-%m-%dT%H-%M-%S") .. ".png"
				end,
			})
		end,
		cond = function()
			-- NOTE: $ cargo install silicon
			return vim.fn.executable("silicon") == 1
		end,
	},

	-- symbol outlines
	{
		"hedyhli/outline.nvim",
		lazy = true,
		cmd = { "Outline", "OutlineOpen" },
		keys = { { "<leader>to", "<cmd>Outline<CR>", desc = "symbols outline: Toggle" } },
		opts = {},
	},

	-- snippets
	-- NOTE: 'coding.luasnip' is enabled in ../extras.lua

	-- code actions
	{
		"aznhe21/actions-preview.nvim",
		config = function()
			require("actions-preview").setup({
				diff = {
					algorithm = "patience",
					ignore_whitespace = true,
				},
				telescope = require("telescope.themes").get_dropdown({ winblend = 10 }),
			})
		end,
	},

	-- debug adapter
	{
		"mfussenegger/nvim-dap",
		lazy = true,
		config = function()
			-- dap sign icons and colors
			vim.fn.sign_define("DapBreakpoint", {
				text = "•",
				texthl = "LspDiagnosticsSignError",
				linehl = "",
				numhl = "",
			})
			vim.fn.sign_define("DapStopped", {
				text = "",
				texthl = "LspDiagnosticsSignInformation",
				linehl = "DiagnosticUnderlineInfo",
				numhl = "LspDiagnosticsSignInformation",
			})
			vim.fn.sign_define("DapBreakpointRejected", {
				text = "",
				texthl = "LspDiagnosticsSignHint",
				linehl = "",
				numhl = "",
			})
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		config = function()
			require("mason-nvim-dap").setup({
				ensure_installed = custom.installable_debugger_names(), -- NOTE: .config/nvim/lua/custom/debuggers_sample.lua
				automatic_installation = false,
			})
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		config = function()
			local dap, dapui = require("dap"), require("dapui")
			dapui.setup({})

			-- auto toggle debug UIs
			dap.listeners.after.event_initialized["dapui_config"] = function()
				local tools = require("tools") -- ~/.config/nvim/lua/tools.lua
				if not tools.ui.is_mouse_enabled() then
					tools.ui.toggle_mouse()
				end
				dapui.open()
			end
			dap.listeners.before.event_terminated["dapui_config"] = dapui.close
			dap.listeners.before.event_exited["dapui_config"] = dapui.close
		end,
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		config = function()
			require("nvim-dap-virtual-text").setup({ commented = true })
		end,
	},

	-- lint
	{
		"mfussenegger/nvim-lint",
		event = "LazyFile",
		opts = {
			events = { "BufWritePost", "BufReadPost", "InsertLeave" },
			linters_by_ft = custom.linters(), -- .config/nvim/lua/custom/linters_sample.lua
		},
		cond = custom.features().linter, -- .config/nvim/lua/custom/init.lua
	},

	--------------------------------
	--
	-- programming languages
	--

	-- bash
	{
		"bash-lsp/bash-language-server",
		ft = { "sh" },
	},

	-- clojure
	-- NOTE: enable 'lang.clojure' with :LazyExtras

	-- golang
	-- NOTE: enable 'lang.go' with :LazyExtras

	-- <lispy languages>
	--
	-- for auto completion: <C-x><C-o>
	-- for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
	-- for reloading everything: \rr
	-- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
	--{ "Olical/conjure" },
	-- >f, <f : move a form
	-- >e, <e : move an element
	-- >), <), >(, <( : move a parenthesis
	-- <I, >I : insert at the beginning or end of a form
	-- dsf : remove surroundings
	-- cse(, cse), cseb : surround an element with parenthesis
	-- cse[, cse] : surround an element with brackets
	-- cse{, cse} : surround an element with braces
	{
		"guns/vim-sexp",
		ft = lisps,
	},
	{
		"tpope/vim-sexp-mappings-for-regular-people",
		ft = lisps,
	},
	{
		"gpanders/nvim-parinfer",
		ft = lisps,
	},
	-- (fennel)
	{
		"bakpakin/fennel.vim",
		ft = { "fennel" },
	},
	-- (janet)
	-- run janet LSP with: $ janet -e '(import spork/netrepl) (netrepl/server)'
	{
		"janet-lang/janet.vim",
		ft = { "janet" },
	},

	-- nim
	{
		"alaviss/nim.nvim",
		ft = { "nim" },
	},

	-- python
	-- NOTE: enable 'lang.python' with :LazyExtras

	-- ruby
	-- NOTE: enable 'lang.ruby' with :LazyExtras

	-- rust
	-- NOTE: enable 'lang.rust' with :LazyExtras

	-- zig
	-- NOTE: enable 'lang.zig' with :LazyExtras
}
