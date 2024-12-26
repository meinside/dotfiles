-- .config/nvim/lua/custom/debuggers_sample.lua
--
-- sample debugger list
--
-- (duplicate this file to:
--
-- ~/.config/nvim/lua/custom/debuggers.lua
--
-- and edit it)
--
-- last update: 2024.12.26.

-- following DAP debuggers will be installed automatically.
--
-- if value is `true`, will be installed automatically.
return {
  -- c, c++, rust, zig
  codelldb = false,

  -- go
  delve = true,
}
