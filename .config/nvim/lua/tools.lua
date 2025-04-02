-- .config/nvim/lua/tools.lua
--
-- My neovim utility functions
--
-- last update: 2025.04.02.

-- Warn: notify silently
local function warn(msg)
	vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

-- Checks if given `path` is executable or not
local function is_executable(path)
	return vim.fn.executable(path) == 1
end

-- Checks if given `path` exists or not
local function file_exists(path)
	local f = io.open(path, "r")
	return f ~= nil and io.close(f)
end

-- Copies file at `from` to `to` and returns the result as true/false
local function copy_file(from, to)
	local result = false

	local source_handle = io.open(from, "rb")
	if not source_handle then
		warn("Failed to copy file from: " .. from)
	end

	local target_handle = io.open(to, "wb")
	if not target_handle then
		warn("Failed to copy file to: " .. to)
	end

	-- copy bytes
	if source_handle and target_handle then
		while true do
			local chunk = source_handle:read("*a")
			if not chunk or chunk == "" then
				break
			end
			target_handle:write(chunk)
		end
		result = true
	end

	if source_handle then
		source_handle:close()
	end
	if target_handle then
		target_handle:close()
	end

	return result
end

-- Copies file `from` to `to` if it doesn't exist
local function copy_if_needed(from, to)
	if not file_exists(to) then
		return copy_file(from, to)
	end
	return false
end

-- Runs given `command` and returns the result
local function shell_execute(command)
	local handle = io.popen(command)
	---@diagnostic disable-next-line: need-check-nil
	local result = handle:read("*a")
	---@diagnostic disable-next-line: need-check-nil
	handle:close()
	return result
end

-- Check if given `port` is opened or not
local function is_port_opened(port)
	if is_executable("lsof") then
		local listen = shell_execute("lsof -i:" .. tostring(port) .. " | grep LISTEN")
		return string.len(listen) > 0
	end
	return false
end

-- Returns total memory (in kB)
local function total_memory()
	local meminfo = "/proc/meminfo"
	if file_exists(meminfo) then
		-- $ grep "MemTotal" /proc/meminfo | grep -oE '[0-9]+'
		local memory = shell_execute('grep "MemTotal" ' .. meminfo .. ' | grep -oE "[0-9]+"')
		memory = memory:gsub("%s+", "")
		if string.len(memory) > 0 then
			return tonumber(memory)
		end
	end
	return -1 -- when it has no proper `/proc/meminfo` file (eg. macOS machine)
end

-- Checks if this machine will work with low performance
-- (if it is not macOS and has < 4GB memory)
local function low_performance()
	local memory = total_memory()
	if memory < 0 or memory >= 4 * 1024 * 1024 then
		return false
	end

	warn("Running on a machine with low performance.")

	return true
end

-- Checks if it is not in termux
local function not_termux()
	local termuxv = os.getenv("TERMUX_VERSION")
	return termuxv == nil or termuxv == ""
end

-- Checks if it is macOS
local function is_macos()
	return vim.uv.os_uname().sysname == "Darwin"
end

-- Checks if mouse is enabled
local function is_mouse_enabled()
	return vim.o.mouse == "nvi"
end

-- Toggles mouse
local function toggle_mouse()
	if is_mouse_enabled() then
		vim.opt.mouse = ""
	else
		vim.opt.mouse = "nvi"
	end
	vim.notify("Toggled mouse " .. (is_mouse_enabled() and "on" or "off"))
end

local Tools = {
	-- functions for managing file system
	fs = {
		executable = is_executable,
		exists = file_exists,
		copy_if_needed = copy_if_needed,
	},

	-- functions for managing the machine
	system = {
		low_perf = low_performance,
		port_opened = is_port_opened,
		not_termux = not_termux,
		is_macos = is_macos,
	},

	-- functions for manaing shell/commands
	shell = {
		execute = shell_execute,
	},

	-- functions for managing ui
	ui = {
		is_mouse_enabled = is_mouse_enabled,
		toggle_mouse = toggle_mouse,
	},
}

-- functions for debugging
function Tools.d(something)
	vim.notify(vim.inspect(something), vim.log.levels.DEBUG)
end

function Tools.e(something)
	vim.notify(vim.inspect(something), vim.log.levels.ERROR)
end

function Tools.i(something)
	vim.notify(vim.inspect(something), vim.log.levels.INFO)
end

-- export things
return Tools
