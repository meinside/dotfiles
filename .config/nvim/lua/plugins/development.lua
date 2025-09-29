-- .config/nvim/lua/plugins/development.lua
--
-- File for plugins for development
--
-- last update: 2025.09.29.

------------------------------------------------
-- imports
--
local custom = require("custom") -- ~/.config/nvim/lua/custom/init.lua
local tools = require("tools") -- ~/.config/nvim/lua/tools.lua

------------------------------------------------
-- global variables
--
-- (for all lispy languages)
local lisps = { "clojure", "fennel", "janet", "lisp", "scheme" }
-- (for conjure)
vim.g["conjure#filetypes"] = lisps
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

	-- auto completion
	--
	-- (blink.cmp)
	{
		"saghen/blink.cmp",
		opts = {
			completion = {
				menu = { border = "rounded" },
				documentation = { window = { border = "rounded" } },
			},
		},
	},

	-- auto pairs
	--
	-- (mini.pairs)
	{
		"nvim-mini/mini.pairs",
		opts = {
			-- not to close pairs in command, search mode
			modes = { insert = true, command = false, terminal = false },
		},
	},

	-- code generation & completion
	--
	-- NOTE: 'monkoose/neocodeium' is enabled in ./genai.lua
	-- NOTE: 'olimorris/codecompanion.nvim' is enabled in ./genai.lua

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
				backend = { "nui", "snacks" },
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

	-- visualize LSP hierarchies
	{
		"retran/meow.yarn.nvim",
		dependencies = { "MunifTanjim/nui.nvim" },
		config = function()
			require("meow.yarn").setup({})
		end,
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
	-- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
	{ "Olical/conjure" },
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
		"atweiden/vim-fennel",
		config = function()
			vim.g["fennel_highlight_compiler"] = 1
			vim.g["fennel_highlight_aniseed"] = 1
			vim.g["fennel_highlight_lume"] = 1
		end,
		ft = { "fennel" },
	},
	{
		"Olical/nfnl", -- for `.nfnl.fnl`: https://github.com/Olical/nfnl#configuration
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
