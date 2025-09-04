-- .config/nvim/init.lua
--
-- File for initializing neovim
--
-- last update: 2025.09.04.

-- bootstrap lazy.nvim, LazyVim and your plugins
--
-- ~/.config/nvim/lua/config/lazy.lua
require("config.lazy")

--------------------------------
---
-- files list for convenience:
--

--------------------------------
-- config files
--
-- (autocmds)
-- ~/.config/nvim/lua/config/autocmds.lua
--
-- (keymaps)
-- ~/.config/nvim/lua/config/keymaps.lua
--
-- (options)
-- ~/.config/nvim/lua/config/options.lua

--------------------------------
-- lazyvim.plugins.extras
--
-- :LazyExtras
--
-- ~/.config/nvim/lua/extras.lua

--------------------------------
-- plugin files
--
-- ~/.config/nvim/lua/plugins/plugins.lua
--
-- (for development)
-- ~/.config/nvim/lua/plugins/development.lua
-- ~/.config/nvim/lua/plugins/genai.lua
--
-- (for lsps)
-- ~/.config/nvim/lua/plugins/lsps.lua
--
-- (for monkeypatching erroneous plugins/features)
-- ~/.config/nvim/lua/plugins/monkeypatched/

--------------------------------
-- files for customization
--
-- ~/.config/nvim/lua/custom/init.lua
--
-- (for debuggers)
-- ~/.config/nvim/lua/custom/debuggers_sample.lua
-- ~/.config/nvim/lua/custom/debuggers.lua
--
-- (for features on/off)
-- ~/.config/nvim/lua/custom/features_sample.lua
-- ~/.config/nvim/lua/custom/features.lua
--
-- (for linters)
-- ~/.config/nvim/lua/custom/linters_sample.lua
-- ~/.config/nvim/lua/custom/linters.lua
--
-- (for lsps)
-- ~/.config/nvim/lua/custom/lsps_sample.lua
-- ~/.config/nvim/lua/custom/lsps.lua

--------------------------------
-- my tools
--
-- ~/.config/nvim/lua/tools.lua
