-- ~/.config/hammerspoon/display.lua
--
-- last update: 2026.06.29.

-- Blink a yellow border around the focused window.
--
-- When focus moves to a window, a border is drawn instantly around that
-- window and fades out, so it is easy to tell where to look on a
-- multi-monitor setup. The blink leaves no residue when focus moves
-- between windows of the same application across displays.
--
-- On multi-display setups, the inactive displays are dimmed so the active
-- display stands out.

-- configuration
local BORDER_COLOR = { red = 1, green = 1, blue = 0, alpha = 1 } -- yellow
local DIM_ALPHA = 0.40 -- darkness of inactive displays (0..1)
local BORDER_WIDTH = 6 -- thickness in points
local FADE_DURATION = 0.6 -- seconds for the border to fade out
local FADE_STEPS = 30 -- number of alpha steps during the fade
local POLL_INTERVAL = 0.3 -- seconds between focus checks

-- currently active blinks, so a new focus can cancel the previous ones
local activeBlinks = {}

local function clearBlinks()
	for _, blink in ipairs(activeBlinks) do
		if blink.timer then
			blink.timer:stop()
		end
		if blink.canvas then
			blink.canvas:delete()
		end
	end
	activeBlinks = {}
end

-- blink a fading border around the focused window's frame
local function blinkWindowBorder(frame)
	if not frame then
		return
	end

	local canvas = hs.canvas.new(frame)
	canvas:appendElements({
		type = "rectangle",
		action = "stroke",
		strokeColor = BORDER_COLOR,
		strokeWidth = BORDER_WIDTH,
		-- inset by half the stroke width so the whole border stays within frame
		frame = {
			x = BORDER_WIDTH / 2,
			y = BORDER_WIDTH / 2,
			w = frame.w - BORDER_WIDTH,
			h = frame.h - BORDER_WIDTH,
		},
	})
	canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
	canvas:canvasMouseEvents(false, false, false, false)
	canvas:level(hs.canvas.windowLevels.overlay)
	canvas:show()

	local blink = { canvas = canvas }
	local step = 0
	local interval = FADE_DURATION / FADE_STEPS
	blink.timer = hs.timer.doEvery(interval, function()
		step = step + 1
		local alpha = 1 - (step / FADE_STEPS)
		if alpha <= 0 then
			blink.timer:stop()
			blink.canvas:delete()
			return
		end
		blink.canvas:alpha(alpha)
	end)

	table.insert(activeBlinks, blink)
end

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

-- poll the focused window and react when it (or its display) changes
local lastWindowID = nil
local lastScreenID = nil

local pollTimer = hs.timer.doEvery(POLL_INTERVAL, function()
	local window = hs.window.focusedWindow()
	if not window then
		return
	end

	local windowID = window:id()
	if windowID == lastWindowID then
		return
	end
	lastWindowID = windowID

	clearBlinks()
	blinkWindowBorder(window:frame())

	-- re-dim the inactive displays when the active display changed
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
