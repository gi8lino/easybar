--- Module contract:
--- Owns reusable `easybar.events` tokens and event-name normalization.
--- Returns one table with `tokens`, `driver_events`, and `normalize(...)`.
local M = {}

local DRIVER_EVENTS = {
	system_woke = true,
	sleep = true,
	space_change = true,
	app_switch = true,
	display_change = true,
	power_source_change = true,
	charging_state_change = true,
	wifi_change = true,
	network_change = true,
	volume_change = true,
	mute_change = true,
	minute_tick = true,
	second_tick = true,
	calendar_change = true,
	focus_change = true,
	workspace_change = true,
	space_mode_change = true,
	forced = true,
}

--- Wraps one runtime event name in a reusable subscribe token.
local function make_event_token(name)
	return {
		name = name,
	}
end

M.tokens = {
	routine = make_event_token("routine"),
	forced = make_event_token("forced"),
	system_woke = make_event_token("system_woke"),
	sleep = make_event_token("sleep"),
	space_change = make_event_token("space_change"),
	app_switch = make_event_token("app_switch"),
	display_change = make_event_token("display_change"),
	power_source_change = make_event_token("power_source_change"),
	charging_state_change = make_event_token("charging_state_change"),
	wifi_change = make_event_token("wifi_change"),
	network_change = make_event_token("network_change"),
	volume_change = make_event_token("volume_change"),
	mute_change = make_event_token("mute_change"),
	minute_tick = make_event_token("minute_tick"),
	second_tick = make_event_token("second_tick"),
	calendar_change = make_event_token("calendar_change"),
	focus_change = make_event_token("focus_change"),
	workspace_change = make_event_token("workspace_change"),
	space_mode_change = make_event_token("space_mode_change"),
	mouse = {
		entered = make_event_token("mouse.entered"),
		exited = make_event_token("mouse.exited"),
		clicked = make_event_token("mouse.clicked"),
		down = make_event_token("mouse.down"),
		up = make_event_token("mouse.up"),
		scrolled = make_event_token("mouse.scrolled"),
	},
	slider = {
		preview = make_event_token("slider.preview"),
		changed = make_event_token("slider.changed"),
	},
}

M.driver_events = DRIVER_EVENTS

--- Extracts the runtime event name from one `easybar.events` token.
function M.normalize(event)
	assert(
		type(event) == "table" and type(event.name) == "string" and event.name ~= "",
		"easybar.subscribe(...) requires easybar.events values"
	)
	return event.name
end

return M
