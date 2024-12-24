-- .config/nvim/lua/config/keymaps.lua
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2024.12.24.

-- DO NOT USE `LazyVim.safe_keymap_set` IN YOUR OWN CONFIG!!
-- use `vim.keymap.set` instead
local map = LazyVim.safe_keymap_set

-- tab navigation
map("n", "<C-h>", ":tabprevious<CR>", {
	desc = "Previous tab",
}) -- <ctrl-h> for previous tab
map("n", "<C-l>", ":tabnext<CR>", {
	desc = "Next tab",
}) -- <ctrl-l> for next tab

-- telescope (https://github.com/nvim-telescope/telescope.nvim#pickers)
local builtin = require("telescope.builtin")
map("n", "<leader>tt", builtin.builtin, {
	desc = "telescope: List builtin pickers",
})
map("n", "<leader>ff", builtin.find_files, {
	desc = "telescope: Find files",
})
map("n", "<leader>gc", builtin.git_commits, {
	desc = "telescope: Git commits",
})
map("n", "<leader>qf", builtin.quickfix, {
	desc = "telescope: Quickfix",
})

-- NOTE: override unwanted default keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
