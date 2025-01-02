-- .config/nvim/lua/config/keymaps.lua
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2025.01.02.

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

-- for toggling inlay hint: `\li`
map("n", "<leader>li", "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>", {
	desc = "lsp: Toggle inlay hint",
})

-- for toggling mouse: `\mm`
map("n", "<leader>mm", function()
	require("tools").ui.toggle_mouse() -- ~/.config/nvim/lua/tools.lua
end, { desc = "mouse: Toggle" })

-- NOTE: override unwanted default keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
