-- .config/nvim/lua/custom/features_sample.lua
--
-- sample features list
--
-- (duplicate this file to:
--
-- ~/.config/nvim/lua/custom/features.lua
--
-- and edit it)
--
-- last update: 2025.08.22.

return {
	codeium = false, -- NOTE: codeium's language server crashes on some machines (eg. Raspberry Pi 4)
	linter = false,
	code_assistance = false, -- eg. codecompanion.nvim
}
