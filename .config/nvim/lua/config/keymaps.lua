-- .config/nvim/lua/config/keymaps.lua
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2025.01.02.

-- DO NOT USE `LazyVim.safe_keymap_set` IN YOUR OWN CONFIG!!
-- use `vim.keymap.set` instead
local map = LazyVim.safe_keymap_set

-- tab navigations
map("n", "<C-h>", ":tabprevious<CR>", {
	desc = "Previous tab",
}) -- <ctrl-h> for previous tab
map("n", "<C-l>", ":tabnext<CR>", {
	desc = "Next tab",
}) -- <ctrl-l> for next tab

-- for toggling mouse: `\mm`
map("n", "<leader>mm", function()
	require("tools").ui.toggle_mouse() -- ~/.config/nvim/lua/tools.lua
end, { desc = "mouse: Toggle" })

-- <Left> for folding, <Right> for unfolding
local origami = require("origami")
map("n", "<Left>", origami.h)
map("n", "<Right>", origami.l)

-- (minifiles)
--
-- for toggling minifiles: `\mf`
map("n", "<leader>mf", function()
	MiniFiles.open()
end, { desc = "mini-files: Open" })

-- (telescope)
--
-- https://github.com/nvim-telescope/telescope.nvim#pickers
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

-- (lsp)
--
-- for toggling inlay hint: `\li`
map("n", "<leader>li", "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<CR>", {
	desc = "lsp: Toggle inlay hint",
})
-- for toggling lsp_lines: `\tl`
map("", "<leader>tl", function()
	require("lsp_lines").toggle()
	vim.notify("Toggled LSP Lines.")
end, { desc = "lsp_lines: Toggle" })

-- (minimap)
--
-- for toggling minimap: `\tm`
map("n", "<leader>tm", function()
	require("codewindow").toggle_minimap()
	vim.notify("Toggled minimap.")
end, { desc = "minimap: Toggle" })

-- (code actions)
--
-- `\ca` for showing code action previews
map({ "v", "n" }, "ca", require("actions-preview").code_actions, { desc = "actions-preview: Code actions" })

-- (codeium)
--
-- alt-e: cycle through suggestions
map("i", "<A-e>", function()
	if require("custom").features().codeium then
		require("neocodeium").cycle_or_complete()
	end
end, { desc = "Neocodeium: Cycle through suggestions" })
-- alt-f: accept
map("i", "<A-f>", function()
	if require("custom").features().codeium then
		require("neocodeium").accept()
	end
end, { desc = "Neocodeium: Accept suggestion" })

-- NOTE: override/delete unwanted default keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
