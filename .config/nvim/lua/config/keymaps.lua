-- .config/nvim/lua/config/keymaps.lua
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2025.04.22.

-- copy, paste below, and comment the current line
vim.keymap.set("n", "ycc", "yygccp", {
	remap = true,
	desc = "Copy, paste below, and comment the current line",
})

-- search within visual selection
vim.keymap.set("x", "/", "<Esc>/\\%V")

-- tab navigations
--
-- \bb for switching buffers,
-- \bd for closing a buffer,
--
vim.keymap.set("n", "<C-h>", ":tabprevious<CR>", {
	desc = "Previous tab",
}) -- <ctrl-h> for previous tab
vim.keymap.set("n", "<C-l>", ":tabnext<CR>", {
	desc = "Next tab",
}) -- <ctrl-l> for next tab

-- for toggling mouse: `\mm`
vim.keymap.set("n", "<leader>mm", function()
	require("tools").ui.toggle_mouse() -- ~/.config/nvim/lua/tools.lua
end, { desc = "mouse: Toggle" })

-- for toggling diagnostics: `\tD`
vim.keymap.set("n", "<leader>tD", function()
	if vim.diagnostic.is_enabled() then
		vim.diagnostic.enable(false)
	else
		vim.diagnostic.enable(true)
	end
	vim.notify("Toggled diagnostics " .. (vim.diagnostic.is_enabled() and "on" or "off"))
end, { desc = "diagnostics: Toggle" })

-- <Left> for folding, <Right> for unfolding
vim.keymap.set("n", "<Left>", require("origami").h)
vim.keymap.set("n", "<Right>", require("origami").l)

-- (minifiles)
--
-- for toggling minifiles: `\mf`
vim.keymap.set("n", "<leader>mf", function()
	require("mini.files").setup({})
	MiniFiles.open()
end, { desc = "mini-files: Open" })

-- (telescope)
--
-- https://github.com/nvim-telescope/telescope.nvim#pickers
local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>tt", builtin.builtin, {
	desc = "telescope: List builtin pickers",
})
vim.keymap.set("n", "<leader>ff", builtin.find_files, {
	desc = "telescope: Find files",
})
vim.keymap.set("n", "<leader>gc", builtin.git_commits, {
	desc = "telescope: Git commits",
})
vim.keymap.set("n", "<leader>qf", builtin.quickfix, {
	desc = "telescope: Quickfix",
})

-- (lsp)
--
-- for toggling inlay hint: `\li`
vim.keymap.set("n", "<leader>li", function()
	local enabled = not vim.lsp.inlay_hint.is_enabled({})
	vim.lsp.inlay_hint.enable(enabled)

	vim.notify("Toggled LSP inlay hints " .. (enabled and "on" or "off"))
end, { desc = "lsp: Toggle inlay hint" })

-- (minimap)
--
-- for toggling minimap: `\tm`
vim.keymap.set("n", "<leader>tm", function()
	require("codewindow").toggle_minimap()

	vim.notify("Toggled minimap.")
end, { desc = "minimap: Toggle" })

-- (code actions)
--
-- `\ca` for showing code action previews
vim.keymap.set({ "v", "n" }, "ca", require("actions-preview").code_actions, { desc = "actions-preview: Code actions" })

-- (codeium)
--
-- alt-e: cycle through suggestions
vim.keymap.set("i", "<A-e>", function()
	if require("custom").features().codeium then
		require("neocodeium").cycle_or_complete()
	end
end, { desc = "Neocodeium: Cycle through suggestions" })
-- alt-f: accept
vim.keymap.set("i", "<A-f>", function()
	if require("custom").features().codeium then
		require("neocodeium").accept()
	end
end, { desc = "Neocodeium: Accept suggestion" })

-- NOTE: override/delete unwanted default keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
