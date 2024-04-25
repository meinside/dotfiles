-- .config/nvim/lua/plugins.lua
--
-- Neovim plugins list
--
-- NOTE: this will be sourced from: ~/.config/nvim/init.lua
--
-- last update: 2024.04.25.


------------------------------------------------
-- imports
--
local tools = require'tools'    -- ~/.config/nvim/lua/tools.lua
local lsps = require'lsps'      -- ~/.config/nvim/lua/lsps.lua
local custom = require'custom'  -- ~/.config/nvim/lua/custom/init.lua


------------------------------------------------
-- global variables
--
-- (for all lispy languages)
local lisps = { 'clojure', 'fennel', 'janet' }
-- (for conjure)
vim.g['conjure#filetypes'] = lisps
vim.g['conjure#filetype#fennel'] = 'conjure.client.fennel.stdio' -- for fennel
-- (for nvim-parinfer)
vim.g['parinfer_filetypes'] = lisps
-- (for guns/vim-sexp)
vim.g['sexp_enable_insert_mode_mappings'] = 0 -- '"' key works weirdly in insert mode
vim.g['sexp_filetypes'] = table.concat(lisps, ',')


------------------------------------------------
-- lazy
--
-- install `lazy` automatically
-- (https://github.com/folke/lazy.nvim#-installation)
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
-- NOTE: TODO: replace `vim.loop` with `vim.uv` after neovim 0.10 becomes stable
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


------------------------------------------------
-- lazy
--
-- load `lazy` plugins here
require'lazy'.setup({

  -- startup time (:StartupTime)
  'dstein64/vim-startuptime',


  -- colorschemes
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require'catppuccin'.setup {
        flavour = 'mocha',
        term_colors = true,
        styles = {
          comments = { 'italic' },
          conditionals = { 'italic' },
          loops = { 'italic' },
          functions = { 'italic' },
          keywords = { 'italic' },
          strings = {},
          variables = {},
          numbers = {},
          booleans = {},
          properties = {},
          types = {},
        },
        color_overrides = {
          mocha = {
            base = '#000000',
            mantle = '#000000',
            crust = '#000000',
          },
        },
        highlight_overrides = {
          mocha = function(C)
            return {
              CmpBorder = { fg = C.surface2 },
              CursorLine = { bg = '#423030' },
              Pmenu = { bg = C.none },
              TelescopeBorder = { link = 'FloatBorder' },
            }
          end,
        },
        integrations = {
          notify = true,
          mason = true,
          navic = { enabled = true, custom_bg = 'NONE' },
          which_key = true,
        },
      }
      vim.cmd.colorscheme 'catppuccin'
    end,
  },


  -- file browser
  {
    'echasnovski/mini.files', version = false, config = function()
      require'mini.files'.setup {}

      -- for toggling minifiles: \mf
      vim.keymap.set('n', '<leader>mf', function()
        MiniFiles.open()
      end, { remap = false, silent = true, desc = 'mini-files: Open' })
    end,
  },


  -- notification
  {
    'rcarriga/nvim-notify', config = function()
      local notify = require'notify'
      notify.setup { background_colour = '#000000' }
      vim.notify = notify -- override `vim.notify`
    end,
    event = 'VeryLazy',
  },


  -- dim unused things (LSP)
  {
    'zbirenbaum/neodim',
    event = 'LspAttach',
    config = function()
      require'neodim'.setup {
        refresh_delay = 75,
        alpha = 0.75,
        blend_color = '#000000',
        hide = {
          underline = true,
          virtual_text = true,
          signs = true,
        },
        regex = {
          '[uU]nused',
          '[nN]ever [rR]ead',
          '[nN]ot [rR]ead',
        },
        priority = 128,
        disable = {},
      }
    end,
    cond = function() return vim.fn.has('nvim-0.10') == 1 end, -- NOTE: TODO: remove this line after neovim 0.10 becomes stable
  },


  -- show keymaps
  {
    'folke/which-key.nvim', config = function()
      require'which-key'.setup { }
    end,
  },


  -- dim inactive window
  { 'blueyed/vim-diminactive' },


  -- last position
  {
    'ethanholz/nvim-lastplace', config = function()
      require'nvim-lastplace'.setup {
        lastplace_ignore_buftype = {
          'quickfix',
          'nofile',
          'help',
        },
        lastplace_ignore_filetype = {
          'gitcommit',
          'gitrebase',
          'svn',
          'hgcommit',
        },
        lastplace_open_folds = true,
      }
    end,
  },


  -- split/join blocks of code (<space>m - toggle, <space>j - join, <space>s - split)
  {
    'Wansmer/treesj', config = function()
      require'treesj'.setup {
        max_join_length = 240,
      }
    end,
    dependencies = { 'nvim-treesitter' },
  },


  -- minimap
  {
    'gorbit99/codewindow.nvim', config = function()
      local codewindow = require'codewindow'
      codewindow.setup {}

      -- for toggling minimap: \mt
      vim.keymap.set('n', '<leader>mt', function()
        codewindow.toggle_minimap()
        vim.notify 'Toggled minimap.'
      end, { remap = false, silent = true, desc = 'minimap: Toggle' })
    end,
  },


  -- comment (gcc, gbc / visual block + gc, gb)
  {
    'numToStr/Comment.nvim',
    config = function() require'Comment'.setup() end
  },


  -- relative/absolute linenumber toggling
  { 'cpea2506/relative-toggle.nvim' },


  -- show color column
  { 'Bekaboo/deadcolumn.nvim' },


  -- markdown preview
  {
    'iamcco/markdown-preview.nvim',
    build = 'cd app && npm install',
    ft = { 'markdown' },
  },


  -- d2
  { 'terrastruct/d2-vim', ft = { 'd2' } },


  -- fold and preview (zc for closing, zo for opening, za for toggling / zM for closing all, zR for opening all)
  {
    --'anuvyklack/pretty-fold.nvim', config = function() -- FIXME: https://github.com/anuvyklack/pretty-fold.nvim/issues/38
    'bbjornstad/pretty-fold.nvim', config = function()
      require'pretty-fold'.setup {
        keep_indentation = false,
        fill_char = '━',
        sections = {
          left = {
            '━ ',
            function() return string.rep('*', vim.v.foldlevel) end,
            ' ━┫',
            'content',
            '┣',
          },
          right = {
            '┫ ',
            'number_of_folded_lines',
            ': ',
            'percentage',
            ' ┣━━',
          },
        }
      }
      require'fold-preview'.setup {}
    end,
    dependencies = { 'anuvyklack/fold-preview.nvim', 'anuvyklack/keymap-amend.nvim' },
  },


  -- formatting
  {
    -- cs'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
    'kylechui/nvim-surround', config = function()
      require'nvim-surround'.setup {}
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim', main = 'ibl', config = function()
      require'ibl'.setup {}
    end,
  },
  { 'tpope/vim-ragtag' }, -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  { 'tpope/vim-sleuth' },
  {
    'HiPhish/rainbow-delimiters.nvim', config = function()
      local rd = require'rainbow-delimiters'
      require'rainbow-delimiters.setup'.setup {
        strategy = {
          [''] = rd.strategy['global'],
        },
        query = {
          [''] = 'rainbow-delimiters',
        },
      }
    end,
  },


  -- marks
  {
    'chentoast/marks.nvim', config = function()
      require'marks'.setup {
        force_write_shada = true, -- FIXME: marks are not removed across sessions without this configuration
      }
    end,
  },


  -- annotation
  {
    -- :Neogen
    'danymat/neogen', config = function()
      require'neogen'.setup { snippet_engine = 'luasnip' }
    end,
    dependencies = 'nvim-treesitter/nvim-treesitter',
  },


  -- finder / locator
  { 'mtth/locate.vim' }, -- :L [query], :lclose, gl
  { 'johngrib/vim-f-hangul' },	-- can use f/t/;/, on Hangul characters
  {
    'nvim-telescope/telescope.nvim', config = function()
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
      local _, _ = pcall(function() telescope.load_extension('fzf') end)

      -- https://github.com/nvim-telescope/telescope.nvim#pickers
      local builtin = require'telescope.builtin'
      vim.keymap.set('n', '<leader>tt', builtin.builtin, {
        remap = false,
        silent = true,
        desc = 'telescope: List builtin pickers',
      })
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {
        remap = false,
        silent = true,
        desc = 'telescope: Find files',
      })
      vim.keymap.set('n', '<leader>gc', builtin.git_commits, {
        remap = false,
        silent = true,
        desc = 'telescope: Git commits',
      })
      vim.keymap.set('n', '<leader>qf', builtin.quickfix, {
        remap = false,
        silent = true,
        desc = 'telescope: Quickfix',
      })
      vim.keymap.set('n', '<leader>lr', builtin.lsp_references, {
        remap = false,
        silent = true,
        desc = 'telescope: LSP references',
      })
      vim.keymap.set('n', '<leader>li', builtin.lsp_implementations, {
        remap = false,
        silent = true,
        desc = 'telescope: LSP implementations',
      })
      vim.keymap.set('n', '<leader>ld', builtin.lsp_definitions, {
        remap = false,
        silent = true,
        desc = 'telescope: LSP definitions',
      })
    end,
    dependencies = {
      { 'nvim-lua/popup.nvim' },
      { 'nvim-lua/plenary.nvim' },
      { 'nvim-telescope/telescope-fzf-native.nvim' },
    },
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    cond = tools.system.not_termux(), -- do not load in termux
  },


  -- git
  { 'junegunn/gv.vim' }, -- :GV, :GV!, :GV?
  {
    -- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    'lewis6991/gitsigns.nvim', config = function()
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
          m(
            { 'n', 'v' },
            '<leader>hs',
            ':Gitsigns stage_hunk<CR>',
            { desc = 'gitsigns: Stage hunk' }
          )
          m(
            { 'n', 'v' },
            '<leader>hr',
            ':Gitsigns reset_hunk<CR>',
            { desc = 'gitsigns: Reset hunk' }
          )
          m(
            'n',
            '<leader>hS',
            gs.stage_buffer,
            { desc = 'gitsigns: Stage buffer' }
          )
          m(
            'n',
            '<leader>hu',
            gs.undo_stage_hunk,
            { desc = 'gitsigns: Undo stage hunk' }
          )
          m(
            'n',
            '<leader>hR',
            gs.reset_buffer,
            { desc = 'gitsigns: Reset buffer' }
          )
          m(
            'n',
            '<leader>hp',
            gs.preview_hunk,
            { desc = 'gitsigns: Preview hunk' }
          )
          m(
            'n',
            '<leader>hb',
            function() gs.blame_line { full = true } end,
            { desc = 'gitsigns: Blame line' }
          )
          m(
            'n',
            '<leader>tb',
            gs.toggle_current_line_blame,
            { desc = 'gitsigns: Toggle current line blame' }
          )
          m(
            'n',
            '<leader>hd',
            gs.diffthis,
            { desc = 'gitsigns: Diff this' }
          )
          m(
            'n',
            '<leader>hD',
            function() gs.diffthis('~') end,
            { desc = 'gitsigns: Diff this ~' }
          )
          m(
            'n',
            '<leader>td',
            gs.toggle_deleted,
            { desc = 'gitsigns: Toggle deleted' }
          )

          -- Text object
          m(
            { 'o', 'x' },
            'ih',
            ':<C-U>Gitsigns select_hunk<CR>'
          )
        end,
      }
    end,
    dependencies = { { 'nvim-lua/plenary.nvim' } },
  },
  -- gist (:Gist / :Gist -p / ...)
  { 'mattn/webapi-vim' },
  { 'mattn/gist-vim' },


  -- statusline
  {
    'linrongbin16/lsp-progress.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function() require'lsp-progress'.setup() end
  },
  {
    'nvim-lualine/lualine.nvim', config = function()
      local navic = require'nvim-navic'
      navic.setup { highlight = true }
      require'lualine'.setup {
        options = {
          theme = 'catppuccin',
          disabled_filetypes = {
            'help',
            'packer',
            'NvimTree',
            'TelescopePrompt',
            'gitcommit',
          },
          globalstatus = true,
        },
        extensions = { 'nvim-dap-ui', 'quickfix' },
        sections = {
          lualine_c = {
            'filename',
            require'lsp-progress'.progress,
            {
              function()
                return navic.get_location()
              end,
              cond = function()
                return navic.is_available()
              end,
            },
          },
        },
      }
    end,
    dependencies = { 'nvim-tree/nvim-web-devicons', 'linrongbin16/lsp-progress.nvim' },
  },
  { 'SmiteshP/nvim-navic', dependencies = { 'neovim/nvim-lspconfig' } },


  -- tabline
  {
    'crispgm/nvim-tabline', config = function()
      require'tabline'.setup {
        show_index = false,
        show_modify = true,
        show_icon = true,
        modify_indicator = '*',
        no_name = '<untitled>',
        brackets = { '', '' },
      }
    end,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },


  --------------------------------
  --
  -- tools for development
  --

  -- trouble
  {
    'folke/trouble.nvim', config = function()
      require'trouble'.setup {}
    end,
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },


  -- auto pair/close
  {
    'windwp/nvim-autopairs', config = function()
      require'nvim-autopairs'.setup {}
    end,
  },


  -- code generation & completion
  {
    -- :Codeium Auth
    'Exafunction/codeium.nvim', config = function()
      require'codeium'.setup { }
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'hrsh7th/nvim-cmp',
    },
    cond = custom.features().codeium, -- .config/nvim/lua/custom/init.lua
  },


  -- screenshot codeblocks
  {
    'michaelrommel/nvim-silicon',
    lazy = true,
    cmd = 'Silicon',
    config = function()
      require'silicon'.setup {
        font = 'JetBrainsMono Nerd Font Mono=20;Nanum Gothic;Noto Color Emoji', -- NOTE: $ silicon --list-fonts
        theme = 'Visual Studio Dark+', -- NOTE: $ silicon --list-themes
        background = '#000000',
        no_round_corner = true,
        no_window_controls = true,
        tab_width = 2,
        shadow_blur_radius = 0,
        output = function() return './silicon_' .. os.date('!%Y-%m-%dT%H-%M-%S') .. '.png' end,
      }
    end,
    cond = function() return vim.fn.executable('silicon') == 1 end, -- $ cargo install silicon
  },


  -- lsp
  { 'neovim/nvim-lspconfig' },
  {
    'ray-x/lsp_signature.nvim', config = function()
      require'lsp_signature'.setup {
        bind = true,
        handler_opts = { border = 'single' },
        hi_parameter = 'CurSearch',
      }
    end,
  },
  {
    'https://git.sr.ht/~whynothugo/lsp_lines.nvim', config = function()
      local ll = require'lsp_lines'
      ll.setup()
      vim.diagnostic.config {
        virtual_lines = { only_current_line = true },
      }
      vim.keymap.set('', '<leader>ll', function()
        ll.toggle()
        vim.notify 'Toggled LSP Lines.'
      end, { desc = 'lsp_lines: Toggle' })
    end,
  },
  {
    'onsails/lspkind-nvim', config = function()
      -- (gray)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrDeprecated', {
        bg = 'NONE',
        fg = '#808080',
        strikethrough = true,
      })
      -- (blue)
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatch', {
        bg = 'NONE',
        fg = '#569CD6',
      })
      vim.api.nvim_set_hl(0, 'CmpItemAbbrMatchFuzzy', {
        bg = 'NONE',
        fg = '#569CD6',
      })
      -- (light blue)
      vim.api.nvim_set_hl(0, 'CmpItemKindVariable', {
        bg = 'NONE',
        fg = '#9CDCFE',
      })
      vim.api.nvim_set_hl(0, 'CmpItemKindInterface', {
        bg = 'NONE',
        fg = '#9CDCFE',
      })
      vim.api.nvim_set_hl(0, 'CmpItemKindText', {
        bg = 'NONE',
        fg = '#9CDCFE',
      })
      -- (pink)
      vim.api.nvim_set_hl(0, 'CmpItemKindFunction', {
        bg = 'NONE',
        fg = '#C586C0',
      })
      vim.api.nvim_set_hl(0, 'CmpItemKindMethod', {
        bg = 'NONE',
        fg = '#C586C0',
      })
      -- (front)
      vim.api.nvim_set_hl(0, 'CmpItemKindKeyword', {
        bg = 'NONE',
        fg = '#D4D4D4',
      })
      vim.api.nvim_set_hl(0, 'CmpItemKindProperty', {
        bg = 'NONE',
        fg = '#D4D4D4',
      })
      vim.api.nvim_set_hl(0, 'CmpItemKindUnit', {
        bg = 'NONE',
        fg = '#D4D4D4',
      })
    end,
  },
  {
    'williamboman/mason.nvim', config = function()
      require'mason'.setup {
        ui = {
          icons = {
            package_installed = '✓',
            package_pending = '➜',
            package_uninstalled = '✗',
          },
        },
      }
    end,
  },
  {
    'williamboman/mason-lspconfig.nvim', config = function()
      -- install lsp servers
      require'mason-lspconfig'.setup {
        ensure_installed = custom.installable_lsp_names(), -- NOTE: .config/nvim/lua/custom/lsps_sample.lua
        automatic_installation = false,
      }

      -- NOTE: no way of installing things other than lsp servers for now
      -- install other things with: :MasonInstall delve codelldb vale
    end,
  },


  -- snippets
  { 'L3MON4D3/LuaSnip', build = 'make install_jsregexp' },
  { 'rafamadriz/friendly-snippets' },


  -- autocompletion
  {
    'hrsh7th/nvim-cmp', config = function()
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
          { name = 'calc' },
          { name = 'codeium', keyword_length = 4 },
          { name = 'conjure', keyword_length = 2 },
          { name = 'luasnip', keyword_length = 2 },
          { name = 'nvim_lsp', keyword_length = 3 },
          { name = 'nvim_lua', keyword_length = 2 },
          { name = 'path' },
        },
        formatting = {
          format = lspkind.cmp_format {
            mode = 'symbol',
            maxwidth = 50,
            ellipsis_char = '...',
            symbol_map = { Codeium = '' },
          },
        },
      }

      -- setup autopairs
      cmp.event:on('confirm_done', require'nvim-autopairs.completion.cmp'.on_confirm_done())

      -- load snippets
      require'luasnip/loaders/from_vscode'.lazy_load()
    end,
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-nvim-lua',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-calc',
      'saadparwaiz1/cmp_luasnip',
    },
  },


  -- syntax highlighting and rainbow parenthesis
  --
  -- $ npm -g install tree-sitter-cli
  -- or
  -- $ cargo install tree-sitter-cli
  -- or
  -- $ brew install tree-sitter
  --
  -- NOTE: if it complains about any language, try :TSInstall [xxx]
  {
    --'nvim-treesitter/nvim-treesitter', build = ':TSUpdate', config = function()
    'nvim-treesitter/nvim-treesitter', config = function()
      require'nvim-treesitter.configs'.setup {
        ensure_installed = {
          'bash',
          'c', 'clojure', 'cmake', 'comment', 'cpp', 'css',
          'dart', 'diff', 'dockerfile',
          'eex', 'elixir',
          'fennel',
          'go', 'gomod', 'gowork', 'gitignore',
          'heex', 'html', 'http',
          'java', 'javascript', 'jq', 'jsdoc', 'json', 'json5', 'jsonc', 'julia',
          'kotlin',
          'latex', 'llvm', 'lua',
          'make', 'markdown', 'markdown_inline', 'mermaid',
          'perl', 'php', 'python',
          'query',
          'regex', 'ruby', 'rust',
          'scss', 'sql', 'swift',
          'toml', 'typescript',
          'yaml',
          'zig',
        },
        sync_install = tools.system.low_perf(), -- NOTE: asynchronous install generates too much load on tiny machines
        highlight = { enable = true },
        rainbow = {
          enable = true,
          query = 'rainbow-parens',
          strategy = require'rainbow-delimiters'.strategy.global,
        },
      }
    end,
  },
  { 'nvim-treesitter/nvim-treesitter-context' },


  -- code action: `\ca`
  { 'weilbith/nvim-code-action-menu', cmd = 'CodeActionMenu' },
  {
    'kosayoda/nvim-lightbulb', config = function()
      require'nvim-lightbulb'.setup { autocmd = { enabled = true } }
    end,
    dependencies = 'antoinemadec/FixCursorHold.nvim',
  },


  -- debug adapter
  {
    'mfussenegger/nvim-dap', config = function()
      -- dap sign icons and colors
      vim.fn.sign_define('DapBreakpoint', {
        text = '•',
        texthl = 'LspDiagnosticsSignError',
        linehl = '',
        numhl = '',
      })
      vim.fn.sign_define('DapStopped', {
        text = '',
        texthl = 'LspDiagnosticsSignInformation',
        linehl = 'DiagnosticUnderlineInfo',
        numhl = 'LspDiagnosticsSignInformation',
      })
      vim.fn.sign_define('DapBreakpointRejected', {
        text = '',
        texthl = 'LspDiagnosticsSignHint',
        linehl = '',
        numhl = '',
      })
    end,
  },
  {
    'rcarriga/nvim-dap-ui', config = function()
      local dap, dapui = require 'dap', require 'dapui'
      dapui.setup {}
      -- auto toggle debug UIs
      dap.listeners.after.event_initialized['dapui_config'] = dapui.open
      dap.listeners.before.event_terminated['dapui_config'] = dapui.close
      dap.listeners.before.event_exited['dapui_config'] = dapui.close
    end,
    dependencies = { 'mfussenegger/nvim-dap', 'nvim-neotest/nvim-nio' },
  },
  {
    'theHamsta/nvim-dap-virtual-text', config = function()
      require'nvim-dap-virtual-text'.setup { commented = true }
    end,
  },


  -- lint
  {
    'mfussenegger/nvim-lint', config = function()
      local lint = require'lint'
      lint.linters_by_ft = custom.linters()
      vim.api.nvim_create_autocmd(
        { 'BufWritePost' },
        { callback = function() lint.try_lint() end }
      )
    end,
    cond = custom.features().linter, -- .config/nvim/lua/custom/init.lua
  },


  --------------------------------
  --
  -- programming languages
  --

  -- bash
  { 'bash-lsp/bash-language-server', ft = { 'sh' } },


  -- elixir
  {
    'elixir-tools/elixir-tools.nvim',
    version = '*',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local elixirls = require'elixir.elixirls'
      require'elixir'.setup {
        nextls = { enable = false },
        credo = { enable = false },
        elixirls = {
          enable = true,
          cmd = vim.env.HOME .. '/.local/share/nvim/mason/bin/elixir-ls',
          settings = elixirls.settings {
            dialyzerEnabled = false,
            fetchDeps = true,
            enableTestLenses = true,
            suggestSpecs = true,
          },
        },
      }
    end,
    dependencies = { 'nvim-lua/plenary.nvim' },
    ft = { 'elixir' },
  },
  {
    'mhinz/vim-mix-format',
    config = function()
      vim.g['mix_format_on_save'] = 1
      vim.g['mix_format_silent_errors'] = 1
    end,
    ft = { 'elixir' },
  },


  -- go
  {
    'ray-x/go.nvim', config = function()
      require'go'.setup {
        gofmt = 'gopls',
        lsp_inlay_hints = { enable = false }, -- FIXME: inlay hints break screen
      }

      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.go',
        callback = function() require'go.format'.goimport() end,
      })
    end,
    ft = { 'go' },
  },
  { 'ray-x/guihua.lua', build = 'cd lua/fzy && make' },
  {
    -- install `delve` with :Mason, :DapContinue for starting debugging
    'leoluz/nvim-dap-go', config = function()
      require'dap-go'.setup()
    end,
    ft = { 'go' },
  },


  -- <lispy languages>
  --
  -- for auto completion: <C-x><C-o>
  -- for evaluating: \ee (current form / selection), \er (root form), \eb (current buffer), ...
  -- for reloading everything: \rr
  -- for controlling log buffer: \ls (horizontal), \lv (vertical), \lt (new tab), \lq (close all tabs), ...
  { 'Olical/conjure' },
  -- >f, <f : move a form
  -- >e, <e : move an element
  -- >), <), >(, <( : move a parenthesis
  -- <I, >I : insert at the beginning or end of a form
  -- dsf : remove surroundings
  -- cse(, cse), cseb : surround an element with parenthesis
  -- cse[, cse] : surround an element with brackets
  -- cse{, cse} : surround an element with braces
  { 'guns/vim-sexp', ft = lisps },
  { 'tpope/vim-sexp-mappings-for-regular-people', ft = lisps },
  { 'gpanders/nvim-parinfer', ft = lisps },
  { 'PaterJason/cmp-conjure', ft = lisps },
  -- (clojure)
  { 'dmac/vim-cljfmt', ft = { 'clojure' } }, -- $ go install github.com/cespare/goclj/cljfmt
  -- (fennel)
  { 'bakpakin/fennel.vim', ft = { 'fennel' } },
  -- (janet)
  -- run janet LSP with: $ janet -e '(import spork/netrepl) (netrepl/server)'
  { 'janet-lang/janet.vim', ft = { 'janet' } },


  -- nim
  { 'alaviss/nim.nvim', ft = { 'nim' } },


  -- ruby
  { 'vim-ruby/vim-ruby', ft = { 'ruby' } },
  {
    'suketa/nvim-dap-ruby', config = function()
      -- $ gem install readapt
      -- :DapContinue for debugging
      require'dap-ruby'.setup()
    end,
    ft = { 'ruby' },
  },


  -- rust
  {
    'simrat39/rust-tools.nvim',
    ft = { 'rust' },
    dependencies = {
      { 'neovim/nvim-lspconfig' },
      { 'nvim-lua/plenary.nvim' },
      { 'mfussenegger/nvim-dap' },
    },
  },


  -- zig
  { 'ziglang/zig.vim', ft = { 'zig' } },


  --------------------------------
  --
  -- my neovim lua plugins for testing & development
  --

  {
    'meinside/gemini.nvim', config = function()
      require'gemini'.setup {
        configFilepath = '~/.config/gemini.nvim/config.json',
        timeout = 30 * 1000,
        model = 'gemini-1.0-pro',
        safetyThreshold = 'BLOCK_ONLY_HIGH',
        stripOutermostCodeblock = function()
          return vim.bo.filetype ~= 'markdown'
        end,
        verbose = false, -- for debugging
      }
    end,
    dependencies = { { 'nvim-lua/plenary.nvim' } },

    -- for testing local changes
    --dir = '~/srcs/lua/gemini.nvim/',
  },

}, {
  ui = {
    icons = {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤',
    },
  },
})

----------------
-- lsp settings
lsps.setup(require'lspconfig', custom.autoconfigurable_lsp_names())  -- NOTE: ~/.config/nvim/lua/custom/lsps_sample.lua

