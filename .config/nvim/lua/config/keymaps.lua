-- .config/nvim/lua/config/keymaps.lua
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2025.04.02.

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

-- for toggling diagnostics: `\tD`
map("n", "<leader>tD", function()
	if vim.diagnostic.is_enabled() then
		vim.diagnostic.enable(false)
	else
		vim.diagnostic.enable(true)
	end
	vim.notify("Toggled diagnostics " .. (vim.diagnostic.is_enabled() and "on" or "off"))
end, { desc = "diagnostics: Toggle" })

-- <Left> for folding, <Right> for unfolding
map("n", "<Left>", require("origami").h)
map("n", "<Right>", require("origami").l)

-- (minifiles)
--
-- for toggling minifiles: `\mf`
map("n", "<leader>mf", function()
	require("mini.files").setup({})
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
map("n", "<leader>li", function()
	local enabled = not vim.lsp.inlay_hint.is_enabled({})
	vim.lsp.inlay_hint.enable(enabled)

	vim.notify("Toggled LSP inlay hints " .. (enabled and "on" or "off"))
end, { desc = "lsp: Toggle inlay hint" })

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
