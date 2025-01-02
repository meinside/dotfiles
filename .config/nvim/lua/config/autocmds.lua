-- .config/nvim/lua/config/autocmds.lua
--
-- last update: 2025.01.02.

-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- FIXME: not working in mosh (https://github.com/mobile-shell/mosh/issues/352)
vim.api.nvim_create_autocmd({ "VimLeave" }, {
	callback = function()
		vim.opt.guicursor = "a:ver1-blinkon1"
	end,
}) -- NOTE: for fixing cursor in tmux

-- highlight on yank
vim.api.nvim_create_augroup("etc", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	group = "etc",
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({ on_visual = false })
	end,
})

-- keep windows equally sized
vim.api.nvim_create_augroup("Random", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
	group = "Random",
	desc = "Keep windows equally resized",
	command = "tabdo wincmd =",
})
vim.api.nvim_create_autocmd("TermOpen", {
	group = "Random",
	command = "setlocal nonumber norelativenumber signcolumn=no",
})
