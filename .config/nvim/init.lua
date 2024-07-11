-- My .config/nvim/init.lua file for neovim 0.10+
--
-- created on : 2021.05.27.
-- last update: 2024.07.11.


------------------------------------------------
-- common neovim settings
--
require'settings' -- ~/.config/nvim/lua/settings.lua


------------------------------------------------
-- neovim plugins
--
require'plugins' -- ~/.config/nvim/lua/plugins.lua


------------------------------------------------
-- for developing and testing my plugins
--
--_G['tools'] = require'tools' -- ~/.config/nvim/lua/tools.lua
--_G['custom'] = require'custom' -- ~/.config/nvim/lua/custom/init.lua
--_G['XXXX'] = require'XXXX' -- ~/.config/nvim/lua/XXXX.lua

