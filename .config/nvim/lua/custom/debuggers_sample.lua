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
--
-- if value is `true`, will be installed automatically.
return {
  -- c, c++, rust, zig
  codelldb = false,

  -- go
  delve = true,
}

