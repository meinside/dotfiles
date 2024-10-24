-- .config/nvim/lua/plugins.lua
--
-- Neovim plugins list
--
-- NOTE: this will be sourced from: ~/.config/nvim/init.lua
--
-- last update: 2024.10.24.


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
if not vim.uv.fs_stat(lazypath) then
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
          beacon = true,
          cmp = true,
          dap = true,
          dap_ui = true,
          dropbar = {
            enabled = true,
            color_mode = true,
          },
          gitsigns = true,
          lsp_trouble = true,
          mason = true,
          neogit = true,
          notify = true,
          rainbow_delimiters = true,
          telescope = {
            enabled = true,
          },
          treesitter = true,
          treesitter_context = true,
          which_key = true,
        },
      }
      vim.cmd.colorscheme 'catppuccin'
    end,
  },


  -- file browser
  {
    'echasnovski/mini.files',
    version = false,
    config = function()
      require'mini.files'.setup {}

      -- for toggling minifiles: \mf
      vim.keymap.set('n', '<leader>mf', function()
        MiniFiles.open()
      end, { remap = false, silent = true, desc = 'mini-files: Open' })
    end,
  },


  -- notification
  {
    'rcarriga/nvim-notify', -- for viewing the history, :Telescope notify
    config = function()
      local notify = require'notify'
      notify.setup { background_colour = '#000000' }
      vim.notify = notify -- override `vim.notify`
    end,
    event = 'VeryLazy',
  },


  -- flash cursor location
  { 'danilamihailov/beacon.nvim' },


  -- dim unused things (LSP)
  {
    'zbirenbaum/neodim',
    event = 'LspAttach',
    config = function()
      require'neodim'.setup {
        alpha = 0.75,
        blend_color = '#000000',
        hide = {
          signs = true,
          underline = true,
          virtual_text = true,
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
  },


  -- show keymaps
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    keys = {
      {
        '<leader>?',
        function()
          require'which-key'.show { global = false }
        end,
        desc = 'Buffer Local Keymaps (which-key)',
      },
    },
  },


  -- dim inactive window
  {
    'levouh/tint.nvim',
    config = function()
      require'tint'.setup {
        tint = -60, -- darker than default (-45)
      }
    end
  },


  -- remember the last cursor position
  {
    'vladdoster/remember.nvim',
    config = function()
      require'remember'
    end,
  },


  -- breadcrumbs
  {
    'Bekaboo/dropbar.nvim',
    dependencies = { 'nvim-telescope/telescope-fzf-native.nvim' }
  },


  -- split/join blocks of code (<space>m - toggle, <space>j - join, <space>s - split)
  {
    'Wansmer/treesj',
    config = function()
      require'treesj'.setup {
        max_join_length = 240,
      }
    end,
    dependencies = { 'nvim-treesitter' },
  },


  -- minimap
  {
    'gorbit99/codewindow.nvim',
    config = function()
      local codewindow = require'codewindow'
      codewindow.setup {}

      -- for toggling minimap: `\tm`
      vim.keymap.set('n', '<leader>tm', function()
        codewindow.toggle_minimap()
        vim.notify 'Toggled minimap.'
      end, { remap = false, silent = true, desc = 'minimap: Toggle' })
    end,
  },


  -- relative/absolute linenumber toggling
  { 'cpea2506/relative-toggle.nvim' },


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
    -- FIXME: https://github.com/anuvyklack/pretty-fold.nvim/issues/38
    --'anuvyklack/pretty-fold.nvim',
    'bbjornstad/pretty-fold.nvim',
    config = function()
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
    'kylechui/nvim-surround',
    event = 'VeryLazy',
    config = function()
      require'nvim-surround'.setup {}
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    config = function()
      -- multiple indent colors
      local highlight = { 'RainbowRed', 'RainbowYellow', 'RainbowBlue', 'RainbowOrange', 'RainbowGreen', 'RainbowViolet', 'RainbowCyan' }
      local hooks = require'ibl.hooks'
      hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
        vim.api.nvim_set_hl(0, 'RainbowRed', { fg = '#E06C75' })
        vim.api.nvim_set_hl(0, 'RainbowYellow', { fg = '#E5C07B' })
        vim.api.nvim_set_hl(0, 'RainbowBlue', { fg = '#61AFEF' })
        vim.api.nvim_set_hl(0, 'RainbowOrange', { fg = '#D19A66' })
        vim.api.nvim_set_hl(0, 'RainbowGreen', { fg = '#98C379' })
        vim.api.nvim_set_hl(0, 'RainbowViolet', { fg = '#C678DD' })
        vim.api.nvim_set_hl(0, 'RainbowCyan', { fg = '#56B6C2' })
      end)

      vim.g.rainbow_delimiters = { highlight = highlight } -- NOTE: integrate with rainbow-delimiters
      require'ibl'.setup { scope = { highlight = highlight } }
      hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
    end,
  },
  { 'tpope/vim-ragtag' }, -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
  { 'tpope/vim-sleuth' },
  {
    'HiPhish/rainbow-delimiters.nvim',
    config = function()
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
    'chentoast/marks.nvim',
    config = function()
      require'marks'.setup {
        force_write_shada = true, -- FIXME: marks are not removed across sessions without this configuration
      }
    end,
  },


  -- annotation
  {
    'danymat/neogen', -- create annotations with :Neogen
    config = function()
      require'neogen'.setup { snippet_engine = 'luasnip' }
    end,
    dependencies = 'nvim-treesitter/nvim-treesitter',
  },


  -- finder / locator
  { 'mtth/locate.vim' }, -- :L [query], :lclose, gl
  { 'johngrib/vim-f-hangul' },	-- can use f/t/;/, on Hangul characters
  {
    'nvim-telescope/telescope.nvim',
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
  {
    'nvim-telescope/telescope-frecency.nvim', -- :Telescope frecency
    config = function()
      require'telescope'.load_extension 'frecency'
    end,
  },
  {
    -- :Telescope lazy
    'nvim-telescope/telescope.nvim',
    dependencies = 'tsakirist/telescope-lazy.nvim',
  },


  -- git
  {
    -- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
    'lewis6991/gitsigns.nvim',
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
          m({ 'n', 'v' }, '<leader>hs', ':Gitsigns stage_hunk<CR>', { desc = 'gitsigns: Stage hunk' })
          m({ 'n', 'v' }, '<leader>hr', ':Gitsigns reset_hunk<CR>', { desc = 'gitsigns: Reset hunk' })
          m('n', '<leader>hS', gs.stage_buffer, { desc = 'gitsigns: Stage buffer' })
          m('n', '<leader>hu', gs.undo_stage_hunk, { desc = 'gitsigns: Undo stage hunk' })
          m('n', '<leader>hR', gs.reset_buffer, { desc = 'gitsigns: Reset buffer' })
          m('n', '<leader>hp', gs.preview_hunk, { desc = 'gitsigns: Preview hunk' })
          m('n', '<leader>hb', function() gs.blame_line { full = true } end, { desc = 'gitsigns: Blame line' })
          m('n', '<leader>tb', gs.toggle_current_line_blame, { desc = 'gitsigns: Toggle current line blame' })
          m('n', '<leader>hd', gs.diffthis, { desc = 'gitsigns: Diff this' })
          m('n', '<leader>hD', function() gs.diffthis('~') end, { desc = 'gitsigns: Diff this ~' })
          m('n', '<leader>td', gs.toggle_deleted, { desc = 'gitsigns: Toggle deleted' })

          -- Text object
          m({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
        end,
      }
    end,
    dependencies = { { 'nvim-lua/plenary.nvim' } },
  },
  {
    'NeogitOrg/neogit', -- :Neogit xxx
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim',
      'nvim-telescope/telescope.nvim',
    },
    config = true,
  },
  -- gist (:Gist / :Gist -p / ...)
  { 'mattn/webapi-vim' },
  { 'mattn/gist-vim' },


  -- statusline
  {
    'linrongbin16/lsp-progress.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require'lsp-progress'.setup()
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    config = function()
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
          },
        },
      }
    end,
    dependencies = { 'nvim-tree/nvim-web-devicons', 'linrongbin16/lsp-progress.nvim' },
  },


  -- tabline
  {
    'crispgm/nvim-tabline',
    config = function()
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
    'folke/trouble.nvim',
    cmd = 'Trouble',
    opts =  {
      modes = {
        diagnostics = {
          auto_close = true,
        },
      },
    },
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },


  -- auto pair/close
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = true,
  },


  -- code generation & completion
  {
    'monkoose/neocodeium',  -- :NeoCodeium auth
    event = 'VeryLazy',
    config = function()
      local neocodeium = require'neocodeium'
      local cmp = require'cmp'
      neocodeium.setup {
        manual = true, -- for nvim-cmp
        filter = function(bufnr)
          if vim.tbl_contains({ -- NOTE: enable neocodeium only for these file types
            'c', 'clojure', 'cmake', 'cpp', 'css',
            'elixir',
            'fennel',
            'go', 'gomod', 'gowork',
            'html',
            'java', 'javascript', 'janet',
            'lua',
            'python',
            'ruby', 'rust',
            'sh',
            'zig',
          }, vim.api.nvim_get_option_value('filetype',  { buf = bufnr })) then
            return true
          end
          return not cmp.visible()
        end,
        filetypes = {
          ['.'] = false,
          ['dap-repl'] = false,
          DressingInput = false,
          gitcommit = false,
          gitrebase = false,
          help = false,
          TelescopePrompt = false,
        },
        root_dir = {
          '.bzr', '.git', '.hg', '.svn',
          'build.zig',
          'Cargo.toml',
          'Gemfile', 'go.mod',
          'package.json', 'project.clj', 'project.janet',
        },
      }

      -- create an autocommand which closes nvim-cmp when completions are displayed
      vim.api.nvim_create_autocmd('User', {
        pattern = 'NeoCodeiumCompletionDisplayed',
        callback = require'cmp'.abort,
      })

      -- alt-e/E: cycle or complete
      vim.keymap.set('i', '<A-e>', neocodeium.cycle_or_complete)
      vim.keymap.set('i', '<A-E>', function() neocodeium.cycle_or_complete(-1) end)
      -- alt-f: accept
      vim.keymap.set('i', '<A-f>', neocodeium.accept)
    end,
    dependencies = {
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


  -- symbol outlines
  {
    'hedyhli/outline.nvim',
    lazy = true,
    cmd = { 'Outline', 'OutlineOpen' },
    keys = { { '<leader>to', '<cmd>Outline<CR>', desc = 'symbols outline: Toggle' } },
    opts = { },
  },


  -- todo comments
  {
    'folke/todo-comments.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { },
  },


  -- lsp
  { 'neovim/nvim-lspconfig' },
  {
    'ray-x/lsp_signature.nvim',
    event = 'VeryLazy',
    opts = {
      bind = true,
      handler_opts = { border = 'single' },
      hi_parameter = 'CurSearch',
    },
    config = function(_, opts)
      require'lsp_signature'.setup(opts)
    end,
  },
  {
    'https://git.sr.ht/~whynothugo/lsp_lines.nvim',
    config = function()
      local ll = require'lsp_lines'
      ll.setup()
      vim.diagnostic.config {
        virtual_text = false,
        virtual_lines = {
          only_current_line = true,
          highlight_whole_line = false,
        },
      }
      -- FIXME: https://github.com/folke/lazy.nvim/issues/620
      vim.diagnostic.config({ virtual_lines = false }, require'lazy.core.config'.ns)
      -- for toggling lsp_lines: `\tl`
      vim.keymap.set('', '<leader>tl', function()
        ll.toggle()
        vim.notify 'Toggled LSP Lines.'
      end, { desc = 'lsp_lines: Toggle' })
    end,
  },
  {
    'onsails/lspkind-nvim',
    config = function()
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
    'williamboman/mason.nvim',
    config = function()
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
    'williamboman/mason-lspconfig.nvim',
    config = function()
      -- install lsp servers
      require'mason-lspconfig'.setup {
        ensure_installed = custom.installable_lsp_names(), -- NOTE: .config/nvim/lua/custom/lsps_sample.lua
        automatic_installation = false,
      }
    end,
  },


  -- snippets
  {
    'L3MON4D3/LuaSnip',
    build = 'make install_jsregexp',
    config = function()
      require'luasnip.loaders.from_vscode'.lazy_load()
    end,
    dependencies = { 'rafamadriz/friendly-snippets' },
  },


  -- autocompletion
  {
    'hrsh7th/nvim-cmp',
    config = function()
      local cmp = require'cmp'
      local luasnip = require'luasnip'
      local lspkind = require'lspkind'

      local neocodeium = nil
      if custom.features().codeium then -- .config/nvim/lua/custom/init.lua
        neocodeium = require'neocodeium'
      end

      cmp.setup {
        completion = {
          completeopt = 'menu,menuone,noselect',
        },
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
            show_labelDetails = true,
            symbol_map = { },
          },
        },
      }

      -- setup for neocodeium
      if neocodeium ~= nil then
        cmp.event:on('menu_opened', function()
          neocodeium.clear()
        end)
        cmp.event:on('menu_closed', function()
          neocodeium.cycle_or_complete()
        end)
      end

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
    'nvim-treesitter/nvim-treesitter',
    config = function()
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
  -- :TSContextToggle for toggling
  { 'nvim-treesitter/nvim-treesitter-context' },


  -- code actions
  --
  -- `\ca` for showing code action previews
  {
    'aznhe21/actions-preview.nvim',
    config = function()
      local ap = require'actions-preview'
      ap.setup {
        diff = {
          algorithm = 'patience',
          ignore_whitespace = true,
        },
        telescope = require'telescope.themes'.get_dropdown { winblend = 10 },
      }
      vim.keymap.set({ 'v', 'n' }, 'ca', ap.code_actions)
    end,
  },
  {
    'kosayoda/nvim-lightbulb',
    config = function()
      require'nvim-lightbulb'.setup {
        autocmd = { enabled = true },
        code_lenses = true,
      }
    end,
  },


  -- debug adapter
  {
    'mfussenegger/nvim-dap',
    lazy = true,
    config = function()
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
    'jay-babu/mason-nvim-dap.nvim',
    config = function()
      require'mason-nvim-dap'.setup {
        ensure_installed = custom.installable_debugger_names(), -- NOTE: .config/nvim/lua/custom/debuggers_sample.lua
        automatic_installation = false,
      }
    end,
  },
  {
    'rcarriga/nvim-dap-ui',
    config = function()
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
    'theHamsta/nvim-dap-virtual-text',
    config = function()
      require'nvim-dap-virtual-text'.setup { commented = true }
    end,
  },


  -- lint
  {
    'mfussenegger/nvim-lint',
    config = function()
      local lint = require'lint'
      lint.linters_by_ft = custom.linters() -- .config/nvim/lua/custom/linters_sample.lua
      vim.api.nvim_create_autocmd({ 'BufWritePost' }, { callback = function() lint.try_lint() end })
    end,
    cond = custom.features().linter, -- .config/nvim/lua/custom/init.lua
  },


  -- coding assistants
  -- TODO: ...


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
    'ray-x/go.nvim',
    config = function()
      require'go'.setup {
        lsp_inlay_hints = { enable = false },

        trouble = true, -- NOTE: using folke/trouble.nvim
        luasnip = true, -- NOTE: using L3MON4D3/LuaSnip
      }

      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.go',
        callback = function() require'go.format'.goimports() end,
        group = vim.api.nvim_create_augroup('GoFormat', {}),
      })
    end,
    event = { 'CmdlineEnter' },
    ft = { 'go', 'gomod' },
    build = ':lua require("go.install").update_all_sync()',
    dependencies = {
      'ray-x/guihua.lua',
      'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter',
    },
  },
  {
    -- install `delve` with :Mason, :DapContinue for starting debugging
    'leoluz/nvim-dap-go',
    config = function()
      require'dap-go'.setup()
    end,
    ft = { 'go' },
  },
  {
    'catgoose/templ-goto-definition',
    ft = { 'go' },
    config = true,
    dependenciies = 'nvim-treesitter/nvim-treesitter',
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
    'suketa/nvim-dap-ruby',
    config = function()
      -- $ gem install readapt
      -- :DapContinue for debugging
      require'dap-ruby'.setup()
    end,
    ft = { 'ruby' },
  },


  -- rust
  {
    'mrcjkb/rustaceanvim',
    ft = { 'rust' },
    version = '^5',
    lazy = false,
    config = function()
      -- :RustFmt on save
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.rs',
        callback = function() vim.lsp.buf.format { async = false } end,
      })
    end,
  },


  -- zig
  { 'ziglang/zig.vim', ft = { 'zig' } },


  --------------------------------
  --
  -- my neovim lua plugins for testing & development
  --

  {
    'meinside/gemini.nvim',
    config = function()
      require'gemini'.setup {
        configFilepath = '~/.config/gemini.nvim/config.json',
        timeout = 30 * 1000,
        model = 'gemini-1.5-flash-latest',
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

