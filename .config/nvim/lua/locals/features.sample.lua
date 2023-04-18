-- .config/nvim/lua/locals/features.sample.lua
--
-- sample features list
--
-- (duplicate this file to: ~/.config/nvim/lua/locals/features.lua
-- and edit it)
--
-- last update: 2023.04.18.

return {
  codeium = false, -- codeium's language server crashes on some machines (eg. Raspberry Pi 4)
  linter = false,
}

