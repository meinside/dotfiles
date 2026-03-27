-- .config/nvim/lua/tools.lua
--
-- File for neovim utility functions
--
-- last update: 2026.03.27.

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
	return vim.uv.fs_stat(path) ~= nil
end

-- Copies file at `from` to `to` and returns the result as true/false
local function copy_file(from, to)
	local ok, err = vim.uv.fs_copyfile(from, to)
	if not ok then
		w("Failed to copy file: " .. (err or "unknown error"))
	end
	return ok ~= nil
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
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		w(string.format("Failed to read file: %s", path))
		return nil
	end
	return table.concat(lines, "\n")
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

-- Runs given `command` synchronously and returns stdout
local function shell_execute(command)
	local result = vim.system({ "sh", "-c", command }):wait()
	return result.stdout or ""
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

-- Resolves highlight group
local function resolve_hl(group)
	-- 1. follow the link chain first,
	local resolved = group
	for _ = 1, 10 do
		local info = vim.api.nvim_get_hl(0, { name = resolved, link = true })
		if info.link then
			resolved = info.link
		else
			break
		end
	end

	-- 2. if the result is still empty, fallback to the treesitter capture
	-- by reducing like: "@property.go" -> "@property" -> "@variable"
	local info = vim.api.nvim_get_hl(0, { name = resolved })
	local is_empty = next(info) == nil

	if is_empty and resolved:sub(1, 1) == "@" then
		local parts = vim.split(resolved, ".", { plain = true })
		-- remove the language suffix: "@property.go" -> "@property"
		-- and search further by removing each point
		for n = #parts - 1, 1, -1 do
			local shorter = table.concat(vim.list_slice(parts, 1, n), ".")
			local shorter_info = vim.api.nvim_get_hl(0, { name = shorter, link = true })
			if next(shorter_info) ~= nil then
				return resolve_hl(shorter) -- 재귀로 link까지 추적
			end
		end
	end

	return resolved
end

-- Prints highlight groups under mouse in text-editable areas
--
-- (only works when mouse is enabled)
local function print_hls_under_mouse()
	local pos = vim.fn.getmousepos()
	local row, col = pos.line - 1, pos.column - 1 -- 0-indexed

	local bufnr = vim.fn.winbufnr(pos.winid)
	local result = vim.inspect_pos(bufnr, row, col)

	local groups = {}
	for _, hl in ipairs(result.syntax) do
		table.insert(groups, hl.hl_group)
	end
	for _, hl in ipairs(result.treesitter) do
		table.insert(groups, string.format("%s (-> %s)", hl.hl_group, resolve_hl(hl.hl_group)))
	end
	for _, hl in ipairs(result.semantic_tokens or {}) do
		table.insert(groups, hl.hl_group)
	end

	if #groups > 0 then
		vim.notify(string.format("Pos: [%d, %d], HL Groups:", pos.line, pos.column), vim.log.levels.INFO)
		for _, g in ipairs(groups) do
			vim.notify(string.format(g, pos.line, pos.column), vim.log.levels.INFO)
		end
	else
		vim.notify(string.format("Pos: [%d, %d], HL Group: Unknown", pos.line, pos.column), vim.log.levels.INFO)
	end
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
