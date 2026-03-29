--- Module contract:
--- Owns raw host-event normalization and runtime dispatch into the registry.
--- Returns helpers that normalize payloads and trigger re-renders.
local M = {}

--- Converts JSON boolean strings into Lua booleans.
local function normalize_boolean(value)
	if value == "true" then
		return true
	end

	if value == "false" then
		return false
	end

	return nil
end

--- Converts numeric payload fields into Lua numbers.
local function normalize_number(value)
	if value == nil or value == "" then
		return nil
	end

	return tonumber(value)
end

--- Converts one raw JSON payload into one canonical Lua event table.
function M.normalize_event(payload)
	return {
		name = payload.event,
		widget_id = payload.widget,
		target_widget_id = payload.target_widget,
		app_name = payload.app,
		interface_name = payload.interface,
		button = payload.button,
		direction = payload.direction,
		charging = normalize_boolean(payload.charging),
		muted = normalize_boolean(payload.muted),
		value = normalize_number(payload.value),
		delta_x = normalize_number(payload.delta_x),
		delta_y = normalize_number(payload.delta_y),
		raw = payload,
	}
end

--- Dispatches one normalized event and re-renders all affected trees.
function M.dispatch_event(registry, event, render, log, json)
	log.debug("runtime dispatch event=" .. tostring(event.name))
	registry.handle_event(event)
	render.emit_all(registry, log, json)
end

return M
