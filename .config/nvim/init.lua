-- My .config/nvim/init.lua file for neovim (0.5+)
--
-- created by meinside@gmail.com,
--
-- created on : 2021.05.27.
-- last update: 2021.05.29.

------------------------------------------------
-- helpers
local cmd = vim.cmd  -- to execute Vim commands e.g. cmd('pwd')
local fn = vim.fn    -- to call Vim functions e.g. fn.bufnr()
local g = vim.g      -- a table to access global variables
local scopes = {o = vim.o, b = vim.bo, w = vim.wo}

local function opt(scope, key, value)
  scopes[scope][key] = value
  if scope ~= 'o' then scopes['o'][key] = value end
end

local function map(mode, lhs, rhs, opts)
  local options = {noremap = true}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end


------------------------------------------------
-- package manager
--
-- :PackerInstall / :PackerUpdate / ...
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
end

------------------------------------------------
-- plugin packages
--
local use = require('packer').use
require('packer').startup(function()
  use 'wbthomason/packer.nvim'

  -- colorschemes (https://github.com/rafi/awesome-vim-colorschemes)
  --
  use 'kristijanhusak/vim-hybrid-material'

  -- formatting
  --
  use 'jiangmiao/auto-pairs'
  use 'tmhedberg/matchit'
  use 'tpope/vim-surround' -- cst'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
  use 'tpope/vim-repeat'
  use 'tpope/vim-ragtag' -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  use 'lukas-reineke/indent-blankline.nvim'
  use 'Yggdroot/indentLine'
  g['indentLine_char'] = '▏'
  use 'docunext/closetag.vim'
  use 'tpope/vim-sleuth'
  use 'luochen1990/rainbow'
  g['rainbow_active'] = 1

  -- finder / locator
  --
  use 'nvim-lua/popup.nvim'
  use 'nvim-lua/plenary.nvim'
  use 'nvim-telescope/telescope.nvim'
  use 'mtth/locate.vim' -- :L xxx, :lclose, gl
  use 'johngrib/vim-f-hangul'	-- can use f/t/;/, on Hangul characters

  -- git
  --
  use 'junegunn/gv.vim' -- :GV, :GV!, :GV?
  use 'tpope/vim-fugitive'

  -- airline
  --
  use 'vim-airline/vim-airline'
  g['airline#extensions#tabline#enabled'] = 1
  g['airline#extensions#tabline#show_buffers'] = 0
  g['airline#extensions#tabline#tab_min_count'] = 2  -- show tabline only when there are >=2

  -- project management
  --
  -- <ctrl-p> to start,
  -- <ctrl-j/k> to navigate files,
  -- <ctrl-t/v/x> to open a file in a new tab, vertical split, or horizontal split
  --
  use 'ctrlpvim/ctrlp.vim'
  g['ctrlp_map'] = '<c-p>'
  g['ctrlp_cmd'] = 'CtrlP'
  g['ctrlp_working_path_mode'] = 'ra'
  g['ctrlp_root_markers'] = {'pom.xml', 'go.mod'}

  -- autocompletion
  --
  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
  use 'nvim-treesitter/playground'
  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/nvim-compe'
  vim.o.completeopt = 'menuone,noselect'

  -- linting
  -- TODO

  -- gist (:Gist / :Gist -p / ...)
  --
  use 'mattn/webapi-vim'
  use 'mattn/gist-vim'

  -- gitgutter
  --
  use 'lewis6991/gitsigns.nvim'	-- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo

  -- syntax checking
  --
  use 'vim-syntastic/syntastic'
  cmd [[set statusline+=%#warningmsg#]]
  cmd [[set statusline+=%{SyntasticStatuslineFlag()}]]
  cmd [[set statusline+=%*]]
  g['syntastic_always_populate_loc_list'] = 1
  g['syntastic_auto_loc_list'] = 1
  g['syntastic_check_on_open'] = 0
  g['syntastic_check_on_wq'] = 0

  -- ruby
  --
  use 'vim-ruby/vim-ruby'
  use 'tpope/vim-endwise'

  -- zig
  --
  use 'ziglang/zig.vim'


  ------------------------
  -- for language server configuration
  local nvim_lsp = require('lspconfig')

  -- default setup for language servers
  local on_attach = function(client, bufnr)
    local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

    --Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = { noremap=true, silent=true }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
    buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
    buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
    buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

  end

  -- language servers with default setup
  local servers = {
    -- clojure
    --
    -- $ brew install clojure-lsp/brew/clojure-lsp-native
    "clojure_lsp",

    -- golang
    --
    -- $ go install golang.org/x/tools/gopls@latest
    "gopls",

    -- ruby
    --
    -- $ gem install --user-install solargraph
    "solargraph",

    -- rust
    --
    -- $ git clone https://github.com/rust-analyzer/rust-analyzer.git && cd rust-analyzer/ && cargo xtask install --server
    "rust_analyzer"
  }
  for _, lsp in ipairs(servers) do
    nvim_lsp[lsp].setup { on_attach = on_attach }
  end

  -- other language servers for custom setup
  require'lspconfig'.zls.setup{ -- zig
    cmd = { '/opt/zls/zig-out/bin/zls' };
    on_attach = on_attach;
  }

  -- clojure
  --
  -- $ go get github.com/cespare/goclj/cljfmt
  use 'dmac/vim-cljfmt'
  -- >f, <f : move a form
  -- >e, <e : move an element
  -- >), <), >(, <( : move a parenthesis
  -- <I, >I : insert at the beginning or end of a form
  -- dsf : remove surroundings
  -- cse(, cse), cseb : surround an element with parenthesis
  -- cse[, cse] : surround an element with brackets
  -- cse{, cse} : surround an element with braces
  use 'guns/vim-sexp'
  use 'tpope/vim-sexp-mappings-for-regular-people'
  -- for auto completion: <C-x><C-o>
  -- for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
  -- for reloading everything: \rr
  -- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
  use {'Olical/conjure', tag = 'v4.19.0'} -- https://github.com/Olical/conjure/releases

  -- rust
  g['rustfmt_autosave'] = 1 -- :RustFmt

  ------------------------
  -- treesitter for syntax highlighting
  require'nvim-treesitter.configs'.setup {
    ensure_installed = {'go', 'python', 'ruby', 'rust', 'zig'};
    highlight = {enable = true};
  }

  ------------------------
  -- compe for autocompletion
  require'compe'.setup {
    enabled = true;
    autocomplete = true;
    debug = false;
    min_length = 1;
    preselect = 'enable';
    throttle_time = 80;
    source_timeout = 200;
    incomplete_delay = 400;
    max_abbr_width = 100;
    max_kind_width = 100;
    max_menu_width = 100;
    documentation = true;

    source = {
      path = true;
      buffer = true;
      calc = true;
      nvim_lsp = true;
      nvim_lua = true;
    };
  }

  local t = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
  end

  local check_back_space = function()
    local col = fn.col('.') - 1
    if col == 0 or fn.getline('.'):sub(col, col):match('%s') then
      return true
    else
      return false
    end
  end

  -- Use (s-)tab to:
  --- move to prev/next item in completion menuone
  --- jump to prev/next snippet's placeholder
  _G.tab_complete = function()
    if fn.pumvisible() == 1 then
      return t "<C-n>"
    elseif check_back_space() then
      return t "<Tab>"
    else
      return fn['compe#complete']()
    end
  end
  _G.s_tab_complete = function()
    if fn.pumvisible() == 1 then
      return t "<C-p>"
    else
      return t "<S-Tab>"
    end
  end

  vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
  vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
  vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
  vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})

  ------------------------------------------------
  -- linting
  -- TODO

  ------------------------
  -- gitgutter
  require('gitsigns').setup{}

end)

------------------------------------------------
-- other settings

g['go_term_enabled'] = 1  -- XXX - it needs to be set for 'delve' (2017.02.10.)
cmd [[set mouse-=a]]  -- not to enter visual mode when dragging text
cmd [[set backspace=indent,eol,start]]  -- allow backspacing over everything in insert mode
cmd [[set nobackup]]  -- do not keep a backup file, use versions instead
cmd [[set history=50]]  -- keep 50 lines of command line history
cmd [[set ruler]]  -- show the cursor position all the time
cmd [[set showcmd]]  -- display incomplete commands
cmd [[set incsearch]]  -- do incremental searching
cmd [[set smartcase]]  -- smart case insensitive search
cmd [[set cindent]]
cmd [[set ai]]
cmd [[set smartindent]]
cmd [[set nu]]
cmd [[set ts=4]]
cmd [[set sw=4]]
cmd [[set sts=4]]
cmd [[set fencs=ucs-bom,utf-8,korea]]
cmd [[set termencoding=utf-8]]
cmd [[set showbreak=↳]]
cmd [[set wildmenu]]
cmd [[set breakindent]]

map('n', '<C-h>', ':tabprevious<CR>') -- <ctrl-h> for previous tab,
map('n', '<C-l>', ':tabnext<CR>') -- <ctrl-l> for next tab,

-- vim autocmds (not yet supported)
vim.api.nvim_exec([[
  augroup vimrcEx
    au!

    " For all text files set 'textwidth' to 78 characters.
    autocmd FileType text setlocal textwidth=78

    " html/javascript/css
    autocmd FileType htm,html,js,json set ai sw=2 ts=2 sts=2 et
    autocmd FileType css,scss set ai sw=2 ts=2 sts=2 et

    " Ruby
    autocmd FileType ruby,eruby,yaml set ai sw=2 ts=2 sts=2 et

    " Python
    autocmd FileType python set ai sw=2 ts=2 sts=2 et

    " When editing a file, always jump to the last known cursor position.
    " Don't do it when the position is invalid or when inside an event handler
    " (happens when dropping a file on gvim).
    autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g`\"" | endif

    " highlight yanked text
    autocmd TextYankPost * lua vim.highlight.on_yank {on_visual = false}
  augroup end
]], false)

-- set colorscheme
--
g['hybrid_transparent_background'] = 1
cmd [[set background=dark]]
cmd [[colorscheme hybrid_reverse]]

