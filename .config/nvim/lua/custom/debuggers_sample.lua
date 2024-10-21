-- .config/nvim/lua/custom/debuggers_sample.lua
--
-- sample debugger list
--
-- (duplicate this file to: ~/.config/nvim/lua/custom/debuggers.lua
-- and edit it)
--
-- last update: 2024.10.21.

-- following DAP debuggers will be installed automatically
-- in: ~/.config/nvim/lua/plugins.lua
return {
  -- c, c++, rust, zig
  codelldb = true,

  -- go
  delve = true,
}

