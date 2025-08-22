-- .config/nvim/lua/config/autocmds.lua
--
-- last update: 2025.08.22.

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

-- disable diagnostics for Lazy
local lazy_diag = vim.api.nvim_create_augroup("LazyDiagnostics", { clear = true })
-- (when opening Lazy)
vim.api.nvim_create_autocmd("FileType", {
	group = lazy_diag,
	pattern = "lazy",
	callback = function()
		vim.diagnostic.enable(false, { bufnr = 0 }) -- current buffer
	end,
})
-- (when closing Lazy)
vim.api.nvim_create_autocmd("BufLeave", {
	group = lazy_diag,
	pattern = "*",
	callback = function()
		vim.diagnostic.enable(true, { bufnr = 0 }) -- current buffer
	end,
})

-- change highlight color for function signature help
vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "*",
	desc = "Custom LSP signature highlights",
	callback = function()
		vim.api.nvim_set_hl(0, "LspSignatureActiveParameter", {
			bg = "#000000",
			fg = "#ff0000",
			bold = true, -- Optionally add styles
		})
	end,
})

-- for codecompanion.nvim
--
-- (referenced: https://github.com/olimorris/codecompanion.nvim/discussions/813)
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local group = vim.api.nvim_create_augroup("CodeCompanionFidgetHooks", { clear = true })
vim.api.nvim_create_autocmd({ "User" }, {
	pattern = "CodeCompanion*",
	group = group,
	callback = function(request)
		if request.match == "CodeCompanionChatSubmitted" or request.match == "CodeCompanionContextChanged" then
			return
		end

		local msg
		msg = "[CodeCompanion] " .. request.match:gsub("CodeCompanion", "")

		vim.notify(msg, "info", {
			timeout = 1000,
			keep = function()
				return not vim.iter({ "Finished", "Opened", "Hidden", "Closed", "Cleared", "Created" })
					:fold(false, function(acc, cond)
						return acc or vim.endswith(request.match, cond)
					end)
			end,
			id = "code_companion_status",
			title = "Code Companion Status",
			opts = function(notif)
				notif.icon = ""
				if vim.endswith(request.match, "Started") then
					---@diagnostic disable-next-line: undefined-field
					notif.icon = spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
				elseif vim.endswith(request.match, "Finished") then
					notif.icon = " "
				end
			end,
		})
	end,
})
