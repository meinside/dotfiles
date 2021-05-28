" meinside's .vimrc file for vim
"
" created by meinside@gmail.com,
"
" last update: 2021.05.28.

set t_Co=256

""""""""""""""""""""""""""""""""
" settings for vim-plug (https://github.com/junegunn/vim-plug)
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
                \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Specify a directory for plugins
call plug#begin('~/.vim/plugged')

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
Plug 'Yggdroot/indentLine'
let g:indentLine_char = '⎸'
let g:indentLine_enabled = 0	" :IndentLinesToggle
Plug 'docunext/closetag.vim'
Plug 'tpope/vim-sleuth'
Plug 'luochen1990/rainbow'     " rainbow-colored parentheses
let g:rainbow_active = 1

" finder / locator
"
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' " :Files, :GFiles
Plug 'mtth/locate.vim' " :L xxx, :lclose, gl
Plug 'johngrib/vim-f-hangul'	" can use f/t/;/, on Hangul characters
Plug 'majutsushi/tagbar'    " For source file browsing ($ sudo apt-get install vim-nox ctags)
nmap <F8> :TagbarToggle<CR>

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

" linting

" gist (:Gist / :Gist -p / ...)
"
Plug 'mattn/webapi-vim'
Plug 'mattn/gist-vim'

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

" golang
"
Plug 'fatih/vim-go', {'for': 'go', 'do': ':GoInstallBinaries'}

" ruby
"
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }
Plug 'tpope/vim-endwise'

" rust
"
Plug 'rust-lang/rust.vim', { 'for': 'rust' }

" zig
"
Plug 'ziglang/zig.vim', { 'for': 'zig' }

" XXX - do not load following plugins on machines with low performance:
" (touch '~/.vimrc.lowperf' for it)
let lowperf=expand('~/.vimrc.lowperf')
if !filereadable(lowperf)

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

    " gitgutter
    "
    Plug 'airblade/vim-gitgutter'        " [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    let g:gitgutter_highlight_lines = 1
    let g:gitgutter_realtime = 0
    let g:gitgutter_eager = 0

    " clojure

    " golang
    "
    let g:go_fmt_command = "goimports"     " auto import dependencies
    let g:go_highlight_build_constraints = 1
    let g:go_highlight_extra_types = 1
    let g:go_highlight_fields = 1
    let g:go_highlight_functions = 1
    let g:go_highlight_methods = 1
    let g:go_highlight_operators = 1
    let g:go_highlight_structs = 1
    let g:go_highlight_types = 1
    let g:go_jump_to_error = 0
    let g:go_auto_sameids = 0
    let g:go_auto_type_info = 1
    let g:syntastic_go_checkers = ['go']	" XXX: 'golint' is too slow, use :GoLint manually.
    let g:syntastic_aggregate_errors = 1
    autocmd BufEnter *.go nmap <leader>ci  <Plug>(go-implements)    " \ci for implementations of given interface
    autocmd BufEnter *.go nmap <leader>cc  <Plug>(go-callers)    " \cc for callers of given function
    nmap <leader>cr <Plug>(coc-references)    " \cr for references of given type/function

    " rust
    "
    let g:rustfmt_autosave = 1 " :RustFmt

endif

"
""""""""

" Initialize plugin system
call plug#end()
"
""""""""""""""""""""""""""""""""

" linting
"
" * clojure:
" $ npm install -g clj-kondo
" $ go get -d github.com/candid82/joker && cd $GOPATH/src/github.com/candid82/joker && ./run.sh --version && go install
let g:ale_linters = {
    \ 'clojure': ['clj-kondo', 'joker']
    \}

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

