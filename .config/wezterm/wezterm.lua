-- $XDG_CONFIG_HOME/wezterm/wezterm.lua
--
-- last update: 2025.02.24.

local wezterm = require("wezterm")

local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

--------------------------------
-- my configurations
config.color_scheme = "Peppermint (Gogh)"
config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font Mono",
	"Iosevka Rootiest v2",
	"Flog Symbols",
	"Symbols Nerd Font",
	"Material Icons",
	"Noto Color Emoji",
	"JetBrains Mono",
	"Fira Code",
})
config.initial_cols = 160
config.initial_rows = 50
config.window_padding = { left = "0.5cell", right = "0.5cell", top = 0, bottom = 0 }
config.use_cap_height_to_scale_fallback_fonts = true
--
--------------------------------

return config
