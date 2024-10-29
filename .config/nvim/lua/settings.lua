-- .config/nvim/lua/settings.lua
--
-- My neovim settings
--
-- NOTE: sourced from: `.config/nvim/init.lua`
--
-- last update: 2024.10.29.


-- use new loader with byte-compilation cache
if vim.loader then
  vim.loader.enable()
end


------------------------------------------------
--
-- options

local opt = vim.opt
opt.autoindent = true
opt.backspace = { 'indent', 'eol', 'start' } -- allow backspacing over everything in insert mode
opt.breakindent = true
opt.cindent = true
opt.clipboard = opt.clipboard + 'unnamedplus' -- copy/paste to/from system clipboard
opt.colorcolumn = ''
opt.conceallevel = 2 -- render hyperlinks in markdown
opt.cursorline = true -- highlight current line
opt.expandtab = true
opt.encoding = 'utf-8'
opt.guicursor = 'n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20'
-- FIXME: not working in mosh (https://github.com/mobile-shell/mosh/issues/352)
vim.api.nvim_create_autocmd({ 'VimLeave' }, { callback = function() opt.guicursor='a:ver1-blinkon1' end })  -- NOTE: for fixing cursor in tmux
opt.fileencodings = { 'ucs-bom', 'utf-8', 'korea' }
opt.foldmethod = 'expr'
opt.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
opt.foldcolumn = '0'
opt.foldtext = ''
opt.foldlevelstart = 20 -- but open all folds on file open
opt.history = 50
opt.ignorecase = true
opt.inccommand = 'split'
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

-- for toggling color column: `\tc`
vim.keymap.set('n', '<leader>tc', function()
  local value = vim.api.nvim_get_option_value('colorcolumn', {})
  if value == '' then
    vim.api.nvim_set_option_value('colorcolumn', '79', {})
    vim.notify 'Color column enabled'
  else
    vim.api.nvim_set_option_value('colorcolumn', '', {})
    vim.notify 'Color column disabled'
  end
end, { remap = false, silent = true, desc = 'color column: Toggle' })

-- for toggling mouse: `\mm`
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
end, { remap = false, silent = true, desc = 'mouse: Toggle' })

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

-- keep windows euqally sized
vim.api.nvim_create_augroup('Random', {clear = true})
vim.api.nvim_create_autocmd('VimResized', {
    group = 'Random',
    desc = 'Keep windows equally resized',
    command = 'tabdo wincmd ='
})
vim.api.nvim_create_autocmd('TermOpen', {
    group = 'Random',
    command = 'setlocal nonumber norelativenumber signcolumn=no'
})

-- disable unneeded providers
vim.g['loaded_perl_provider'] = 0

