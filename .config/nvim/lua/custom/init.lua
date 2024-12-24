-- .config/nvim/lua/custom/init.lua
--
-- My custom functions and variable/constants.
--
-- last update: 2024.12.24.

local function lua_filepath(path)
	local config_dir = os.getenv("XDG_CONFIG_HOME")
	if config_dir == nil then
		config_dir = vim.fn.expand("$HOME/.config")
	end

	return config_dir .. "/nvim/lua/" .. path
end

local tools = require("tools")

local Custom = {}

-- Loads and returns LSP names if possible
local function load_lsps(filter)
	-- NOTE: will try loading: ~/.config/nvim/lua/custom/lsps.lua
	-- sample file here: ~/.config/nvim/lua/custom/lsps_sample.lua
	local ok, lsps = pcall(require, "custom/lsps")
	if ok then
		local names = {}
		for name, b in pairs(lsps) do
			if not filter or b then
				table.insert(names, name)
			end
		end
		return names
	else
		-- NOTE: default: ~/.config/nvim/lua/custom/lsps_sample.lua
		return require("custom/lsps_sample")
	end
end

-- Returns LSP names for configuration
local lsp_names = function(filter)
	tools.fs.copy_if_needed(lua_filepath("custom/lsps_sample.lua"), lua_filepath("custom/lsps.lua"))

	return load_lsps(filter)
end

-- Returns LSP names that are installable
function Custom.installable_lsp_names()
	return lsp_names(false)
end

-- Returns LSP names that are autoconfigurable
function Custom.autoconfigurable_lsp_names()
	return lsp_names(true)
end

-- Loads and returns debugger names if possible
local function load_debuggers()
	-- NOTE: will try loading: ~/.config/nvim/lua/custom/debuggers.lua
	-- sample file here: ~/.config/nvim/lua/custom/debuggers_sample.lua
	local ok, lsps = pcall(require, "custom/debuggers")
	if ok then
		local names = {}
		for name, b in pairs(lsps) do
			if b then
				table.insert(names, name)
			end
		end
		return names
	else
		-- NOTE: default: ~/.config/nvim/lua/custom/debuggers_sample.lua
		return require("custom/lsps_sample")
	end
end

-- Returns debugger names that are installable
function Custom.installable_debugger_names()
	tools.fs.copy_if_needed(lua_filepath("custom/debuggers_sample.lua"), lua_filepath("custom/debuggers.lua"))

	return load_debuggers()
end

-- Loads and returns linter names if possible
local function load_linters()
	-- NOTE: will try loading: ~/.config/nvim/lua/custom/linters.lua
	local ok, linters = pcall(require, "custom/linters")
	if ok then
		return linters
	else
		-- NOTE: default: ~/.config/nvim/lua/custom/linters_sample.lua
		return require("custom/linters_sample")
	end
end

-- Returns linter names for configuration
function Custom.linters()
	tools.fs.copy_if_needed(lua_filepath("custom/linters_sample.lua"), lua_filepath("custom/linters.lua"))

	return load_linters()
end

-- Loads and returns features if possible
local function load_features()
	-- NOTE: will try loading: ~/.config/nvim/lua/custom/features.lua
	local ok, features = pcall(require, "custom/features")
	if ok then
		return features
	else
		-- NOTE: default: ~/.config/nvim/lua/custom/features_sample.lua
		return require("custom/features_sample")
	end
end

-- Returns features' on/off for configuration
function Custom.features()
	tools.fs.copy_if_needed(lua_filepath("custom/features_sample.lua"), lua_filepath("custom/features.lua"))

	return load_features()
end

-- export things
return Custom
