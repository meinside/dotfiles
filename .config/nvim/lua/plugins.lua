-- .config/nvim/lua/plugins.lua
--
-- Neovim plugins list
--
-- NOTE: sourced from: `.config/nvim/init.lua`
--
-- last update: 2023.01.11.


------------------------------------------------
--
-- install packer automatically
-- (https://github.com/wbthomason/packer.nvim#bootstrapping)
local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end
local packer_bootstrap = ensure_packer()


------------------------------------------------
--
-- packer plugins here
local packer = require'packer'
return packer.startup { function()
  local ok
  local use = packer.use

  use 'wbthomason/packer.nvim'


  -- startup time
  use 'dstein64/vim-startuptime'  -- :StartupTime


  -- colorschemes (https://github.com/rockerBOO/awesome-neovim#colorscheme)
  use {
    'projekt0n/github-nvim-theme',
    config = function() require'github-theme'.setup { theme_style = 'dark', transparent = true } end
  }


  -- show keymaps
  use {
    'folke/which-key.nvim',
    config = function()
      require('which-key').setup { }
    end,
  }


  -- notification
  use {
    'rcarriga/nvim-notify',
    config = function()
      local notify = require'notify'
      notify.setup {
        background_colour = '#000000',
      }
      vim.notify = notify -- override `vim.notify`
    end,
  }


  -- dim inactive window
  use 'blueyed/vim-diminactive'


  -- split/join blocks of code (<space>m - toggle, <space>j - join, <space>s - split)
  use {
    'Wansmer/treesj',
    requires = { 'nvim-treesitter' },
    config = function()
      require'treesj'.setup { max_join_length = 240 }
    end,
  }


  -- minimap
  use {
    'gorbit99/codewindow.nvim',
    config = function()
      local codewindow = require'codewindow'
      codewindow.setup {}

      -- for toggling minimap: \mt
      vim.keymap.set('n', '<leader>mt', function() codewindow.toggle_minimap() end, { remap = false, silent = true, desc = 'minimap: Toggle' })
    end,
  }


  -- markdown preview
  use { 'iamcco/markdown-preview.nvim', run = 'cd app && npm install', ft = { 'markdown' } }


  -- d2
  use { 'terrastruct/d2-vim', ft = { 'd2' } }


  -- fold and preview (zc for closing, zo for opening / zM for closing all, zR opening all)
  use {
    'anuvyklack/pretty-fold.nvim',
    requires = {'anuvyklack/fold-preview.nvim', 'anuvyklack/keymap-amend.nvim'},
    config = function()
      require'pretty-fold'.setup {
        keep_indentation = false,
        fill_char = '━',
        sections = {
          left = { '━ ', function() return string.rep('*', vim.v.foldlevel) end, ' ━┫', 'content', '┣' },
          right = { '┫ ', 'number_of_folded_lines', ': ', 'percentage', ' ┣━━' }
        }
      }
      require'fold-preview'.setup {}
    end,
  }


  -- formatting
  use {
    -- cs'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
    'kylechui/nvim-surround',
    config = function()
      require'nvim-surround'.setup {}
    end,
  }
  use {
    'lukas-reineke/indent-blankline.nvim',
    config = function()
      require'indent_blankline'.setup {
        char = '▏',
        buftype_exclude = { 'terminal' },
        show_current_context = true,
        show_current_context_start = true,
      }
    end,
  }
  use 'tpope/vim-ragtag' -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  use 'tpope/vim-sleuth'
  use 'mrjones2014/nvim-ts-rainbow'


  -- annotation
  use {
    'danymat/neogen',
    config = function()
      require('neogen').setup {
        snippet_engine = 'luasnip',
      }
    end,
    requires = 'nvim-treesitter/nvim-treesitter',
  }


  -- finder / locator
  use 'mtth/locate.vim' -- :L [query], :lclose, gl
  use 'johngrib/vim-f-hangul'	-- can use f/t/;/, on Hangul characters
  use {
    'nvim-telescope/telescope.nvim',
    requires = {
      { 'nvim-lua/popup.nvim' },
      { 'nvim-lua/plenary.nvim' },
      { 'nvim-telescope/telescope-fzf-native.nvim' },
    },
    config = function()
      local telescope = require'telescope'
      telescope.setup {
        extensions = {
          fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = 'smart_case',        -- or "ignore_case" or "respect_case"
          }
        }
      }
      telescope.load_extension('fzf')

      -- https://github.com/nvim-telescope/telescope.nvim#pickers
      local builtin = require'telescope.builtin'
      vim.keymap.set('n', '<leader>tt', builtin.builtin, {remap = false, silent = true, desc = 'telescope: List builtin pickers'})
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {remap = false, silent = true, desc = 'telescope: Find files'})
      vim.keymap.set('n', '<leader>gc', builtin.git_commits, {remap = false, silent = true, desc = 'telescope: Git commits'})
      vim.keymap.set('n', '<leader>qf', builtin.quickfix, {remap = false, silent = true, desc = 'telescope: Quickfix'})
      vim.keymap.set('n', '<leader>lr', builtin.lsp_references, {remap = false, silent = true, desc = 'telescope: LSP references'})
      vim.keymap.set('n', '<leader>li', builtin.lsp_implementations, {remap = false, silent = true, desc = 'telescope: LSP implementations'})
      vim.keymap.set('n', '<leader>ld', builtin.lsp_definitions, {remap = false, silent = true, desc = 'telescope: LSP definitions'})
    end,
  }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }


  -- git
  use 'junegunn/gv.vim' -- :GV, :GV!, :GV?
  use {
    'lewis6991/gitsigns.nvim', -- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
      require'gitsigns'.setup {
        numhl = true,
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function m(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end

          -- Navigation
          m('n', ']c', function()
            if vim.wo.diff then return ']c' end
            vim.schedule(function() gs.next_hunk() end)
            return '<Ignore>'
          end, { expr = true, desc = 'gitsigns: Next hunk' })
          m('n', '[c', function()
            if vim.wo.diff then return '[c' end
            vim.schedule(function() gs.prev_hunk() end)
            return '<Ignore>'
          end, { expr = true, desc = 'gitsigns: Previous hunk' })

          -- Actions
          m({ 'n', 'v' }, '<leader>hs', ':Gitsigns stage_hunk<CR>', {desc = 'gitsigns: Stage hunk'})
          m({ 'n', 'v' }, '<leader>hr', ':Gitsigns reset_hunk<CR>', {desc = 'gitsigns: Reset hunk'})
          m('n', '<leader>hS', gs.stage_buffer, {desc = 'gitsigns: Stage buffer'})
          m('n', '<leader>hu', gs.undo_stage_hunk, {desc = 'gitsigns: Undo stage hunk'})
          m('n', '<leader>hR', gs.reset_buffer, {desc = 'gitsigns: Reset buffer'})
          m('n', '<leader>hp', gs.preview_hunk, {desc = 'gitsigns: Preview hunk'})
          m('n', '<leader>hb', function() gs.blame_line {full = true} end, {desc = 'gitsigns: Blame line'})
          m('n', '<leader>tb', gs.toggle_current_line_blame, {desc = 'gitsigns: Toggle current line blame'})
          m('n', '<leader>hd', gs.diffthis, {desc = 'gitsigns: Diff this'})
          m('n', '<leader>hD', function() gs.diffthis('~') end, {desc = 'gitsigns: Diff this ~'})
          m('n', '<leader>td', gs.toggle_deleted, {desc = 'gitsigns: Toggle deleted'})

          -- Text object
          m({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        end,
      }
    end,
  }
  -- gist (:Gist / :Gist -p / ...)
  use 'mattn/webapi-vim'
  use 'mattn/gist-vim'


  -- statusline
  use {
    'nvim-lualine/lualine.nvim',
    after = 'github-nvim-theme',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true },
    config = function()
      local navic = require'nvim-navic'
      require'lualine'.setup {
        options = {
          disabled_filetypes = { 'help', 'packer', 'NvimTree', 'TelescopePrompt', 'gitcommit' },
          globalstatus = true,
        },
        extensions = { 'nvim-dap-ui', 'quickfix' },
        sections = {
          lualine_c = { 'filename', { navic.get_location, cond = navic.is_available } },
        },
        winbar = { lualine_c = { { 'filetype', icon_only = true }, { 'filename' } } },
        inactive_winbar = { lualine_c = { 'filename' } },
      }
    end,
  }
  use { 'SmiteshP/nvim-navic', requires = { 'neovim/nvim-lspconfig' } }


  -- auto pair/close
  use {
    'windwp/nvim-autopairs',
    config = function()
      require'nvim-autopairs'.setup {}
    end,
  }


  -- lsp
  use 'neovim/nvim-lspconfig'
  use {
    'ray-x/lsp_signature.nvim',
    config = function()
      require'lsp_signature'.setup { bind = true, handler_opts = { border = 'single' } }
    end,
  }
  use {
    'https://git.sr.ht/~whynothugo/lsp_lines.nvim',
    config = function()
      local ll = require'lsp_lines'
      ll.setup()
      vim.keymap.set('', '<leader>ll', ll.toggle, { desc = 'lsp_lines: Toggle' })
    end,
  }
  use {
    'onsails/lspkind-nvim',
    config = function()
      -- (gray)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrDeprecated', { bg = 'NONE', fg = '#808080', strikethrough = true })
      -- (blue)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatch', { bg = 'NONE', fg = '#569CD6' })
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatchFuzzy', { bg = 'NONE', fg = '#569CD6' })
      -- (light blue)
      vim.api.nvim_set_hl(0, 'CmpItemKindVariable', { bg = 'NONE', fg = '#9CDCFE' })
      vim.api.nvim_set_hl(0, 'CmpItemKindInterface', { bg = 'NONE', fg = '#9CDCFE' })
      vim.api.nvim_set_hl(0, 'CmpItemKindText', { bg = 'NONE', fg = '#9CDCFE' })
      -- (pink)
      vim.api.nvim_set_hl(0, 'CmpItemKindFunction', { bg = 'NONE', fg = '#C586C0' })
      vim.api.nvim_set_hl(0, 'CmpItemKindMethod', { bg = 'NONE', fg = '#C586C0' })
      -- (front)
      vim.api.nvim_set_hl(0, 'CmpItemKindKeyword', { bg = 'NONE', fg = '#D4D4D4' })
      vim.api.nvim_set_hl(0, 'CmpItemKindProperty', { bg = 'NONE', fg = '#D4D4D4' })
      vim.api.nvim_set_hl(0, 'CmpItemKindUnit', { bg = 'NONE', fg = '#D4D4D4' })
    end,
  }
  use {
    'williamboman/mason.nvim',
    config = function()
      require'mason'.setup { ui = { icons = { package_installed = '✓', package_pending = '➜', package_uninstalled = '✗' } } }
    end,
  }
  use {
    'williamboman/mason-lspconfig.nvim',
    config = function()
      -- install lsp servers
      require'mason-lspconfig'.setup {
        ensure_installed = require'locals'.installable_lsp_names(), -- NOTE: see `.config/nvim/lua/locals/lsps.sample.lua`
        automatic_installation = true,
      }

      -- NOTE: no way of installing things other than lsp servers for now
      -- install other things with: :MasonInstall delve codelldb
    end,
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
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-calc',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function ()
      local cmp = require'cmp'
      local luasnip = require'luasnip'
      local lspkind = require'lspkind'

      cmp.setup {
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
          ['<C-Space>'] = cmp.mapping(cmp.mapping.complete{}, { 'i', 'c' }),
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
          { name = 'buffer', keyword_length = 3 },
          { name = 'path' },
          { name = 'calc' },
          { name = 'nvim_lsp', keyword_length = 3 },
          { name = 'luasnip', keyword_length = 2 },
          { name = 'nvim_lua', keyword_length = 2 },
        },
        formatting = { format = lspkind.cmp_format() },
      }

      -- setup autopairs
      cmp.event:on('confirm_done', require'nvim-autopairs.completion.cmp'.on_confirm_done())

      -- load snippets
      require'luasnip/loaders/from_vscode'.lazy_load()
    end,
  }


  -- syntax highlighting and rainbow parenthesis
  --
  -- $ cargo install tree-sitter-cli
  -- or
  -- $ brew install tree-sitter
  --
  -- NOTE: if it complains about any language, try :TSInstall [xxx]
  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require'nvim-treesitter.configs'.setup {
        ensure_installed = {
          'bash',
          'c', 'clojure', 'cmake', 'comment', 'cpp', 'css',
          'dart', 'diff', 'dockerfile',
          'fennel',
          'go', 'gomod', 'gowork', --'gitignore',
          'haskell', 'html', 'http',
          'java', 'javascript', 'jq', 'jsdoc', 'json', 'json5', 'jsonc', --'julia',
          'kotlin',
          'latex', 'llvm', 'lua',
          'make', 'markdown', 'markdown_inline', 'mermaid',
          'perl', 'php', 'python',
          'query',
          'r', 'regex', 'ruby', 'rust',
          'scheme', 'scss', 'sql', --'swift',
          'toml', 'typescript',
          'yaml',
          'zig',
        },
        highlight = { enable = true },
        rainbow = { enable = true, extended_mode = true },
      }
    end,
  }
  use 'nvim-treesitter/nvim-treesitter-context'


  -- code action: `\ca`
  use { 'weilbith/nvim-code-action-menu', cmd = 'CodeActionMenu' }
  use {
    'kosayoda/nvim-lightbulb',
    requires = 'antoinemadec/FixCursorHold.nvim',
    config = function()
      require'nvim-lightbulb'.setup { autocmd = { enabled = true } }
    end,
  }


  -- debug adapter
  use {
    'mfussenegger/nvim-dap',
    config = function()
      -- dap sign icons and colors
      vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'LspDiagnosticsSignError', linehl = '', numhl = '' })
      vim.fn.sign_define('DapStopped', { text = '', texthl = 'LspDiagnosticsSignInformation', linehl = 'DiagnosticUnderlineInfo', numhl = 'LspDiagnosticsSignInformation' })
      vim.fn.sign_define('DapBreakpointRejected', { text = '', texthl = 'LspDiagnosticsSignHint', linehl = '', numhl = '' })
    end,
  }
  use {
    'rcarriga/nvim-dap-ui',
    requires = { 'mfussenegger/nvim-dap' },
    config = function()
      local dap, dapui = require 'dap', require 'dapui'
      dapui.setup {}
      -- auto toggle debug UIs
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close
    end,
  }
  use {
    'theHamsta/nvim-dap-virtual-text',
    config = function()
      require'nvim-dap-virtual-text'.setup { commented = true }
    end,
  }


  -- bash
  use { 'bash-lsp/bash-language-server', ft = { 'sh' } }


  -- go
  use {
    'ray-x/go.nvim',
    ft = { 'go' },
    config = function()
      require'go'.setup { gofmt = 'gopls' }
      vim.api.nvim_exec([[autocmd BufWritePre *.go :silent! lua require('go.format').goimport()]], false)
    end,
  }
  use { 'ray-x/guihua.lua', run = 'cd lua/fzy && make' }
  use {
    'leoluz/nvim-dap-go',
    -- install `delve` with :Mason
    -- :DapContinue for starting debugging
    ft = {'go'},
    config = function()
      require'dap-go'.setup()
    end,
  }


  -- haskell
  use { 'neovimhaskell/haskell-vim', ft = { 'haskell' } }
  use { 'itchyny/vim-haskell-indent', ft = { 'haskell' } }
  if vim.fn.executable('stylish-haskell') == 1 then
    use { 'alx741/vim-stylishask', ft = { 'haskell' } }
  end


  -- lispy languages
  local lisps = { 'clojure', 'fennel', 'janet', 'scheme' }
  -- for auto completion: <C-x><C-o>
  -- for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
  -- for reloading everything: \rr
  -- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
  use { 'Olical/conjure', ft = lisps }
  use { 'dmac/vim-cljfmt', ft = { 'clojure' } } -- $ go install github.com/cespare/goclj/cljfmt
  use {
    'bakpakin/fennel.vim',
    ft = { 'fennel' },
    config = function() -- https://github.com/Olical/conjure/wiki/Quick-start:-Fennel-(stdio)
      vim.api.nvim_exec([[let g:conjure#filetype#fennel = "conjure.client.fennel.stdio"]], false)
    end,
  }
  use {
    'bakpakin/janet.vim',
    ft = { 'janet' },
    config = function()
      if vim.fn.executable('lsof') == 1 then
        local open = vim.fn.system('lsof -i:9365 | grep LISTEN')
        if string.len(open) <= 0 then
          vim.api.nvim_create_autocmd('BufEnter', {pattern = '*.janet', callback = function()
            print("NOTE: run LSP with $ janet -e '(import spork/netrepl) (netrepl/server)'")
          end})
        end
      else
        error('`lsof` is not installed.')
      end
    end,
  }
  vim.api.nvim_exec([[
    let g:conjure#client#scheme#stdio#command = "petite"
    let g:conjure#client#scheme#stdio#prompt_pattern = "> $?"
  ]], false)
  -- >f, <f : move a form
  -- >e, <e : move an element
  -- >), <), >(, <( : move a parenthesis
  -- <I, >I : insert at the beginning or end of a form
  -- dsf : remove surroundings
  -- cse(, cse), cseb : surround an element with parenthesis
  -- cse[, cse] : surround an element with brackets
  -- cse{, cse} : surround an element with braces
  use { 'guns/vim-sexp', ft = lisps }
  vim.g['sexp_enable_insert_mode_mappings'] = 0 -- '"' key works weirdly in insert mode
  vim.g['sexp_filetypes'] = table.concat(lisps, ',')
  use { 'tpope/vim-sexp-mappings-for-regular-people', ft = lisps }
  use { 'gpanders/nvim-parinfer', ft = lisps }


  -- nim
  use { 'alaviss/nim.nvim', ft = { 'nim' } }


  -- ruby
  use { 'vim-ruby/vim-ruby', ft = { 'ruby' } }
  use {
    'suketa/nvim-dap-ruby',
    ft = { 'ruby' },
    config = function()
      -- $ gem install readapt
      -- :DapContinue for debugging
      require'dap-ruby'.setup()
    end,
  }


  -- rust
  use {
    'simrat39/rust-tools.nvim',
    --ft = { 'rust' }, -- FIXME: lazyloading doesn't work
    requires = { { 'nvim-lua/plenary.nvim' }, { 'mfussenegger/nvim-dap' } },
  }


  -- zig
  use { 'ziglang/zig.vim', ft = { 'zig' } }


  -- vale (see ~/.vale.ini)
  use 'jose-elias-alvarez/null-ls.nvim'


  ----------------
  -- lsp settings
  local mason_pkgs_dir = vim.env.HOME .. '/.local/share/nvim/mason/packages'
  local on_attach_lsp = function(client, bufnr) -- default setup for language servers
    -- Enable completion triggered by <c-x><c-o>
    vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { remap = false, silent = true, desc = 'lsp: Declaration' })
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { remap = false, silent = true, desc = 'lsp: Definition' })
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, { remap = false, silent = true, desc = 'lsp: Hover' })
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { remap = false, silent = true, desc = 'lsp: Implementation' })
    --vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, { remap = false, silent = true, desc = 'lsp: Signature help' })
    --vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, { remap = false, silent = true, desc = 'lsp: Add workspace folder' })
    --vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, { remap = false, silent = true, desc = 'lsp: Remove workspace folder' })
    --vim.keymap.set('n', '<space>wl', function() print(vim.inspect(vim.lsp.buf.list_workspace_folders())) end, { remap = false, silent = true, desc = 'lsp: List workspace folders' })
    vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, { remap = false, silent = true, desc = 'lsp: Type definition' })
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { remap = false, silent = true, desc = 'lsp: Rename' })
    --vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { remap = false, silent = true, desc = 'lsp: Code action' })
    vim.keymap.set('n', '<leader>ca', '<cmd>CodeActionMenu<CR>', { remap = false, silent = true, desc = 'lsp: Code action' })
    --vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', { remap = false, silent = true, desc = 'lsp: References' })
    vim.keymap.set('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', { remap = false, silent = true, desc = 'lsp: Previous diagnostic' })
    vim.keymap.set('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', { remap = false, silent = true, desc = 'lsp: Next diagnostic' })
    vim.keymap.set('n', '<leader>dl', '<cmd>lua vim.diagnostic.setloclist()<CR>', { remap = false, silent = true, desc = 'lsp: Diagnostics list' })
    vim.keymap.set('n', '<leader>fo', '<cmd>lua vim.lsp.buf.format {async = true}<CR>', { remap = false, silent = true, desc = 'lsp: Format' })

    -- diagnostics configuration
    vim.diagnostic.config({ underline = false, virtual_text = false, signs = true, severity_sort = true, update_in_insert = false })
    vim.fn.sign_define('DiagnosticSignError', { text = '✗', texthl = 'DiagnosticSignError' })
    vim.fn.sign_define('DiagnosticSignWarn', { text = '!', texthl = 'DiagnosticSignWarn' })
    vim.fn.sign_define('DiagnosticSignInformation', { text = '', texthl = 'DiagnosticSignInfo' })
    vim.fn.sign_define('DiagnosticSignHint', { text = '', texthl = 'DiagnosticSignHint' })

    -- auto formatting on save
    if client.server_capabilities.document_formatting then
      vim.api.nvim_create_autocmd('BufWritePre', { callback = function() vim.lsp.buf.format { async = false } end })
    end

    -- highlight current variable
    if client.server_capabilities.document_highlight then
      vim.api.nvim_set_hl(0, 'LspReferenceRead', { link = 'Visual' })
      vim.api.nvim_set_hl(0, 'LspReferenceText', { link = 'Visual' })
      vim.api.nvim_set_hl(0, 'LspReferenceWrite', { link = 'Visual' })
      vim.api.nvim_create_augroup('lsp_document_highlight', { clear = true })
      vim.api.nvim_create_autocmd('CursorHold', { group = 'lsp_document_highlight', callback = function() vim.lsp.buf.document_highlight() end })
      vim.api.nvim_create_autocmd('CursorMoved', { group = 'lsp_document_highlight', callback = function() vim.lsp.buf.clear_references() end })
    end

    -- navic
    if client.server_capabilities.documentSymbolProvider then
      require'nvim-navic'.attach(client, bufnr)
    end
  end
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local cmp_nvim_lsp
  ok, cmp_nvim_lsp = pcall(require, 'cmp_nvim_lsp')
  if ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end
  capabilities.textDocument.completion.completionItem.documentationFormat = { 'markdown', 'plaintext' }
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
  capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
  capabilities.textDocument.completion.completionItem.resolveSupport = { properties = { 'documentation', 'detail', 'additionalTextEdits' } }
  local lsp_settings = {
    gopls = {
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        compositeLiteralTypes = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
    Lua = {
      runtime = { version = 'LuaJIT', path = (function()
        local runtime_paths = vim.split(package.path, ';')
        table.insert(runtime_paths, 'lua/?.lua')
        table.insert(runtime_paths, 'lua/?/init.lua')
        return runtime_paths
      end)() },
      diagnostics = { globals = { 'vim' } },
      workspace = {
        library = vim.api.nvim_get_runtime_file('', true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  }
  -------- automatic configuration with `lspconfig` --------
  local nvim_lsp
  ok, nvim_lsp = pcall(require, 'lspconfig')
  if ok then
    for _, lsp in ipairs(require'locals'.autoconfigurable_lsp_names()) do -- NOTE: see `.config/nvim/lua/locals/lsps.sample.lua`
      nvim_lsp[lsp].setup { on_attach = on_attach_lsp, capabilities = capabilities, settings = lsp_settings }
    end
  end
  -------- manual configuration here --------
  -- (rust)
  local rust_tools
  ok, rust_tools = pcall(require, 'rust-tools')
  if ok then
    rust_tools.setup {
      tools = {hover_actions = { auto_focus = true }},
      server = { on_attach = on_attach_lsp, capabilities = capabilities },
      dap = {
        -- install `codelldb` with :Mason
        -- :RustDebuggables for debugging
        adapter = require'rust-tools.dap'.get_codelldb_adapter(
          mason_pkgs_dir .. '/codelldb/extension/adapter/codelldb',
          mason_pkgs_dir .. '/codelldb/extension/lldb/lib/liblldb.so'
        ),
      },
    }
  end
  -- FIXME: `rust-tools` doesn't format on file saves
  vim.api.nvim_create_autocmd('BufWritePre', { pattern = '*.rs', callback = function() vim.lsp.buf.format { async = false } end })


  -- vale
  if vim.fn.executable('vale') == 1 then -- $ go install github.com/errata-ai/vale@latest
    local null_ls
    ok, null_ls = pcall(require, 'null-ls')
    if ok then
      null_ls.setup {
        sources = {
          require'null-ls'.builtins.diagnostics.vale,
        },
      }
    end
  end


  -- sync plugins after bootstrapping
  if packer_bootstrap then
    require'packer'.sync()
  end
end, config = { autoremove = true, display = { open_fn = function() return require'packer.util'.float { border = 'single' } end } } }

