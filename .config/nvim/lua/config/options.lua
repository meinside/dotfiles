-- .config/nvim/lua/config/options.lua
--
-- File for options
--
-- default: https://www.lazyvim.org/configuration/general#options
--
-- last update: 2025.12.01.

vim.g.mapleader = "\\"
vim.g.lazyvim_picker = "fzf" -- FIXME: `snacks` causes weird errors on nvim startup

local opt = vim.opt
opt.autoindent = true
opt.autowrite = true -- Enable auto write
opt.backspace = { "indent", "eol", "start" } -- allow backspacing over everything in insert mode
opt.breakat = " "
opt.breakindent = true
opt.cindent = true
opt.clipboard = opt.clipboard + "unnamedplus"
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
--opt.colorcolumn = "80" -- handled by 'smartcolumn.nvim'
opt.completeopt = "menu,menuone,noselect"
opt.conceallevel = 2 -- Hide * markup for bold and italic, but not markers with substitutions
opt.confirm = true -- Confirm to save changes before exiting modified buffer
opt.cursorline = true -- Enable highlighting of the current line
opt.cursorlineopt = "screenline,number"
opt.encoding = "utf-8"
opt.expandtab = true -- Use spaces instead of tabs
opt.fileencodings = { "ucs-bom", "utf-8", "korea" }
opt.fillchars = {
	foldopen = "",
	foldclose = "",
	fold = " ",
	foldsep = " ",
	diff = "╱",
	eob = " ",
}
opt.foldcolumn = "0"
opt.foldexpr = "v:lua.require'lazyvim.util'.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldmethod = "expr"
opt.foldtext = ""
opt.formatexpr = "v:lua.require'lazyvim.util'.format.formatexpr()"
opt.formatoptions = "tcrqnlj" -- :h fo-table
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"
opt.guicursor = "n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20"
opt.ignorecase = true -- Ignore case
opt.inccommand = "split"
opt.incsearch = true
opt.jumpoptions = "view"
opt.laststatus = 3 -- global statusline
opt.linebreak = true
opt.list = true
opt.mouse = "" -- disable mouse mode
opt.number = true -- Print line number
opt.pumblend = 10 -- Popup blend
opt.pumheight = 10 -- Maximum number of entries in a popup
opt.relativenumber = true -- Relative line numbers
opt.ruler = true
-- NOTE: scrolling: <C-y> and <C-e> by one line, <C-u> and <C-d> by half page, `zz` for centering the cursor
opt.scrolloff = 0
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.shiftround = true
opt.shiftwidth = 2
opt.shortmess:append({ W = true, I = true, c = true, C = true })
opt.showbreak = "↳"
opt.showcmd = true
opt.showmode = false
opt.sidescrolloff = 8 -- Columns of context
opt.signcolumn = "auto"
opt.smartcase = true
opt.smartindent = true
opt.smoothscroll = true
opt.softtabstop = 2
opt.spelllang = { "en" }
opt.splitbelow = true -- Put new windows below current
opt.splitkeep = "screen"
opt.splitright = true -- Put new windows right of current
opt.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
opt.tabstop = 2
opt.termguicolors = true
opt.timeoutlen = vim.g.vscode and 1000 or 300 -- Lower than default (1000) to quickly trigger which-key
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200 -- Save swap file and trigger CursorHold
opt.virtualedit = "block" -- Allow cursor to move where there is no text in visual block mode
opt.wildmode = "longest:full,full" -- Command-line completion mode
opt.winborder = "none"
opt.winminwidth = 5 -- Minimum window width
opt.wrap = true

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
	signs = true,
	severity_sort = true,
	update_in_insert = false,
	float = {
		source = "if_many",
		border = "rounded",
	},
})
vim.fn.sign_define("DiagnosticSignError", {
	text = "✗",
	texthl = "DiagnosticSignError",
})
vim.fn.sign_define("DiagnosticSignWarn", {
	text = "!",
	texthl = "DiagnosticSignWarn",
})
vim.fn.sign_define("DiagnosticSignInformation", {
	text = "",
	texthl = "DiagnosticSignInfo",
})
vim.fn.sign_define("DiagnosticSignHint", {
	text = "",
	texthl = "DiagnosticSignHint",
})
