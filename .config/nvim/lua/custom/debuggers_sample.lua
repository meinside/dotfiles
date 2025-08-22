-- .config/nvim/lua/custom/debuggers_sample.lua
--
-- File for debuggers (sample)
--
-- (duplicate this file to:
--
-- ~/.config/nvim/lua/custom/debuggers.lua
--
-- and edit it)
--
-- last update: 2025.08.22.

-- following DAP debuggers will be installed automatically.
--
-- if value is `true`, will be installed automatically.
return {
	-- c, c++, rust, zig
	codelldb = false,

	-- go
	delve = true,
}
