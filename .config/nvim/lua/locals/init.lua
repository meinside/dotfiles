-- .config/nvim/lua/locals/init.lua
--
-- My custom functions and variable/constants.
--
-- last update: 2023.04.21.

local Locals = {}

-- Returns LSP names for configuration
local lsp_names = function(filter)
  -- will try loading: ~/.config/nvim/lua/locals/lsps.lua
  -- sample file here: ~/.config/nvim/lua/locals/lsps.sample.lua
  local ok, lsps = pcall(require, 'locals/lsps')
  if not ok then
    -- default
    return {
      'bashls', -- bash
      'jsonls', -- json
      'lua_ls', -- lua
    }
  else
    local names = {}
    for name, b in pairs(lsps) do
      if not filter or b then
        table.insert(names, name)
      end
    end
    return names
  end
end

function Locals.installable_lsp_names()
  return lsp_names(false)
end

function Locals.autoconfigurable_lsp_names()
  return lsp_names(true)
end

-- Returns linter names for configuration
function Locals.linters()
  -- will try loading: ~/.config/nvim/lua/locals/linters.lua
  -- sample file here: ~/.config/nvim/lua/locals/linters.sample.lua
  local ok, linters = pcall(require, 'locals/linters')
  if ok then
    return linters
  else
    -- default
    return {
      go = { 'golangcilint' },
      lua = { 'luacheck' },
      markdown = { 'vale' },
      ruby = { 'rubocop' },
      sh = { 'shellcheck' },
    }
  end
end

-- Returns features' on/off for configuration
function Locals.features()
  -- will try loading: ~/.config/nvim/lua/locals/features.lua
  -- sample file here: ~/.config/nvim/lua/locals/features.sample.lua
  local ok, features = pcall(require, 'locals/features')
  if not ok then
    -- default
    return {
      codeium = false,
      linter = false,
    }
  else
    return features
  end
end


-- export things
return Locals

