-- .config/nvim/lua/config/options.lua
--
-- File for options
--
-- default: https://www.lazyvim.org/configuration/general#options
--
-- last update: 2026.03.27.

vim.g.mapleader = "\\"
vim.g.lazyvim_picker = "fzf" -- FIXME: `snacks` causes weird errors on nvim startup

local opt = vim.opt

-- options different from LazyVim/Neovim defaults
opt.breakat = " "
opt.cindent = true
opt.clipboard:append("unnamedplus")
-- for copying to clipboard remotely
if vim.env.SSH_TTY then
	-- NOTE: not working in local macOS tmux
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = require("vim.ui.clipboard.osc52").copy("+"),
			["*"] = require("vim.ui.clipboard.osc52").copy("*"),
		},
		paste = {
			["+"] = require("vim.ui.clipboard.osc52").paste("+"),
			["*"] = require("vim.ui.clipboard.osc52").paste("*"),
		},
	}
end
opt.cursorlineopt = "screenline,number"
opt.fileencodings = { "ucs-bom", "utf-8", "korea" }
opt.foldcolumn = "0" -- LazyVim default: "1"
opt.foldlevelstart = 99
opt.formatoptions = "tcrqnlj" -- LazyVim default: "jcroqlnt", :h fo-table
opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
opt.inccommand = "split" -- LazyVim default: "nosplit"
opt.mouse = "" -- disable mouse mode (LazyVim default: "a")
-- NOTE: scrolling: <C-y> and <C-e> by one line, <C-u> and <C-d> by half page, `zz` for centering the cursor
opt.scrolloff = 0 -- LazyVim default: 4
opt.showbreak = "↳"
opt.signcolumn = "auto" -- LazyVim default: "yes"
opt.softtabstop = 2
opt.winborder = "none"
opt.wrap = true -- LazyVim default: false

-- diagnostics configuration
--
-- NOTE: some related autocmds are defined in:
-- ~/.config/nvim/lua/config/autocmds.lua
vim.diagnostic.config({
	underline = true,
	virtual_text = {
		source = "if_many",
	},
	virtual_lines = {
		source = "if_many",
		current_line = true,
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✗",
			[vim.diagnostic.severity.WARN] = "!",
			[vim.diagnostic.severity.INFO] = "",
			[vim.diagnostic.severity.HINT] = "",
		},
	},
	severity_sort = true,
	update_in_insert = false,
	float = {
		source = "if_many",
		border = "rounded",
	},
})
