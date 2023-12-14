-- .config/nvim/lua/custom/init.lua
--
-- My custom functions and variable/constants.
--
-- last update: 2023.12.07.

local lua_dir = vim.fn.expand('$XDG_CONFIG_HOME/nvim/lua/')
local function lua_filepath(path)
  return lua_dir .. path
end

local tools = require('tools')

local Custom = {}

-- Loads and returns LSP names if possible
local function load_lsps(filter)
  -- will try loading: ~/.config/nvim/lua/custom/lsps.lua
  -- sample file here: ~/.config/nvim/lua/custom/lsps_sample.lua
  local ok, lsps = pcall(require, 'custom/lsps')
  if ok then
    local names = {}
    for name, b in pairs(lsps) do
      if not filter or b then
        table.insert(names, name)
      end
    end
    return names
  else
    -- default: ~/.config/nvim/lua/custom/lsps_sample.lua
    return require('custom/lsps_sample')
  end
end

-- Returns LSP names for configuration
local lsp_names = function(filter)
  tools.fs.copy_if_needed(lua_filepath('custom/lsps_sample.lua'), lua_filepath('custom/lsps.lua'))

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

-- Loads and returns linter names if possible
local function load_linters()
  -- will try loading: ~/.config/nvim/lua/custom/linters.lua
  local ok, linters = pcall(require, 'custom/linters')
  if ok then
    return linters
  else
    -- default: ~/.config/nvim/lua/custom/linters_sample.lua
    return require('custom/linters_sample')
  end
end

-- Returns linter names for configuration
function Custom.linters()
  tools.fs.copy_if_needed(lua_filepath('custom/linters_sample.lua'), lua_filepath('custom/linters.lua'))

  return load_linters()
end

-- Loads and returns features if possible
local function load_features()
  -- will try loading: ~/.config/nvim/lua/custom/features.lua
  local ok, features = pcall(require, 'custom/features')
  if ok then
    return features
  else
    -- default: ~/.config/nvim/lua/custom/features_sample.lua
    return require('custom/features_sample')
  end
end

-- Returns features' on/off for configuration
function Custom.features()
  tools.fs.copy_if_needed(lua_filepath('custom/features_sample.lua'), lua_filepath('custom/features.lua'))

  return load_features()
end


-- export things
return Custom

