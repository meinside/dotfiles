-- .config/nvim/lua/plugins/plugins.lua
--
-- File for plugins
--
-- last update: 2025.09.18.

------------------------------------------------
-- imports
--
local tools = require("tools") -- ~/.config/nvim/lua/tools.lua

return {
	-- colorschemes
	{
		"catppuccin/nvim",
		name = "catppuccin",
		opts = {
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
						CursorColumn = { bg = C.surface0 },
						CursorLine = { bg = C.surface0 },
						CursorLineNr = { fg = C.yellow, bold = true },
						Pmenu = { bg = C.none },
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
				treesitter = true,
				treesitter_context = true,
				which_key = true,
			},
		},
		priority = 1000,
		lazy = false,
	},

	-- lazyvim
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "catppuccin",
		},
	},

	-- startup time (:StartupTime)
	-- NOTE: enable 'util.startuptime' with :LazyExtras

	-- noice (for messages and notifications)
	{
		"folke/noice.nvim",
		opts = {
			presets = { lsp_doc_border = true },
		},
	},

	-- syntax highlighting
	--
	-- $ npm -g install tree-sitter-cli
	-- or
	-- $ cargo install tree-sitter-cli
	-- or
	-- $ brew install tree-sitter-cli
	--
	-- NOTE: if it complains about any language, try :TSInstall [xxx]
	{
		"nvim-treesitter/nvim-treesitter",
		opts = function(_, opts)
			return {
				-- https://github.com/nvim-treesitter/nvim-treesitter#supported-languages
				ensure_installed = {
					"asm",
					"bash",
					"c",
					"clojure",
					"cmake",
					"comment",
					"cpp",
					"css",
					"csv",
					"dart",
					"diff",
					"dockerfile",
					"eex",
					"elixir",
					"erlang",
					"fennel",
					"fish",
					"git_config",
					"git_rebase",
					"gitattributes",
					"gitcommit",
					"gitignore",
					"go",
					"gomod",
					"gosum",
					"gowork",
					"gpg",
					"heex",
					"html",
					"http",
					"ini",
					"janet_simple",
					"java",
					"javadoc",
					"javascript",
					"jq",
					"jsdoc",
					"json",
					"json5",
					"jsonc",
					"kotlin",
					"latex",
					"llvm",
					"lua",
					"make",
					"markdown",
					"markdown_inline",
					"mermaid",
					"meson",
					"nasm",
					"nginx",
					"nim",
					"perl",
					"php",
					"printf",
					"python",
					"query",
					"regex",
					"ruby",
					"rust",
					"scss",
					"sql",
					"ssh_config",
					"strace",
					"swift",
					"tmux",
					"toml",
					"typescript",
					"xml",
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
			}
		end,
	},
	-- `:TSContext toggle` for toggling
	{ "nvim-treesitter/nvim-treesitter-context" },

	-- color column
	{
		"m4xshen/smartcolumn.nvim",
		opts = {
			colorcolumn = "80",
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
				"noice",
				"NvimTree",
				"Trouble",
			},
			scope = "line",
		},
	},

	-- dim inactive window
	{
		"levouh/tint.nvim",
		config = function()
			require("tint").setup({
				tint = -60, -- darker than default (-45)
			})
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
		"nvim-mini/mini.map",
		version = "*",
		config = function()
			require("mini.map").setup()
		end,
	},

	-- relative/absolute linenumber toggling
	{ "cpea2506/relative-toggle.nvim" },

	-- d2
	-- * \d2 for viewing .d2 file content in a preview pane
	-- * \rd2 for replacing selected text into a diagram
	{ "terrastruct/d2-vim" },

	-- fold
	{
		"chrisgrieser/nvim-origami",
		event = "VeryLazy",
		opts = {
			foldKeymaps = {
				setup = false,
				hOnlyOpensOnFirstColumn = false,
			},
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
	{ "tpope/vim-ragtag" }, -- TAG + <ctrl-x> + @, !, #, $, /, <space>, <cr>, ...
	{ "tpope/vim-sleuth" },
	{
		"HiPhish/rainbow-delimiters.nvim",
		config = function()
			require("rainbow-delimiters.setup").setup({
				strategy = {
					[""] = require("rainbow-delimiters").strategy["global"],
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
		event = "VeryLazy",
		opts = {
			force_write_shada = true,
		},
	},

	-- annotation
	-- NOTE: enable 'coding.neogen' with :LazyExtras

	-- finder / locator
	{ "mtth/locate.vim" }, -- :L [query], :lclose, gl
	{ "johngrib/vim-f-hangul" }, -- can use f/t/;/, on Hangul characters
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
		cond = tools.system.not_termux(), -- do not load in termux
	},

	-- git
	{
		-- NOTE: doesn't work if 'editor.mini-diff' is enabled with :LazyExtras
		--
		-- [c, ]c for prev/next hunk, \hp for preview, \hs for stage, \hu for undo
		"lewis6991/gitsigns.nvim",
		opts = {
			on_attach = function(buffer)
				local gs = package.loaded.gitsigns

				local function map(mode, l, r, desc)
					vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
				end

				-- Navigation
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gs.nav_hunk("next")
					end
				end, "gitsigns: Next hunk")
				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gs.nav_hunk("prev")
					end
				end, "gitsigns: Previous hunk")

				-- Actions
				map("n", "<leader>hs", gs.stage_hunk, "gitsigns: Stage hunk")
				map("n", "<leader>hr", gs.reset_hunk, "gitsigns: Reset hunk")
				map({ "n", "v" }, "<leader>hs", function()
					gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "gitsigns: Stage hunk")
				map({ "n", "v" }, "<leader>hr", function()
					gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "gitsigns: Reset hunk")
				map("n", "<leader>hS", gs.stage_buffer, "gitsigns: Stage buffer")
				map("n", "<leader>hR", gs.reset_buffer, "gitsigns: Reset buffer")
				map("n", "<leader>hp", gs.preview_hunk, "gitsigns: Preview hunk")
				map("n", "<leader>hi", gs.preview_hunk_inline, "gitsigns: Preview hunk inline")
				map("n", "<leader>hb", function()
					gs.blame_line({ full = true })
				end, "gitsigns: Blame line")
				map("n", "<leader>hd", gs.diffthis, "gitsigns: Diff this")
				map("n", "<leader>hD", function()
					gs.diffthis("~")
				end, "gitsigns: Diff this ~")
				map("n", "<leader>hQ", function()
					gs.setqflist("all")
				end, "gitsigns: Set quickfix list all")
				map("n", "<leader>hq", gs.setqflist, "gitsigns: Set quickfix list")
				map("n", "<leader>tb", gs.toggle_current_line_blame, "gitsigns: Toggle blame")
				map("n", "<leader>td", gs.toggle_deleted, "gitsigns: Toggle deleted")
				map("n", "<leader>tw", gs.toggle_word_diff, "gitsigns: Toggle word diff")

				-- Text object
				map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "gitsigns: Select hunk")
			end,
		},
	},
	{
		"NeogitOrg/neogit", -- :Neogit xxx
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
			"folke/snacks.nvim",
		},
		config = true,
		opts = { graph_style = "kitty" }, -- NOTE: kitty or wezterm + flog symbols font is needed
	},
	-- gist (:Gist / :Gist -p / ...)
	{ "mattn/webapi-vim" },
	{ "mattn/gist-vim" },

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

	--------------------------------
	--
	-- my neovim lua plugins for testing & development
	--
	-- (will be placed here)
}
