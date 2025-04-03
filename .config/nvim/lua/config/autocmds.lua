-- .config/nvim/lua/config/autocmds.lua
--
-- last update: 2025.04.03.

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

-- diagnostics: show only virtual lines, not virtual text on the current line
--
-- * referenced: https://www.reddit.com/r/neovim/comments/1jpbc7s/disable_virtual_text_if_there_is_diagnostic_in/
local og_virt_text
local og_virt_line
vim.api.nvim_create_autocmd({ "CursorMoved", "DiagnosticChanged" }, {
	group = vim.api.nvim_create_augroup("diagnostic_only_virtlines", {}),
	callback = function()
		if og_virt_line == nil then
			og_virt_line = vim.diagnostic.config().virtual_lines
		end

		-- ignore if virtual_lines.current_line is disabled
		if not (og_virt_line and og_virt_line.current_line) then
			if og_virt_text then
				vim.diagnostic.config({ virtual_text = og_virt_text })
				og_virt_text = nil
			end
			return
		end

		if og_virt_text == nil then
			og_virt_text = vim.diagnostic.config().virtual_text
		end

		local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

		if vim.tbl_isempty(vim.diagnostic.get(0, { lnum = lnum })) then
			vim.diagnostic.config({ virtual_text = og_virt_text })
		else
			vim.diagnostic.config({ virtual_text = false })
		end
	end,
})
vim.api.nvim_create_autocmd("ModeChanged", {
	group = vim.api.nvim_create_augroup("diagnostic_redraw", {}),
	callback = function()
		pcall(vim.diagnostic.show)
	end,
})
