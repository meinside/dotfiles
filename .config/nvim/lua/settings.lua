-- .config/nvim/lua/settings.lua
--
-- My neovim settings
--
-- NOTE: sourced from: `.config/nvim/init.lua`
--
-- last update: 2024.04.15.


------------------------------------------------
--
-- options

local opt = vim.opt
opt.autoindent = true
opt.backspace = { 'indent', 'eol', 'start' } -- allow backspacing over everything in insert mode
opt.breakindent = true
opt.cindent = true
opt.clipboard = opt.clipboard + 'unnamedplus' -- copy/paste to/from system clipboard
opt.colorcolumn = '80'
opt.cursorline = true -- highlight current line
opt.expandtab = true
opt.encoding = 'utf-8'
opt.guicursor = 'n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20'
opt.fileencodings = { 'ucs-bom', 'utf-8', 'korea' }
opt.foldmethod = 'indent' -- automatically fold on indent
opt.foldlevelstart = 20 -- but open all folds on file open
opt.history = 50
opt.incsearch = true
opt.mouse = ''
opt.number = true
opt.ruler = true
opt.shiftwidth = 4
opt.showbreak = '↳'
opt.showcmd = true
opt.smartcase = true
opt.smartindent = true
opt.softtabstop = 4
opt.splitbelow = true
opt.splitright = true
opt.tabstop = 4
opt.termguicolors = true
opt.updatetime = 1000 -- for shortening delay of CursorHold
opt.wildmenu = true
vim.o.signcolumn = 'number'

-- for toggling mouse: \mm
local mouse_enabled = false
vim.keymap.set('n', '<leader>mm', function()
  if mouse_enabled then
    opt.mouse = ''
    vim.notify 'Mouse disabled'
  else
    opt.mouse = 'nvi'
    vim.notify 'Mouse enabled'
  end
  mouse_enabled = not mouse_enabled
end, { remap = false, silent = true, desc = 'Toggle mouse' })

-- tab navigation
vim.keymap.set('n', '<C-h>', ':tabprevious<CR>', {
  remap = false,
  silent = true,
  desc = 'Previous tab',
}) -- <ctrl-h> for previous tab
vim.keymap.set('n', '<C-l>', ':tabnext<CR>', {
  remap = false,
  silent = true,
  desc = 'Next tab',
}) -- <ctrl-l> for next tab

-- highlight on yank
vim.api.nvim_create_augroup('etc', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  group = 'etc',
  pattern = '*',
  callback = function() vim.highlight.on_yank({ on_visual = false }) end,
})

-- disable unneeded providers
vim.g['loaded_perl_provider'] = 0

