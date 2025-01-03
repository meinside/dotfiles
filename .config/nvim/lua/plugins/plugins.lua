-- .config/nvim/lua/plugins/plugins.lua
--
-- last update: 2025.01.03.

------------------------------------------------
-- imports
--
local tools = require("tools") -- ~/.config/nvim/lua/tools.lua

return {
	-- lazyvim
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},

	-- startup time (:StartupTime)
	-- NOTE: enable 'util.startuptime' in :LazyExtras

	-- colorschemes
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				transparent_background = true,
				flavour = "mocha",
				term_colors = true,
				styles = {
					comments = { "italic" },
					conditionals = { "italic" },
					loops = { "italic" },
					functions = { "italic" },
					keywords = { "italic" },
					strings = {},
					variables = {},
					numbers = {},
					booleans = {},
					properties = {},
					types = {},
				},
				color_overrides = {
					mocha = {
						base = "#000000",
						mantle = "#000000",
						crust = "#000000",
					},
				},
				highlight_overrides = {
					mocha = function(C)
						return {
							CmpBorder = { fg = C.surface2 },
							CursorLine = { bg = "#423030" },
							Pmenu = { bg = C.none },
							TelescopeBorder = { link = "FloatBorder" },
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
			})
			vim.cmd.colorscheme("catppuccin")
		end,
	},

	-- override nvim-cmp and add cmp-emoji
	{
		"hrsh7th/nvim-cmp",
		dependencies = { "hrsh7th/cmp-emoji" },
		---@param opts cmp.ConfigSchema
		opts = function(_, opts)
			table.insert(opts.sources, { name = "emoji" })
		end,
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
		"nvim-treesitter/nvim-treesitter",
		config = function()
			require("nvim-treesitter.configs").setup({
				ensure_installed = {
					"bash",
					"c",
					"clojure",
					"cmake",
					"comment",
					"cpp",
					"css",
					"dart",
					"diff",
					"dockerfile",
					"eex",
					"elixir",
					"fennel",
					"go",
					"gomod",
					"gowork",
					"gitignore",
					"heex",
					"html",
					"http",
					"java",
					"javascript",
					"jq",
					"jsdoc",
					"json",
					"json5",
					"jsonc",
					"julia",
					"kotlin",
					"latex",
					"llvm",
					"lua",
					"make",
					"markdown",
					"markdown_inline",
					"mermaid",
					"perl",
					"php",
					"python",
					"query",
					"regex",
					"ruby",
					"rust",
					"scss",
					"sql",
					"swift",
					"toml",
					"typescript",
					"yaml",
					"zig",
				},
				sync_install = tools.system.low_perf(), -- NOTE: asynchronous install generates too much load on tiny machines
				highlight = { enable = true },
				rainbow = {
					enable = true,
					query = "rainbow-parens",
					strategy = require("rainbow-delimiters").strategy.global,
				},
			})
		end,
	},
	-- :TSContextToggle for toggling
	{ "nvim-treesitter/nvim-treesitter-context" },

	-- use mini.starter instead of alpha
	{ import = "lazyvim.plugins.extras.ui.mini-starter" },

	-- add jsonls and schemastore packages, and setup treesitter for json, json5 and jsonc
	{ import = "lazyvim.plugins.extras.lang.json" },

	-- color column
	{
		"m4xshen/smartcolumn.nvim",
		opts = {
			custom_colorcolumns = {},
			disabled_filetypes = {
				-- common
				"checkhealth",
				"gitcommit",
				"help",
				"lspinfo",
				"zsh",
				-- file types
				"text",
				"markdown",
				-- plugins
				"lazy",
				"mason",
				"NvimTree",
				"TelescopePrompt",
				"Trouble",
			},
			scope = "line",
		},
	},

	-- file browser
	{
		"echasnovski/mini.files",
		version = false,
		config = function()
			require("mini.files").setup({})
		end,
	},

	-- flash cursor location
	{ "danilamihailov/beacon.nvim" },

	-- dim inactive window
	{
		"levouh/tint.nvim",
		config = function()
			require("tint").setup({
				tint = -60, -- darker than default (-45)
			})
		end,
	},

	-- remember the last cursor position
	{
		"vladdoster/remember.nvim",
		config = function()
			require("remember")
		end,
	},

	-- breadcrumbs
	{
		"Bekaboo/dropbar.nvim",
		dependencies = { "nvim-telescope/telescope-fzf-native.nvim" },
	},

	-- split/join blocks of code (<space>m - toggle, <space>j - join, <space>s - split)
	{
		"Wansmer/treesj",
		config = function()
			require("treesj").setup({
				max_join_length = 240,
			})
		end,
		dependencies = { "nvim-treesitter" },
	},

	-- minimap
	{
		"gorbit99/codewindow.nvim",
		config = function()
			local codewindow = require("codewindow")
			codewindow.setup({})
		end,
	},

	-- relative/absolute linenumber toggling
	{ "cpea2506/relative-toggle.nvim" },

	-- markdown preview
	{
		"iamcco/markdown-preview.nvim",
		build = "cd app && npm install",
		ft = { "markdown" },
		cond = tools.system.is_macos(), -- NOTE: only on macOS
	},

	-- d2
	{ "terrastruct/d2-vim", ft = { "d2" } },

	-- fold
	{
		-- `zM` for closing all, `zR` for opening all
		-- `zc` for closing, `zo` for opening, `za` for toggling
		"kevinhwang91/nvim-ufo",
		dependencies = { "kevinhwang91/promise-async" },
	},
	{
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {
			setupFoldKeymaps = false,
		},
	},

	-- formatting
	{
		-- cs'" => change ' to " / ds" => remove " / ysiw" => wrap text object with " / yss" => wrap line with "
		"kylechui/nvim-surround",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end,
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		config = function()
			-- multiple indent colors
			local highlight = {
				"RainbowRed",
				"RainbowYellow",
				"RainbowBlue",
				"RainbowOrange",
				"RainbowGreen",
				"RainbowViolet",
				"RainbowCyan",
			}
			local hooks = require("ibl.hooks")
			hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
				vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
				vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
				vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
				vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
				vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
				vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
				vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
			end)

			vim.g.rainbow_delimiters = { highlight = highlight } -- NOTE: integrate with rainbow-delimiters
			require("ibl").setup({ scope = { highlight = highlight } })
			hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
		end,
	},
	{ "tpope/vim-ragtag" }, -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
	{ "tpope/vim-sleuth" },
	{
		"HiPhish/rainbow-delimiters.nvim",
		config = function()
			local rd = require("rainbow-delimiters")
			require("rainbow-delimiters.setup").setup({
				strategy = {
					[""] = rd.strategy["global"],
				},
				query = {
					[""] = "rainbow-delimiters",
				},
			})
		end,
	},

	-- marks
	{
		"chentoast/marks.nvim",
		config = function()
			require("marks").setup({ force_write_shada = true })
		end,
	},

	-- annotation
	{
		"danymat/neogen", -- create annotations with :Neogen
		config = function()
			require("neogen").setup({ snippet_engine = "luasnip" })
		end,
		dependencies = "nvim-treesitter/nvim-treesitter",
	},

	-- finder / locator
	{ "mtth/locate.vim" }, -- :L [query], :lclose, gl
	{ "johngrib/vim-f-hangul" }, -- can use f/t/;/, on Hangul characters
	{
		"nvim-telescope/telescope.nvim",
		config = function()
			local telescope = require("telescope")
			telescope.setup({
				extensions = {
					fzf = {
						fuzzy = true, -- false will only do exact matching
						override_generic_sorter = true, -- override the generic sorter
						override_file_sorter = true, -- override the file sorter
						case_mode = "smart_case", -- or "ignore_case" or "respect_case"
					},
				},
			})
			local _, _ = pcall(function()
				telescope.load_extension("fzf")
			end)
		end,
		dependencies = {
			{ "nvim-lua/popup.nvim" },
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope-fzf-native.nvim" },
		},
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
		cond = tools.system.not_termux(), -- do not load in termux
	},
	{
		"nvim-telescope/telescope-frecency.nvim", -- :Telescope frecency
		config = function()
			require("telescope").load_extension("frecency")
		end,
	},
	{
		-- :Telescope lazy
		"nvim-telescope/telescope.nvim",
		dependencies = "tsakirist/telescope-lazy.nvim",
	},

	-- git
	{
		-- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				numhl = true,
				on_attach = function(bufnr)
					local gitsigns = require("gitsigns")
					local function map(mode, l, r, opts)
						opts = opts or {}
						opts.buffer = bufnr
						vim.keymap.set(mode, l, r, opts)
					end

					-- Navigation
					map("n", "]c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "]c", bang = true })
						else
							gitsigns.nav_hunk("next")
						end
					end, { desc = "gitsigns: Next hunk" })
					map("n", "[c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "[c", bang = true })
						else
							gitsigns.nav_hunk("prev")
						end
					end, { desc = "gitsigns: Previous hunk" })

					-- Actions
					map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "gitsigns: Stage hunk" })
					map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "gitsigns: Reset hunk" })
					map("v", "<leader>hs", function()
						gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "gitsigns: Stage hunk" })
					map("v", "<leader>hr", function()
						gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "gitsigns: Reset hunk" })
					map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "gitsigns: Stage buffer" })
					map("n", "<leader>hu", gitsigns.undo_stage_hunk, { desc = "gitsigns: Undo stage hunk" })
					map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "gitsigns: Reset buffer" })
					map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "gitsigns: Preview hunk" })
					map("n", "<leader>hb", function()
						gitsigns.blame_line({ full = true })
					end, { desc = "gitsigns: Blame line" })
					map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "gitsigns: Toggle blame" })
					map("n", "<leader>hd", gitsigns.diffthis, { desc = "gitsigns: Diff this" })
					map("n", "<leader>hD", function()
						gitsigns.diffthis("~")
					end, { desc = "gitsigns: Diff this ~" })
					map("n", "<leader>td", gitsigns.toggle_deleted, { desc = "gitsigns: Toggle deleted" })

					-- Text object
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", { desc = "gitsigns: Select hunk" })
				end,
			})
		end,
		dependencies = { { "nvim-lua/plenary.nvim" } },
	},
	{
		"NeogitOrg/neogit", -- :Neogit xxx
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
			"nvim-telescope/telescope.nvim",
		},
		config = true,
		opts = { graph_style = "kitty" }, -- NOTE: kitty or wezterm + flog symbols font is needed
	},
	-- gist (:Gist / :Gist -p / ...)
	{ "mattn/webapi-vim" },
	{ "mattn/gist-vim" },

	-- statusline
	{
		"linrongbin16/lsp-progress.nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lsp-progress").setup()
		end,
	},

	-- tabline
	{
		"crispgm/nvim-tabline",
		config = function()
			require("tabline").setup({
				show_index = false,
				show_modify = true,
				show_icon = true,
				modify_indicator = "*",
				no_name = "<untitled>",
				brackets = { "", "" },
			})
		end,
		dependencies = { "nvim-tree/nvim-web-devicons" },
	},
}
