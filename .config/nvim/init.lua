-- My .config/nvim/init.lua file for neovim 0.7+
--
-- created by meinside@gmail.com,
--
-- created on : 2021.05.27.
-- last update: 2022.04.26.

local fn = vim.fn    -- to call Vim functions e.g. fn.bufnr()
local g = vim.g      -- a table to access global variables

local function map(mode, lhs, rhs, opts)
  local options = {noremap = true}
  if opts then options = vim.tbl_extend('force', options, opts) end
  vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- default setup for language servers
local on_attach_lsp = function(client, bufnr)
  -- Enable completion triggered by <c-x><c-o>
  vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  -- Mappings.
  local opts = { remap = false, silent = true }

  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  --vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
  --vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
  --vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
  --vim.keymap.set('n', '<space>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, opts)
  vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  --vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', '<leader>ca', '<cmd>CodeActionMenu<CR>', opts)
  --vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  vim.keymap.set('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
  vim.keymap.set('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
  vim.keymap.set('n', '<leader>ll', '<cmd>lua vim.diagnostic.setloclist()<CR>', opts)
  vim.keymap.set('n', '<leader>fo', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)

  -- diagnostics configuration
  vim.diagnostic.config({ underline = false, virtual_text = false, signs = true, severity_sort = true, update_in_insert = false })
  fn.sign_define('DiagnosticSignError', { text = '✗', texthl = 'DiagnosticSignError' })
  fn.sign_define('DiagnosticSignWarn', { text = '!', texthl = 'DiagnosticSignWarn' })
  fn.sign_define('DiagnosticSignInformation', { text = '', texthl = 'DiagnosticSignInfo' })
  fn.sign_define('DiagnosticSignHint', { text = '', texthl = 'DiagnosticSignHint' })

  -- auto formatting on save
  if client.resolved_capabilities.document_formatting then -- TODO: remove this when lspconfig is updated
  --if client.server_capabilities.document_formatting then
    vim.api.nvim_create_autocmd('BufWritePre', {callback = function() vim.lsp.buf.formatting_sync() end})
  end

  -- highlight current variable
  if client.resolved_capabilities.document_highlight then -- TODO: remove this when lspconfig is updated
  --if client.server_capabilities.document_highlight then
    vim.api.nvim_set_hl(0, 'LspReferenceRead', {link = 'Visual'})
    vim.api.nvim_set_hl(0, 'LspReferenceText', {link = 'Visual'})
    vim.api.nvim_set_hl(0, 'LspReferenceWrite', {link = 'Visual'})
    vim.api.nvim_create_augroup('lsp_document_highlight', {clear = true})
    vim.api.nvim_create_autocmd('CursorHold', {group = 'lsp_document_highlight', callback = function() vim.lsp.buf.document_highlight() end})
    vim.api.nvim_create_autocmd('CursorMoved', {group = 'lsp_document_highlight', callback = function() vim.lsp.buf.clear_references() end})
  end
end


------------------------------------------------
-- plugins
--
-- :PackerInstall / :PackerUpdate / :PackerSync / ...
local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  fn.execute('!git clone https://github.com/wbthomason/packer.nvim '..install_path)
end
local use = require('packer').use
require('packer').startup({function()
  use 'wbthomason/packer.nvim'


  -- startup time
  use 'dstein64/vim-startuptime'  -- :StartupTime


  -- colorschemes (https://github.com/rockerBOO/awesome-neovim#colorscheme)
  use {
    'projekt0n/github-nvim-theme',
    config = function() require'github-theme'.setup {theme_style = 'dark', transparent = true} end
  }


  -- dim inactive window
  use 'blueyed/vim-diminactive'


  -- show key bindings
  use {
    'folke/which-key.nvim',
    config = function() require("which-key").setup {} end
  }


  -- markdown preview
  use {'iamcco/markdown-preview.nvim', run = 'cd app && npm install'}


  -- fold and preview (zc for closing, zo for opening / zM for closing all, zR opening all)
  use {
    'anuvyklack/pretty-fold.nvim',
    config = function()
      require('pretty-fold').setup {
        keep_indentation = false,
        fill_char = '━',
        sections = {
          left = { '━ ', function() return string.rep('*', vim.v.foldlevel) end, ' ━┫', 'content', '┣' },
          right = { '┫ ', 'number_of_folded_lines', ': ', 'percentage', ' ┣━━' }
        }
      }
      require('pretty-fold.preview').setup_keybinding('l') -- will float preview when pressing 'l' on folds
    end
  }


  -- formatting
  use 'tpope/vim-surround' -- cst'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
  use 'tpope/vim-ragtag' -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  use {
    'lukas-reineke/indent-blankline.nvim',
    config = function()
      require'indent_blankline'.setup {
        char = '▏',
        buftype_exclude = {'terminal'},
        show_current_context = true,
        show_current_context_start = true,
      }
    end
  }
  use 'tpope/vim-sleuth'
  use 'p00f/nvim-ts-rainbow'


  -- finder / locator
  use 'mtth/locate.vim' -- :L [query], :lclose, gl
  use 'johngrib/vim-f-hangul'	-- can use f/t/;/, on Hangul characters
  use {
    'nvim-telescope/telescope.nvim',
    requires = {{'nvim-lua/popup.nvim'}, {'nvim-lua/plenary.nvim'}}
  }
  map('n', '<leader>ff', '<cmd>Telescope find_files<CR>')
  map('n', '<leader>gc', '<cmd>Telescope git_commits<CR>')
  map('n', '<leader>qf', '<cmd>Telescope quickfix<CR>')
  map('n', '<leader>lr', '<cmd>Telescope lsp_references<CR>')
  map('n', '<leader>li', '<cmd>Telescope lsp_implementations<CR>')
  map('n', '<leader>ld', '<cmd>Telescope lsp_definitions<CR>')


  -- git
  use 'junegunn/gv.vim' -- :GV, :GV!, :GV?
  use 'tpope/vim-fugitive'
  -- git signs (for blame: :Gitsigns toggle_current_line_blame)
  use {
    'lewis6991/gitsigns.nvim', -- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    requires = {'nvim-lua/plenary.nvim'},
    config = function()
      require('gitsigns').setup({
        numhl = true,
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function m(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          m('n', ']c', "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'", {expr=true})
          m('n', '[c', "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'", {expr=true})

          -- Actions
          m({'n', 'v'}, '<leader>hs', ':Gitsigns stage_hunk<CR>')
          m({'n', 'v'}, '<leader>hr', ':Gitsigns reset_hunk<CR>')
          m('n', '<leader>hS', gs.stage_buffer)
          m('n', '<leader>hu', gs.undo_stage_hunk)
          m('n', '<leader>hR', gs.reset_buffer)
          m('n', '<leader>hp', gs.preview_hunk)
          m('n', '<leader>hb', function() gs.blame_line{full=true} end)
          m('n', '<leader>tb', gs.toggle_current_line_blame)
          m('n', '<leader>hd', gs.diffthis)
          m('n', '<leader>hD', function() gs.diffthis('~') end)
          m('n', '<leader>td', gs.toggle_deleted)

          -- Text object
          m({'o', 'x'}, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        end
      })
    end
  }
  -- gist (:Gist / :Gist -p / ...)
  use 'mattn/webapi-vim'
  use 'mattn/gist-vim'


  -- statusline
  use {
    'nvim-lualine/lualine.nvim',
    after = 'github-nvim-theme',
    requires = {'kyazdani42/nvim-web-devicons', opt = true},
    config = function()
      require'lualine'.setup {
        options = {theme = 'auto', globalstatus = true},
        extensions = {'quickfix'}}
    end
  }


  -- auto pair/close
  use {
    'windwp/nvim-autopairs',
    config = function() require'nvim-autopairs'.setup{} end
  }


  -- lsp
  use 'neovim/nvim-lspconfig'
  use {
    'ray-x/lsp_signature.nvim',
    config = function() require'lsp_signature'.setup {bind = true, handler_opts = {border = 'single'}} end
  }
  use {
    'onsails/lspkind-nvim',
    config = function()
      -- (gray)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrDeprecated', {bg = 'NONE', fg = '#808080', strikethrough = true})
      -- (blue)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatch', {bg = 'NONE', fg = '#569CD6'})
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatchFuzzy', {bg = 'NONE', fg = '#569CD6'})
      -- (light blue)
      vim.api.nvim_set_hl(0, 'CmpItemKindVariable', {bg = 'NONE', fg = '#9CDCFE'})
      vim.api.nvim_set_hl(0, 'CmpItemKindInterface', {bg = 'NONE', fg = '#9CDCFE'})
      vim.api.nvim_set_hl(0, 'CmpItemKindText', {bg = 'NONE', fg = '#9CDCFE'})
      -- (pink)
      vim.api.nvim_set_hl(0, 'CmpItemKindFunction', {bg = 'NONE', fg = '#C586C0'})
      vim.api.nvim_set_hl(0, 'CmpItemKindMethod', {bg = 'NONE', fg = '#C586C0'})
      -- (front)
      vim.api.nvim_set_hl(0, 'CmpItemKindKeyword', {bg = 'NONE', fg = '#D4D4D4'})
      vim.api.nvim_set_hl(0, 'CmpItemKindProperty', {bg = 'NONE', fg = '#D4D4D4'})
      vim.api.nvim_set_hl(0, 'CmpItemKindUnit', {bg = 'NONE', fg = '#D4D4D4'})
    end
  }


  -- snippets
  use 'L3MON4D3/LuaSnip'
  use 'rafamadriz/friendly-snippets'


  -- autocompletion
  use {
    'hrsh7th/nvim-cmp',
    requires = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-nvim-lua',
      'saadparwaiz1/cmp_luasnip',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-calc',
    },
    config = function ()
      local cmp = require'cmp'
      local luasnip = require'luasnip'
      local lspkind = require'lspkind'

      cmp.setup({
        completion = { completeopt = 'menu,menuone,noselect' },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = {
          ['<Up>'] = cmp.mapping.select_prev_item(),
          ['<Down>'] = cmp.mapping.select_next_item(),
          ['<C-b>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
          ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
          ['<C-y>'] = cmp.config.disable,
          ['<C-e>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close(),
          }),
          ['<CR>'] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          },
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() == 1 then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() == 1 then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'buffer' },
          { name = 'nvim_lua' },
          { name = 'luasnip' },
          { name = 'path' },
          { name = 'calc' },
        },
        formatting = { format = lspkind.cmp_format() },
      })

      -- setup autopairs
      local cmp_autopairs = require('nvim-autopairs.completion.cmp')
      cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())

      -- load snippets
      require'luasnip/loaders/from_vscode'.lazy_load()
    end
  }


  -- quick fix list (:Trouble [mode], :TroubleClose, :TroubleToggle, :TroubleRefresh)
  use {
    'folke/trouble.nvim',
    requires = 'kyazdani42/nvim-web-devicons',
    config = function()
      require'trouble'.setup {
        fold_open = 'v',
        fold_closed = '>',
        indent_lines = false,
        signs = {
          error = 'error',
          warning = 'warn',
          hint = 'hint',
          information = 'info'
        },
        use_diagnostic_signs = true,
      }
    end
  }


  -- syntax highlighting and rainbow parenthesis
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require'nvim-treesitter.configs'.setup {
        ensure_installed = {
          'bash',
          'c', 'clojure', 'cmake', 'comment', 'cpp', 'css',
          'dart', 'dockerfile',
          'fennel',
          'go', 'gomod', 'gowork',
          'haskell', 'html',
          'java', 'javascript', 'jsdoc', 'json', 'json5', 'jsonc', 'julia',
          'kotlin',
          'llvm', 'lua',
          'make', 'markdown',
          'perl', 'php', 'python',
          'query',
          'r', 'ruby', 'rust',
          --'swift',
          'toml', 'typescript',
          'yaml',
          'zig',
        },
        highlight = {enable = true},
        rainbow = {enable = true, extended_mode = true},
      }
    end
  }


  -- syntax checking
  use 'neomake/neomake'


  -- code action: `\ca`
  use {'weilbith/nvim-code-action-menu', cmd = 'CodeActionMenu'}


  -- debug adapter
  use {'rcarriga/nvim-dap-ui', requires = {'mfussenegger/nvim-dap'}}
  use {
    'theHamsta/nvim-dap-virtual-text',
    config = function() require'nvim-dap-virtual-text'.setup {} end
  }


  -- bash
  use 'bash-lsp/bash-language-server'


  -- clojure
  use {'dmac/vim-cljfmt', ft = {'clojure'}} -- $ go install github.com/cespare/goclj/cljfmt
  -- for auto completion: <C-x><C-o>
  -- for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
  -- for reloading everything: \rr
  -- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
  use {'Olical/conjure', ft = {'clojure', 'fennel'}}


  -- fennel
  use {'bakpakin/fennel.vim', ft = {'fennel'}}


  -- go
  use {
    'ray-x/go.nvim',
    config = function()
      require'go'.setup {
        gofmt = 'gopls',
        lsp_codelens = false, -- TODO: remove this when gopls' codelens works
      }
      vim.api.nvim_create_autocmd('BufWritePre', {pattern = '*.go', callback = require('go.format').goimport})
    end
  }


  -- haskell
  use {'neovimhaskell/haskell-vim', ft = {'haskell'}}
  use {'itchyny/vim-haskell-indent', ft = {'haskell'}}
  if fn.executable('stylish-haskell') == 1 then
    use {'alx741/vim-stylishask', ft = {'haskell'}}
  end


  -- julia
  use 'JuliaEditorSupport/julia-vim'


  -- lispy languages
  --
  -- >f, <f : move a form
  -- >e, <e : move an element
  -- >), <), >(, <( : move a parenthesis
  -- <I, >I : insert at the beginning or end of a form
  -- dsf : remove surroundings
  -- cse(, cse), cseb : surround an element with parenthesis
  -- cse[, cse] : surround an element with brackets
  -- cse{, cse} : surround an element with braces
  use {'guns/vim-sexp', ft = {'clojure', 'fennel'}}
  g['sexp_enable_insert_mode_mappings'] = 0 -- '"' key works weirdly in insert mode
  g['sexp_filetypes'] = 'clojure,fennel'
  use {'tpope/vim-sexp-mappings-for-regular-people', ft = {'clojure', 'fennel'}}


  -- ruby
  use {'vim-ruby/vim-ruby', ft = {'ruby'}}


  -- rust
  use {'rust-lang/rust.vim', ft = {'rust'}}


  -- zig
  use {'ziglang/zig.vim', ft = {'zig'}}


  -- github copilot (:Copilot setup)
  use 'github/copilot.vim'


  ----------------
  -- lsp settings (see install methods in .tool-versions file)
  local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())
  capabilities.textDocument.completion.completionItem.documentationFormat = { 'markdown', 'plaintext' }
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = {properties = {'documentation', 'detail', 'additionalTextEdits'}}
  local nvim_lsp = require('lspconfig')
  local lsp_servers = { -- language servers with default setup
    'bashls', -- bash
    'ccls', -- clang
    'clojure_lsp',  -- clojure
    'gopls',  -- go
    'hls',  -- haskell
    'julials',  -- julia
    'pylsp',  -- python
    'rust_analyzer',  -- rust
    'solargraph', -- ruby
    'zls',  -- zig
  }
  for _, lsp in ipairs(lsp_servers) do
    nvim_lsp[lsp].setup {
      on_attach = on_attach_lsp,
      capabilities = capabilities,
    }
  end
  -------- other language servers for custom setup --------
  -- (lua)
  local runtime_path = vim.split(package.path, ';')
  table.insert(runtime_path, "lua/?.lua")
  table.insert(runtime_path, "lua/?/init.lua")
  nvim_lsp['sumneko_lua'].setup {
    settings = { Lua = {
      runtime = { version = 'LuaJIT', path = runtime_path },
      diagnostics = { globals = {'vim'} },
      workspace = { library = vim.api.nvim_get_runtime_file("", true) },
      telemetry = { enable = false },
    } },
  }

end, config = {autoremove = true, display = {open_fn = require'packer.util'.float}}})


-- neomake
vim.api.nvim_exec([[call neomake#configure#automake('nrwi', 500)]], false)
g['neomake_open_list'] = 2


-- copilot settings (ctrl+L for applying)
vim.api.nvim_exec([[imap <silent><script><expr> <C-L> copilot#Accept("<CR>")]], false)
g['copilot_no_tab_map'] = true
g['copilot_filetypes'] = {
  ['*'] = false,
  ['c'] = true, ['clojure'] = true, ['css'] = true,
  ['fennel'] = true,
  ['go'] = true,
  ['haskell'] = true, ['html'] = true,
  ['java'] = true, ['javascript'] = true, ['julia'] = true,
  ['kotlin'] = true,
  ['lua'] = true,
  ['markdown'] = true,
  ['objc'] = true,
  ['python'] = true,
  ['ruby'] = true, ['rust'] = true,
  ['sh'] = true, ['swift'] = true,
  ['zig'] = true,
}


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
opt.foldmethod = 'indent' -- automatically fold on indent
opt.foldlevelstart = 20 -- but open all folds on file open
vim.o.signcolumn = 'number'

-- for tab navigation
map('n', '<C-h>', ':tabprevious<CR>') -- <ctrl-h> for previous tab
map('n', '<C-l>', ':tabnext<CR>') -- <ctrl-l> for next tab

vim.api.nvim_create_augroup("etc", {clear = true})
vim.api.nvim_create_autocmd('BufReadPost', {group = 'etc', pattern = '*', callback = function() -- go to the last position of a file
  if vim.fn.line('.') > 0 and vim.fn.line('.') <= vim.fn.line('$') then
    vim.cmd([[exe "normal g`\""]])
  end
end})
vim.api.nvim_create_autocmd('TextYankPost', {group = 'etc', pattern = '*', callback = function() -- highlight on yank
  vim.highlight.on_yank({on_visual = false})
end})

-- for diagnostics
vim.api.nvim_create_autocmd('CursorHold', {pattern = '*', callback = function()
  vim.diagnostic.open_float(nil, { focusable = false, close_events = { 'BufLeave', 'CursorMoved', 'InsertEnter', 'FocusLost' }, border = 'rounded', source = 'always', prefix = ' ' })
end})

-- disable unneeded providers
g['loaded_python_provider'] = 0
g['loaded_perl_provider'] = 0

