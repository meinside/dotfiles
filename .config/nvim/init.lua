-- My .config/nvim/init.lua file for neovim (0.5+)
--
-- created by meinside@gmail.com,
--
-- created on : 2021.05.27.
-- last update: 2021.08.04.

------------------------------------------------
-- helpers
--

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

-- default setup for language servers
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  --buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  --buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  --buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  --buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  --buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', 'gt', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  --buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  --buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  --buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  --buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  --buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  --buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  --buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap('n', '<leader>ll', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  --buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
  buf_set_keymap("n", "<leader>fo", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

  -- LSP Enable diagnostics
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = true,
    underline = true,
    signs = true,
    update_in_insert = false
  })

  -- Send diagnostics to quickfix list
  do
    local method = "textDocument/publishDiagnostics"
    local default_handler = vim.lsp.handlers[method]
    vim.lsp.handlers[method] = function(err, method, result, client_id, bufnr, config)
      default_handler(err, method, result, client_id, bufnr, config)
      local diagnostics = vim.lsp.diagnostic.get_all()
      local qflist = {}
      for bufnr, diagnostic in pairs(diagnostics) do
        for _, d in ipairs(diagnostic) do
          d.bufnr = bufnr
          d.lnum = d.range.start.line + 1
          d.col = d.range.start.character + 1
          d.text = d.message
          table.insert(qflist, d)
        end
      end
      vim.lsp.util.set_qflist(qflist)
    end
  end

  -- auto formatting on save
  if client.resolved_capabilities.document_formatting then
    vim.api.nvim_exec([[
      autocmd BufWritePre <buffer> lua vim.lsp.buf.formatting_sync()
    ]], false)
  end
end

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

-- split string
function split(s, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    return fields
  end

-- execute given command and return the output with exit status
local function os_execute(cmd)
  -- for Lua 5.2+
  --local fileHandle = assert(io.popen(cmd, 'r'))
  -- for Lua 5.1 or LuaJit 2.1.0
  local fileHandle = assert(io.popen(cmd .. ';echo $?', 'r'))

  local commandOutput = assert(fileHandle:read('*a'))
  local returnTable = {fileHandle:close()}

  -- for Lua 5.2+
  --return commandOutput, returnTable[3]
  -- for Lua 5.1 or LuaJit 2.1.0
  local lines = split(commandOutput, '\n')
  local exit = lines[#lines]
  return commandOutput:gsub(exit, ''), tonumber(exit)
end

-- check if current process is connected through mosh
-- FIXME: mosh 1.3.2 still not support 24bit-colors
local function mosh_connected()
  if os.getenv('TMUX') then
    pid, _ = os_execute("tmux list-clients -t \"`tmux display-message -p '#S'`\" -F '#{client_pid}'")
  else
    pid, _ = os_execute('echo $$')
  end

  _, exit = os_execute(string.format("pstree -ps %s | grep mosh-server", pid:gsub('\n', '')))

  return exit == 0
end

--
------------------------------------------------


------------------------------------------------
-- plugins
--
-- :PackerInstall / :PackerUpdate / :PackerSync / ...
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
end
local use = require('packer').use
require('packer').startup(function()
  use 'wbthomason/packer.nvim'


  -- startup time
  use 'dstein64/vim-startuptime'  -- :StartupTime


  -- colorschemes (https://github.com/rockerBOO/awesome-neovim#colorscheme)
  use 'Iron-E/nvim-soluarized'
  use 'marko-cerovac/material.nvim'


  -- formatting
  use 'tpope/vim-surround' -- cst'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
  use 'tpope/vim-ragtag' -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  use 'lukas-reineke/indent-blankline.nvim'
  g['indentLine_char'] = '▏'
  use 'tpope/vim-sleuth'
  use 'luochen1990/rainbow'
  g['rainbow_active'] = 1


  -- finder / locator
  use 'mtth/locate.vim' -- :L [query], :lclose, gl
  use 'johngrib/vim-f-hangul'	-- can use f/t/;/, on Hangul characters
  use {
    'nvim-telescope/telescope.nvim', -- :Telescope <action>
    requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
  }
  map('n', '<leader>fb', '<cmd>lua require("telescope.builtin").file_browser()<CR>') -- \fb for `file_browser`
  map('n', '<leader>ff', '<cmd>lua require("telescope.builtin").find_files()<CR>') -- \ff for `find_files`
  map('n', '<leader>gc', '<cmd>lua require("telescope.builtin").git_commits()<CR>') -- \gc for `git_commits`
  map('n', '<leader>qf', '<cmd>lua require("telescope.builtin").quickfix()<CR>') -- \qf for `quickfix`
  map('n', '<leader>lr', '<cmd>lua require("telescope.builtin").lsp_references()<CR>') -- \lr for `lsp_references`
  map('n', '<leader>li', '<cmd>lua require("telescope.builtin").lsp_implementations()<CR>') -- \li for `lsp_implementations`
  map('n', '<leader>ld', '<cmd>lua require("telescope.builtin").lsp_definitions()<CR>') -- \ld for `lsp_definitions`


  -- git
  use 'junegunn/gv.vim' -- :GV, :GV!, :GV?
  use 'tpope/vim-fugitive'
  -- git blamer
  use 'APZelos/blamer.nvim' -- :BlamerToggle, :BlamerShow, :BlamerHide
  g['blamer_date_format'] = '%Y-%m-%d'
  g['blamer_prefix'] = ' > '
  vim.api.nvim_exec([[
    autocmd BufRead * highlight Blamer ctermfg=Yellow ctermbg=none
  ]], false)
  -- git signs
  use {'lewis6991/gitsigns.nvim', -- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    requires = {'nvim-lua/plenary.nvim'},
    config = function()
      require('gitsigns').setup()
    end
  }
  vim.api.nvim_exec([[
    autocmd BufRead * highlight GitSignsAdd ctermfg=Green ctermbg=none
    autocmd BufRead * highlight GitSignsChange ctermfg=Blue ctermbg=none
    autocmd BufRead * highlight GitSignsDelete ctermfg=Red ctermbg=none
  ]], false)
  -- gist (:Gist / :Gist -p / ...)
  use 'mattn/webapi-vim'
  use 'mattn/gist-vim'


  -- auto close
  use 'cohama/lexima.vim'
  g['lexima_no_default_rules'] = true


  -- statusline
  use {
    'hoob3rt/lualine.nvim',
    requires = {'kyazdani42/nvim-web-devicons', opt = true}
  }


  -- lsp
  use 'neovim/nvim-lspconfig'
  use 'ray-x/lsp_signature.nvim'
  use 'glepnir/lspsaga.nvim'


  -- autocompletion
  use 'hrsh7th/nvim-compe'
  vim.o.completeopt = 'menuone,noselect'


  -- quick fix list
  --
  -- :Trouble [mode], :TroubleCloe, :TroubleToggle, :TroubleRefresh
  use {
    'folke/trouble.nvim',
    requires = 'kyazdani42/nvim-web-devicons',
    config = function()
      require'trouble'.setup {
        fold_open = 'v', -- icon used for open folds
        fold_closed = '>', -- icon used for closed folds
        indent_lines = false, -- add an indent guide below the fold icons
        signs = {
          -- icons / text used for a diagnostic
          error = 'error',
          warning = 'warn',
          hint = 'hint',
          information = 'info'
        },
        use_lsp_diagnostic_signs = true
      }
    end
  }


  -- snippets
  use 'hrsh7th/vim-vsnip'
  use 'kitagry/vs-snippets' -- various language snippets
  vim.api.nvim_exec([[
    " Ctrl + L for expand, or jump to next element
    imap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
    smap <expr> <C-l>   vsnip#available(1)  ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
    " Jump forward or backward
    imap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
    smap <expr> <Tab>   vsnip#jumpable(1)   ? '<Plug>(vsnip-jump-next)'      : '<Tab>'
    imap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
    smap <expr> <S-Tab> vsnip#jumpable(-1)  ? '<Plug>(vsnip-jump-prev)'      : '<S-Tab>'
  ]], false)


  -- syntax highlighting
  use {'nvim-treesitter/nvim-treesitter', run = ':TSUpdate'}
  use 'nvim-treesitter/playground'


  -- syntax checking
  use 'neomake/neomake'
  g['neomake_open_list'] = 2


  -- tab navigation
  map('n', '<C-h>', ':tabprevious<CR>') -- <ctrl-h> for previous tab,
  map('n', '<C-l>', ':tabnext<CR>') -- <ctrl-l> for next tab,


  -- clojure
  --
  use 'dmac/vim-cljfmt' -- $ go install github.com/cespare/goclj/cljfmt
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
  use {'Olical/conjure', tag = 'v4.21.0'} -- https://github.com/Olical/conjure/releases


  -- haskell
  --
  use 'neovimhaskell/haskell-vim'
  use 'itchyny/vim-haskell-indent'
  if vim.fn.executable("stylish-haskell") == 1 then
    use 'alx741/vim-stylishask'
  end


  -- go
  --
  use 'sebdah/vim-delve'  -- :DlvXXX


  -- ruby
  --
  use 'vim-ruby/vim-ruby'


  -- rust
  --
  use 'rust-lang/rust.vim'


  -- zig
  --
  use 'ziglang/zig.vim'


  -- ↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑ non-lazy `require` not allowed above ↑ ↑ ↑ ↑ ↑ ↑ ↑ ↑
  -- ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ `use` not allowed below ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓


  -- lsp settings
  local nvim_lsp = require('lspconfig')
  local lsp_servers = { -- language servers with default setup
    "clojure_lsp",  -- $ brew install clojure-lsp/brew/clojure-lsp-native
    "gopls",  -- $ go install golang.org/x/tools/gopls@latest
    "solargraph",  -- $ gem install --user-install solargraph
    "rust_analyzer"  -- $ git clone https://github.com/rust-analyzer/rust-analyzer.git && cd rust-analyzer/ && cargo xtask install --server
  }
  for _, lsp in ipairs(lsp_servers) do
    nvim_lsp[lsp].setup {
      on_attach = on_attach;
    }
  end
  -- other language servers for custom setup
  -- (haskell)
  nvim_lsp['hls'].setup {
    cmd = { 'haskell-language-server-wrapper', '--lsp' };
    on_attach = on_attach;
  }
  -- (zig)
  nvim_lsp['zls'].setup {
    cmd = { '/opt/zls/zig-out/bin/zls' };
    on_attach = on_attach;
  }
  -- lsp_signature
  require'lsp_signature'.on_attach({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = "single"
    }
  })
  -- lspsaga
  require'lspsaga'.init_lsp_saga {
    finder_action_keys = {
      open = '<CR>',
      vsplit = 'v',
      split = 's',
      quit = '<ESC>',
      scroll_down = '<C-f>',
      scroll_up = '<C-b>',
    },
    code_action_keys = {
      quit = '<ESC>',
      exec = '<CR>',
    },
    rename_action_keys = {
      quit = '<ESC>',
      exec = '<CR>',
    },
  }
  vim.api.nvim_exec([[
    nnoremap <silent> gh :Lspsaga lsp_finder<CR>
    nnoremap <silent><leader>ca :Lspsaga code_action<CR>
    nnoremap <silent><leader>rn :Lspsaga rename<CR>
    nnoremap <silent> [d :Lspsaga diagnostic_jump_next<CR>
    nnoremap <silent> ]d :Lspsaga diagnostic_jump_prev<CR>

    autocmd CursorHold * :Lspsaga show_line_diagnostics
  ]], false)


  -- lexima settings
  cmd [[call lexima#set_default_rules()]]


  -- lualine settings
  require'lualine'.setup {
    options = {
      theme = 'seoul256',
    },
    extensions = {'quickfix'}
  }


  -- neomake settings
  vim.api.nvim_exec([[call neomake#configure#automake('nrwi', 500)]], false)


  -- treesitter settings
  require'nvim-treesitter.configs'.setup {
    ensure_installed = {'go', 'haskell', 'python', 'ruby', 'rust', 'zig'};
    highlight = {enable = true};
  }


  -- compe settings
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
      vsnip = true;
      nvim_lsp = true;
      nvim_lua = true;
    };
  }
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
  map('i', '<Tab>', 'v:lua.tab_complete()', {expr = true})
  map('s', '<Tab>', 'v:lua.tab_complete()', {expr = true})
  map('i', '<S-Tab>', 'v:lua.s_tab_complete()', {expr = true})
  map('s', '<S-Tab>', 'v:lua.s_tab_complete()', {expr = true})
  vim.api.nvim_exec([[
    let g:lexima_no_default_rules = v:true
    call lexima#set_default_rules()
    inoremap <silent><expr> <C-Space> compe#complete()
    inoremap <silent><expr> <CR>      compe#confirm(lexima#expand('<LT>CR>', 'i'))
    inoremap <silent><expr> <C-e>     compe#close('<C-e>')
    inoremap <silent><expr> <C-f>     compe#scroll({ 'delta': +4 })
    inoremap <silent><expr> <C-d>     compe#scroll({ 'delta': -4 })
  ]], false)


  -- color scheme
  -- FIXME: mosh 1.3.2 still not support 24bit-colors
  if mosh_connected() then
    --print "mosh connected!"

    -- 8bit-colors colorscheme
    vim.o.background = 'dark'
    cmd [[colorscheme soluarized]]
  else
    --print "mosh not connected!"

    vim.o.termguicolors = true

    -- 24bit-colors colorscheme
    vim.g.material_style = 'darker'
    vim.g.material_disable_background = true
    require('material').set()
  end

end)

--
------------------------------------------------

------------------------------------------------
-- other common settings
--
local opt = vim.opt
opt.mouse = opt.mouse - { 'a' } -- not to enter visual mode when dragging text
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
vim.api.nvim_exec([[
  augroup files
    au!

    autocmd FileType text setlocal textwidth=78

    autocmd FileType htm,html,js,json set ai sw=2 ts=2 sts=2 et
    autocmd FileType css,scss set ai sw=2 ts=2 sts=2 et
    autocmd FileType ruby,eruby,yaml set ai sw=2 ts=2 sts=2 et
    autocmd FileType python set ai sw=2 ts=2 sts=2 et

    autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g`\"" | endif

    autocmd TextYankPost * lua vim.highlight.on_yank {on_visual = false}
  augroup end
]], false)

--
------------------------------------------------

