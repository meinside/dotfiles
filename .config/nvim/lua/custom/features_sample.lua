-- .config/nvim/lua/custom/features_sample.lua
--
-- File for customized features (sample)
--
-- (duplicate this file to:
--
-- ~/.config/nvim/lua/custom/features.lua
--
-- and edit it)
--
-- last update: 2026.07.09.

return {
	linter = false,
	code_assistance = false, -- eg. codeium, or etc.

	-- Controls low-performance mode (disables heavy plugins like LSP/DAP,
	-- and shrinks the treesitter parser set).
	--
	--   * "auto"  => auto-detect (not macOS and < 4GB memory) [default]
	--   * true    => force low-performance mode on
	--   * false   => force low-performance mode off
	low_perf = "auto",
}
