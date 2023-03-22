-- My .config/nvim/init.lua file for neovim 0.8+
--
-- created by meinside@duck.com,
--
-- created on : 2021.05.27.
-- last update: 2023.03.22.


------------------------------------------------
-- my helper functions
-- NOTE: in file: `~/.config/nvim/lua/tools.lua`
_G['tools'] = require'tools'


------------------------------------------------
-- my custom things
-- NOTE: in file: `~/.config/nvim/lua/locals/init.lua`
_G['locals'] = require'locals'


------------------------------------------------
-- load neovim plugins
-- NOTE: in file: `~/.config/nvim/lua/plugins.lua`
require'plugins'


------------------------------------------------
-- other common settings
-- NOTE: in file: `~/.config/nvim/lua/settings.lua`
require'settings'


------------------------------------------------
-- for developing and testing my plugins
-- NOTE: in file: `~/.config/nvim/lua/XXXX.lua`
--_G['XXXX'] = require'XXXX'

