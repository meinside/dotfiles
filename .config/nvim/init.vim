" My .config/nvim/init.vim file for neovim (0.5+)
"
" created by meinside@gmail.com,
"
" created on : 2021.05.27.
" last update: 2021.05.28.

""""""""""""""""""""""""""""""""
" settings for vim-plug (https://github.com/junegunn/vim-plug)
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Specify a directory for plugins
call plug#begin('~/.local/share/nvim/plugged')

""""""""""""""""""""""""""""""""
"
" plugins

" colorschemes (https://github.com/rafi/awesome-vim-colorschemes)
"
Plug 'kristijanhusak/vim-hybrid-material'

" formatting
"
Plug 'jiangmiao/auto-pairs'
Plug 'tmhedberg/matchit'
Plug 'tpope/vim-surround' " cst'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-ragtag' " TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'Yggdroot/indentLine'
let g:indentLine_char = '▏'
Plug 'docunext/closetag.vim'
Plug 'tpope/vim-sleuth'
Plug 'luochen1990/rainbow'     " rainbow-colored parentheses
let g:rainbow_active = 1

" finder / locator
"
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'mtth/locate.vim' " :L xxx, :lclose, gl
Plug 'johngrib/vim-f-hangul'	" can use f/t/;/, on Hangul characters

" git
"
Plug 'junegunn/gv.vim' " :GV, :GV!, :GV?
Plug 'tpope/vim-fugitive'

" airline
"
Plug 'vim-airline/vim-airline'
let g:airline#extensions#ale#enabled = 1

" project management
"
" <ctrl-p> to start,
" <ctrl-j/k> to navigate files,
" <ctrl-t/v/x> to open a file in a new tab, vertical split, or horizontal split
"
Plug 'ctrlpvim/ctrlp.vim'
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_root_markers = ['pom.xml', 'go.mod']
nnoremap <C-h> :tabprevious<CR> " <ctrl-h> for previous tab,
nnoremap <C-l> :tabnext<CR> " <ctrl-l> for next tab,

" autocompletion
"
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/playground'
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/nvim-compe'

" linting
"
Plug 'dense-analysis/ale'

" show quickfix list
let g:ale_set_loclist = 0
let g:ale_open_list = 1
let g:ale_set_quickfix = 1

" lint only on save
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 0

" C-j, C-k for moving between errors
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" gist (:Gist / :Gist -p / ...)
"
Plug 'mattn/webapi-vim'
Plug 'mattn/gist-vim'

" gitgutter
"
Plug 'nvim-lua/plenary.nvim'
Plug 'lewis6991/gitsigns.nvim'        " [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo

" syntax checking
"
Plug 'vim-syntastic/syntastic'
set statusline+=%#warningmsg#
if exists('*SyntasticStatuslineFlag')
  set statusline+=%{SyntasticStatuslineFlag()}
endif
set statusline+=%*
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 0

" clojure
"
" $ go get github.com/cespare/goclj/cljfmt
Plug 'dmac/vim-cljfmt', { 'for': 'clojure' }
" >f, <f : move a form
" >e, <e : move an element
" >), <), >(, <( : move a parenthesis
" <I, >I : insert at the beginning or end of a form
" dsf : remove surroundings
" cse(, cse), cseb : surround an element with parenthesis
" cse[, cse] : surround an element with brackets
" cse{, cse} : surround an element with braces
Plug 'guns/vim-sexp', { 'for': 'clojure' }
Plug 'tpope/vim-sexp-mappings-for-regular-people', { 'for': 'clojure' }
" for auto completion: <C-x><C-o>
" for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
" for reloading everything: \rr
" for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
Plug 'Olical/conjure', { 'for': 'clojure', 'tag': 'v4.19.0' } "https://github.com/Olical/conjure/releases

" ruby
"
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
Plug 'tpope/vim-endwise'

" zig
"
Plug 'ziglang/zig.vim', { 'for': 'zig' }

"
""""""""

" Initialize plugin system
call plug#end()
"
""""""""""""""""""""""""""""""""


""""""""""""""""""""""""""""""""
" configuration with lua
"
lua << EOF
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
    nvim_lsp = true;
  };
}

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
  local col = vim.fn.col('.') - 1
  if col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
    return true
  else
    return false
  end
end

-- Use (s-)tab to:
--- move to prev/next item in completion menuone
--- jump to prev/next snippet's placeholder
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t "<C-n>"
  elseif check_back_space() then
    return t "<Tab>"
  else
    return vim.fn['compe#complete']()
  end
end
_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t "<C-p>"
  else
    return t "<S-Tab>"
  end
end

vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", {expr = true})
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", {expr = true})

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
  "clojure_lsp", -- clojure
  "gopls", -- golang
  "solargraph", -- ruby
  "rust_analyzer" -- rust
}
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end

-- other language servers for custom setup
require'lspconfig'.zls.setup{ -- zig
  cmd = { '/opt/zls/zig-out/bin/zls' };
  on_attach = on_attach;
}

------------------------
-- gitgutter
require('gitsigns').setup{}
EOF

" clojure
"
" $ brew install clojure-lsp/brew/clojure-lsp-native

" golang
"
" $ go install golang.org/x/tools/gopls@latest

" ruby
"
" $ gem install --user-install solargraph

" rust
"
" $ git clone https://github.com/rust-analyzer/rust-analyzer.git
" $ cd rust-analyzer/
" $ cargo xtask install --server
let g:rustfmt_autosave = 1 " :RustFmt


""""""""""""""""""""""""""""""""
" linting
"
" * clojure:
" $ npm install -g clj-kondo
" $ go get -d github.com/candid82/joker && cd $GOPATH/src/github.com/candid82/joker && ./run.sh --version && go install
let g:ale_linters = {
  \ 'clojure': ['clj-kondo', 'joker']
  \}


""""""""""""""""""""""""""""""""
" other settings

set mouse-=a	" not to enter visual mode when dragging text
let g:go_term_enabled = 1	" XXX - it needs to be set for 'delve' (2017.02.10.)

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

set nobackup	" do not keep a backup file, use versions instead
set history=50	" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set incsearch	" do incremental searching
set smartcase   " smart case insensitive search
set cindent
set ai
set smartindent
set nu
set ts=4
set sw=4
set sts=4
set fencs=ucs-bom,utf-8,korea
set termencoding=utf-8
set wildmenu   " visual autocomplete for command menu
set showbreak=↳
set breakindent

" file browser (netrw)
" :Ex, :Sex, :Vex
let g:netrw_liststyle = 3
let g:netrw_winsize = 30
" <F2> for vertical file browser
nmap <F2> :Vex <CR>

" Don't use Ex mode, use Q for formatting
map Q gq

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

" Only do this part when compiled with support for autocommands.
if has("autocmd")
  " Put these in an autocmd group, so that we can delete them easily.
  augroup vimrcEx
    au!

    " For all text files set 'textwidth' to 78 characters.
    autocmd FileType text setlocal textwidth=78

    " For html/javascript/css
    autocmd FileType htm,html,js,json set ai sw=2 ts=2 sts=2 et
    autocmd FileType css,scss set ai sw=2 ts=2 sts=2 et

    " For programming languages
    " Ruby
    autocmd FileType ruby,eruby,yaml set ai sw=2 ts=2 sts=2 et
    " Python
    autocmd FileType python set ai sw=2 ts=2 sts=2 et

    " When editing a file, always jump to the last known cursor position.
    " Don't do it when the position is invalid or when inside an event handler
    " (happens when dropping a file on gvim).
    autocmd BufReadPost *
      \ if line("'\"") > 0 && line("'\"") <= line("$") |
      \   exe "normal g`\"" |
      \ endif
  augroup END
else
  set autoindent		" always set autoindenting on
endif " has("autocmd")

" set colorscheme
"
let g:hybrid_transparent_background = 1
set background=dark
colorscheme hybrid_reverse

