-- ~/.config/hammerspoon/display.lua
--
-- last update: 2026.07.01.

-- Dim the inactive displays so the active display stands out.
--
-- On multi-display setups, every display except the one holding the focused
-- window is covered with a translucent overlay, making it easy to tell where
-- to look. With a single display nothing is dimmed.

-- configuration
local DIM_ALPHA = 0.50 -- darkness of inactive displays (0..1)
local POLL_INTERVAL = 0.3 -- seconds between focus checks

-- persistent dim overlays, keyed by screen id
local dimOverlays = {}

local function clearDimOverlays()
	for _, canvas in pairs(dimOverlays) do
		canvas:delete()
	end
	dimOverlays = {}
end

-- dim every display except the active one (no-op with a single display)
local function dimInactiveDisplays(activeScreenID)
	clearDimOverlays()

	local screens = hs.screen.allScreens()
	if #screens < 2 then
		return
	end

	for _, screen in ipairs(screens) do
		if screen:id() ~= activeScreenID then
			local canvas = hs.canvas.new(screen:fullFrame())
			canvas:appendElements({
				type = "rectangle",
				action = "fill",
				fillColor = { red = 0, green = 0, blue = 0, alpha = DIM_ALPHA },
			})
			canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
			canvas:canvasMouseEvents(false, false, false, false)
			canvas:level(hs.canvas.windowLevels.overlay)
			canvas:show()
			dimOverlays[screen:id()] = canvas
		end
	end
end

-- poll the focused window and re-dim when its display changes
local lastScreenID = nil

local pollTimer = hs.timer.doEvery(POLL_INTERVAL, function()
	local window = hs.window.focusedWindow()
	if not window then
		return
	end

	local screen = window:screen()
	local screenID = screen and screen:id() or nil
	if screenID and screenID ~= lastScreenID then
		dimInactiveDisplays(screenID)
	end
	lastScreenID = screenID
end)

-- recompute dim overlays when the display layout changes
local screenWatcher = hs.screen.watcher
	.new(function()
		local window = hs.window.focusedWindow()
		local screen = window and window:screen() or nil
		dimInactiveDisplays(screen and screen:id() or nil)
	end)
	:start()

-- keep references alive so the timer/watcher are not garbage collected
return {
	pollTimer = pollTimer,
	screenWatcher = screenWatcher,
}
