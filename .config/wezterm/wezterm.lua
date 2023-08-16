-- $XDG_CONFIG_HOME/wezterm/wezterm.lua
--
-- last update: 2023.08.16.

local wezterm = require 'wezterm'

local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

--------------------------------
-- my configurations
config.color_scheme = 'Peppermint (Gogh)'
config.font = wezterm.font('JetBrainsMono Nerd Font Mono')
config.initial_cols = 160
config.initial_rows = 50
config.window_padding = { left = '0.5cell', right = '0.5cell', top = 0, bottom = 0 }
--
--------------------------------

return config

