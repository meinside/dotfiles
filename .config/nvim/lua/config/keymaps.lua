-- .config/nvim/lua/config/keymaps.lua
--
-- File for keymaps
--
-- https://www.lazyvim.org/keymaps
--
-- last update: 2025.09.22.

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

-- (fzf-lua)
--
-- https://github.com/ibhagwan/fzf-lua#commands
vim.keymap.set("n", "<leader>sB", ":FzfLua builtin<CR>", {
	desc = "List builtin commands",
})
-- `\ff` for finding files (cwd)
-- `\fF` for finding files (root)
-- `\fg` for finding files (git)
vim.keymap.set("n", "<leader>gc", ":FzfLua git_commits<CR>", {
	desc = "Git Commits",
})
-- `\gd` for git diff (hunks)
-- `\gs` for git status
-- `\gS` for git stash
-- `\sd` for diagnostics
-- `\sq` for quickfix list

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
	require("mini.map").toggle()

	vim.notify("Toggled minimap.")
end, { desc = "minimap: Toggle" })

-- (code actions)
--
-- `\ca` for showing code action previews

-- (codeium)
--
-- alt-e: cycle through suggestions
vim.keymap.set("i", "<A-e>", function()
	if require("custom").features().code_assistance then
		require("neocodeium").cycle_or_complete()
	end
end, { desc = "Neocodeium: Cycle through suggestions" })
-- alt-f: accept
vim.keymap.set("i", "<A-f>", function()
	if require("custom").features().code_assistance then
		require("neocodeium").accept()
	end
end, { desc = "Neocodeium: Accept suggestion" })

-- (snacks.nvim)
--
-- `\ti` for toggling indent colors
vim.keymap.set("n", "<leader>ti", function()
	local indent = require("snacks").indent
	if indent.enabled then
		indent.disable()
	else
		indent.enable()
	end

	vim.notify("Toggled indent colors.")
end, { desc = "Snacks: Toggle indent colors" })

-- (meow.yarn)
vim.keymap.set("n", "<leader>yT", "<Cmd>MeowYarn type super<CR>", { desc = "Yarn: Super Types" })
vim.keymap.set("n", "<leader>yt", "<Cmd>MeowYarn type sub<CR>", { desc = "Yarn: Sub Types" })
vim.keymap.set("n", "<leader>yC", "<Cmd>MeowYarn call callers<CR>", { desc = "Yarn: Callers" })
vim.keymap.set("n", "<leader>yc", "<Cmd>MeowYarn call callees<CR>", { desc = "Yarn: Callees" })

-- NOTE: override/delete unwanted default keymaps
vim.keymap.del("n", "<S-h>")
vim.keymap.del("n", "<S-l>")
