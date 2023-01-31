-- .config/nvim/lua/locals/init.lua
--
-- My custom functions and variable/constants.
--
-- last update: 2023.01.31.

-- Returns LSP names for configuration
local lsp_names = function(filter)
  -- will try loading: `.config/nvim/lua/locals/lsps.lua`
  -- sample file here: `.config/nvim/lua/locals/lsps.sample.lua`
  local ok, my_lsps = pcall(require, 'locals/lsps')
  if not ok then
    -- default
    return {
      'bashls', -- bash
      'jsonls', -- json
      'sumneko_lua', -- lua
    }
  else
    local names = {}
    for name, b in pairs(my_lsps) do
      if not filter or b then
        table.insert(names, name)
      end
    end
    return names
  end
end

-- export things
return {
  installable_lsp_names = function() return lsp_names(false) end,
  autoconfigurable_lsp_names = function() return lsp_names(true) end,
}
