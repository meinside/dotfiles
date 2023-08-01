-- .config/nvim/lua/custom/init.lua
--
-- My custom functions and variable/constants.
--
-- last update: 2023.08.01.

local Custom = {}

-- Returns LSP names for configuration
local lsp_names = function(filter)
  -- will try loading: ~/.config/nvim/lua/custom/lsps.lua
  -- sample file here: ~/.config/nvim/lua/custom/lsps.sample.lua
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
    -- default
    return {
      'bashls', -- bash
      'jsonls', -- json
      'lua_ls', -- lua
    }
  end
end

function Custom.installable_lsp_names()
  return lsp_names(false)
end

function Custom.autoconfigurable_lsp_names()
  return lsp_names(true)
end

-- Returns linter names for configuration
function Custom.linters()
  -- will try loading: ~/.config/nvim/lua/custom/linters.lua
  -- sample file here: ~/.config/nvim/lua/custom/linters.sample.lua
  local ok, linters = pcall(require, 'custom/linters')
  if ok then
    return linters
  else
    -- default
    return {
      go = { 'golangcilint' },
      markdown = { 'vale' },
      sh = { 'shellcheck' },
    }
  end
end

-- Returns features' on/off for configuration
function Custom.features()
  -- will try loading: ~/.config/nvim/lua/custom/features.lua
  -- sample file here: ~/.config/nvim/lua/custom/features.sample.lua
  local ok, features = pcall(require, 'custom/features')
  if ok then
    return features
  else
    -- default
    return {
      codeium = false,
      linter = false,
    }
  end
end

-- lisp types
Custom.lisps = { 'lisp', 'clojure', 'fennel', 'janet' }


-- export things
return Custom

