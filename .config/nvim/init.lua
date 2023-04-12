-- My .config/nvim/init.lua file for neovim 0.8+
--
-- created by meinside@duck.com,
--
-- created on : 2021.05.27.
-- last update: 2023.04.12.


------------------------------------------------
-- common neovim settings
--
require'settings' -- ~/.config/nvim/lua/settings.lua


------------------------------------------------
-- neovim plugins
--
require'plugins' -- ~/.config/nvim/lua/plugins.lua


------------------------------------------------
-- my helper functions and custom things
--
_G['tools'] = require'tools' -- ~/.config/nvim/lua/tools.lua
_G['locals'] = require'locals' -- ~/.config/nvim/lua/locals/init.lua


------------------------------------------------
-- for developing and testing my plugins
--
--_G['XXXX'] = require'XXXX' -- ~/.config/nvim/lua/XXXX.lua

