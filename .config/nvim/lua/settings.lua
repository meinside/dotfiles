-- .config/nvim/lua/settings.lua
--
-- My neovim settings
--
-- NOTE: sourced from: `.config/nvim/init.lua`
--
-- last update: 2022.12.06.


------------------------------------------------
--
-- options

local opt = vim.opt
opt.mouse = ''
opt.backspace = { 'indent', 'eol', 'start' } -- allow backspacing over everything in insert mode
opt.history = 50
opt.number = true
opt.ruler = true
opt.showcmd = true
opt.incsearch = true
opt.smartcase = true
opt.cindent = true
opt.autoindent = true
opt.smartindent = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.fileencodings = { 'ucs-bom', 'utf-8', 'korea' }
opt.showbreak = '↳'
opt.wildmenu = true
opt.breakindent = true
opt.splitbelow = true
opt.splitright = true
opt.foldmethod = 'indent' -- automatically fold on indent
opt.foldlevelstart = 20 -- but open all folds on file open
opt.updatetime = 1000 -- for shortening delay of CursorHold
opt.cursorline = true -- highlight current line
vim.o.signcolumn = 'number'

-- for toggling mouse: \mm
local mouse_enabled = false
vim.keymap.set('n', '<leader>mm', function()
  if mouse_enabled then
    opt.mouse = ''
    print 'mouse disabled'
  else
    opt.mouse = 'nvi'
    print 'mouse enabled'
  end
  mouse_enabled = not mouse_enabled
end, { remap = false, silent = true, desc = 'Toggle mouse' })

-- for tab navigation
vim.keymap.set('n', '<C-h>', ':tabprevious<CR>', { remap = false, silent = true, desc = 'Previous tab' }) -- <ctrl-h> for previous tab
vim.keymap.set('n', '<C-l>', ':tabnext<CR>', { remap = false, silent = true, desc = 'Next tab' }) -- <ctrl-l> for next tab

-- go back to the last position of a file
vim.api.nvim_exec([[
  autocmd BufRead * autocmd FileType <buffer> ++once
    \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
]], false)

-- highlight on yank
vim.api.nvim_create_augroup('etc', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', { group = 'etc', pattern = '*', callback = function() vim.highlight.on_yank({ on_visual = false }) end })

-- disable unneeded providers
vim.g['loaded_python_provider'] = 0
vim.g['loaded_perl_provider'] = 0

