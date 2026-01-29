-- .config/nvim/lua/tools.lua
--
-- File for neovim utility functions
--
-- last update: 2026.01.29.

--------------------------------
-- functions for debugging

-- w for notifying silently
local function w(msg)
	vim.api.nvim_echo({ { msg, "WarningMsg" } }, true, {})
end

-- d for notifying debugging messages
local function d(something)
	vim.notify(vim.inspect(something), vim.log.levels.DEBUG)
end

-- e for notifying error messages
local function e(something)
	vim.notify(vim.inspect(something), vim.log.levels.ERROR)
end

-- i for notifying info messages
local function i(something)
	vim.notify(vim.inspect(something), vim.log.levels.INFO)
end

--------------------------------
-- functions for file system

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
		w("Failed to copy file from: " .. from)
	end

	local target_handle = io.open(to, "wb")
	if not target_handle then
		w("Failed to copy file to: " .. to)
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

-- Reads file content at `path`, returns nil if failed.
local function read_file(path)
	local file = io.open(path, "r")
	if not file then
		w(string.format("Failed to open file: %s", path))
	else
		local content = file:read("*all")
		file:close()
		if not content then
			w(string.format("Failed to read file: %s", path))
		else
			return content
		end
	end
	return nil
end

-- Reads JSON file at `path` and returns the value of `key`.
local function read_json_key(path, key)
	local content = read_file(path)
	if content then
		local success, decoded = pcall(vim.fn.json_decode, content)
		if not success then
			w(string.format("JSON parse failed (file: %s, message: %s)", path, decoded))
		else
			if type(decoded) == "table" and decoded[key] ~= nil then
				return decoded[key]
			end
			w(string.format("Failed to read key '%s' from JSON", key))
		end
	end
	return nil
end

--------------------------------
-- functions for shell

-- Runs given `command` and returns the result
local function shell_execute(command)
	local handle = io.popen(command)
	---@diagnostic disable-next-line: need-check-nil
	local result = handle:read("*a")
	---@diagnostic disable-next-line: need-check-nil
	handle:close()
	return result
end

--------------------------------
-- functions for OS

-- Checks if given `port` is opened or not
local function is_port_opened(port)
	if is_executable("lsof") then
		local listen = shell_execute("lsof -i:" .. tostring(port) .. " | grep LISTEN")
		return string.len(listen) > 0
	else
		w(string.format("Could not check if port %d is opened: `lsof` not installed.", port))
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

	w("Running on a machine with low performance.")

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

--------------------------------
-- functions for UI

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
	vim.notify("Toggled mouse " .. (is_mouse_enabled() and "on" or "off"), vim.log.levels.INFO)
end

-- Prints highlight groups under mouse
-- (only works when mouse is enabled)
local function print_hls_under_mouse()
	local pos = vim.fn.getmousepos()
	local row, col = pos.screenrow, pos.screencol

	local attr_id = vim.fn.screenattr(row, col)
	local hl_name = vim.fn.synIDattr(attr_id, "name")

	local msg
	if hl_name ~= "" then
		msg = string.format("Pos: [%d, %d], HL Group: %s", row, col, hl_name)

		local trans_id = vim.fn.synIDtrans(attr_id)
		local trans_name = vim.fn.synIDattr(trans_id, "name")
		if hl_name ~= trans_name then
			msg = msg .. string.format(" (%s)", trans_name)
		end
	else
		msg = string.format("Pos: [%d, %d], HL Group: None", row, col)
	end

	vim.notify(msg, vim.log.levels.INFO)
end

-- export things
local Tools = {
	-- functions for debugging
	d = d,
	e = e,
	i = i,

	-- functions for managing file system
	fs = {
		executable = is_executable,
		exists = file_exists,
		copy_if_needed = copy_if_needed,
		read_file = read_file,
		read_json_key = read_json_key,
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
		print_hls_under_mouse = print_hls_under_mouse,
	},
}

return Tools
