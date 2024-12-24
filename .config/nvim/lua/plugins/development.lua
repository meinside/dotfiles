-- .config/nvim/lua/plugins/development.lua
--
-- last update: 2024.12.24.

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
	{
		"monkoose/neocodeium", -- :NeoCodeium auth
		event = "VeryLazy",
		config = function()
			local neocodeium = require("neocodeium")
			local blink = require("blink.cmp")
			neocodeium.setup({
				--manual = true, -- for nvim-cmp
				filter = function(bufnr)
					if
						vim.tbl_contains({ -- NOTE: enable neocodeium only for these file types
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

			-- alt-e/E: cycle or complete
			vim.keymap.set("i", "<A-e>", neocodeium.cycle_or_complete)
			vim.keymap.set("i", "<A-E>", function()
				neocodeium.cycle_or_complete(-1)
			end)
			-- alt-f: accept
			vim.keymap.set("i", "<A-f>", neocodeium.accept)
		end,
		cond = custom.features().codeium, -- ~/.config/nvim/lua/custom/init.lua
	},

	-- auto pair/close
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = true,
	},

	-- screenshot codeblocks
	{
		"michaelrommel/nvim-silicon",
		lazy = true,
		cmd = "Silicon",
		config = function()
			require("silicon").setup({
				font = "JetBrainsMono Nerd Font Mono=20;Nanum Gothic;Noto Color Emoji", -- NOTE: $ silicon --list-fonts
				theme = "Visual Studio Dark+", -- NOTE: $ silicon --list-themes
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
			return vim.fn.executable("silicon") == 1
		end, -- $ cargo install silicon
	},

	-- symbol outlines
	{
		"hedyhli/outline.nvim",
		lazy = true,
		cmd = { "Outline", "OutlineOpen" },
		keys = { { "<leader>to", "<cmd>Outline<CR>", desc = "symbols outline: Toggle" } },
		opts = {},
	},

	-- todo comments
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},

	-- snippets
	{
		"L3MON4D3/LuaSnip",
		build = "make install_jsregexp",
		config = function()
			require("luasnip.loaders.from_vscode").lazy_load()
		end,
		dependencies = { "rafamadriz/friendly-snippets" },
	},

	-- code actions
	--
	-- `\ca` for showing code action previews
	{
		"aznhe21/actions-preview.nvim",
		config = function()
			local ap = require("actions-preview")
			ap.setup({
				diff = {
					algorithm = "patience",
					ignore_whitespace = true,
				},
				telescope = require("telescope.themes").get_dropdown({ winblend = 10 }),
			})
			vim.keymap.set({ "v", "n" }, "ca", ap.code_actions)
		end,
	},
	{
		"kosayoda/nvim-lightbulb",
		config = function()
			require("nvim-lightbulb").setup({
				autocmd = { enabled = true },
				code_lenses = true,
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
			dap.listeners.after.event_initialized["dapui_config"] = dapui.open
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
		config = function()
			local lint = require("lint")
			lint.linters_by_ft = custom.linters() -- .config/nvim/lua/custom/linters_sample.lua
			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				callback = function()
					lint.try_lint()
				end,
			})
		end,
		cond = custom.features().linter, -- .config/nvim/lua/custom/init.lua
	},

	--------------------------------
	--
	-- programming languages
	--

	-- bash
	{ "bash-lsp/bash-language-server", ft = { "sh" } },

	-- clojure
	-- NOTE: enable 'lang.clojure' in :LazyExtras

	-- golang
	-- NOTE: enable 'lang.go' in :LazyExtras

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
	{ "guns/vim-sexp", ft = lisps },
	{ "tpope/vim-sexp-mappings-for-regular-people", ft = lisps },
	{ "gpanders/nvim-parinfer", ft = lisps },
	{ "PaterJason/cmp-conjure", ft = lisps },
	-- (fennel)
	{ "bakpakin/fennel.vim", ft = { "fennel" } },
	-- (janet)
	-- run janet LSP with: $ janet -e '(import spork/netrepl) (netrepl/server)'
	{ "janet-lang/janet.vim", ft = { "janet" } },

	-- nim
	{ "alaviss/nim.nvim", ft = { "nim" } },

	-- python
	-- NOTE: enable 'lang.python' in :LazyExtras

	-- ruby
	-- NOTE: enable 'lang.ruby' in :LazyExtras

	-- rust
	-- NOTE: enable 'lang.rust' in :LazyExtras
	-- NOTE: install 'rust-analyzer' with `rustup component add rust-analyzer`

	-- zig
	-- NOTE: enable 'lang.zig' in :LazyExtras

	--------------------------------
	--
	-- my neovim lua plugins for testing & development
	--
	{
		"meinside/gemini.nvim",
		config = function()
			require("gemini").setup({
				configFilepath = "~/.config/gemini.nvim/config.json",
				timeout = 30 * 1000,
				model = "gemini-1.5-flash-latest",
				safetyThreshold = "BLOCK_ONLY_HIGH",
				stripOutermostCodeblock = function()
					return vim.bo.filetype ~= "markdown"
				end,
				verbose = false, -- for debugging
			})
		end,
		dependencies = { { "nvim-lua/plenary.nvim" } },

		-- for testing local changes
		--dir = '~/srcs/lua/gemini.nvim/',
	},
}
