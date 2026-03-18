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
	forced = true,
}

local function deep_copy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, item in pairs(value) do
		copy[key] = deep_copy(item)
	end

	return copy
end

local function deep_merge(target, source)
	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			deep_merge(target[key], value)
		else
			target[key] = deep_copy(value)
		end
	end

	return target
end

local function normalize_bool(value, default)
	if value == nil then
		return default
	end

	if value == true or value == "on" then
		return true
	end

	if value == false or value == "off" then
		return false
	end

	return default
end

local function normalize_label(value)
	if value == nil then
		return nil
	end

	if type(value) == "table" then
		return value
	end

	return {
		string = tostring(value),
	}
end

local function normalize_icon(value)
	if value == nil then
		return nil
	end

	if type(value) == "table" then
		return value
	end

	return {
		string = tostring(value),
	}
end

local function normalize_props(props)
	local normalized = deep_copy(props or {})

	if normalized.label ~= nil then
		normalized.label = normalize_label(normalized.label)
	end

	if normalized.icon ~= nil then
		normalized.icon = normalize_icon(normalized.icon)
	end

	if normalized.drawing ~= nil then
		normalized.drawing = normalize_bool(normalized.drawing, true)
	end

	if type(normalized.popup) == "table" and normalized.popup.drawing ~= nil then
		normalized.popup.drawing = normalize_bool(normalized.popup.drawing, false)
	end

	return normalized
end

local function trim_trailing_newlines(value)
	if not value then
		return ""
	end

	value = value:gsub("\r", "")
	value = value:gsub("\n+$", "")
	return value
end

local function join_message(...)
	local parts = {}

	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end

	return table.concat(parts, " ")
end

function M.new(log)
	local state = {
		items = {},
		item_order = {},
		subscriptions = {},
		routine_next_due = {},
		needs_second_tick = false,
		defaults = {},
	}

	local api = {}

	local function ensure_item_exists(id)
		local item = state.items[id]

		if not item then
			error("easybar item does not exist: " .. tostring(id))
		end

		return item
	end

	local function child_ids_of(id)
		local result = {}

		for child_id, item in pairs(state.items) do
			local parent = item.props.parent
			local position = item.props.position

			if parent == id then
				result[#result + 1] = child_id
			elseif type(position) == "string" and position == ("popup." .. id) then
				result[#result + 1] = child_id
			end
		end

		table.sort(result)
		return result
	end

	local function remove_recursive(id)
		local children = child_ids_of(id)

		for _, child_id in ipairs(children) do
			remove_recursive(child_id)
		end

		state.items[id] = nil
		state.subscriptions[id] = nil
		state.routine_next_due[id] = nil

		for index, value in ipairs(state.item_order) do
			if value == id then
				table.remove(state.item_order, index)
				break
			end
		end
	end

	local function merged_with_defaults(props)
		local merged = {}
		deep_merge(merged, state.defaults)
		deep_merge(merged, normalize_props(props or {}))
		return merged
	end

	local function log_widget(source, level, ...)
		if not log or type(log.widget) ~= "function" then
			return
		end

		log.widget(source or "widget", level or "INFO", join_message(...))
	end

	--- Sets defaults for future easybar.add(...) calls.
	--- Later calls merge on top of earlier defaults.
	function api.default(props)
		deep_merge(state.defaults, normalize_props(props or {}))
	end

	--- Resets all add(...) defaults.
	function api.clear_defaults()
		state.defaults = {}
	end

	--- Adds one item.
	function api.add(kind, id, props)
		assert(type(kind) == "string" and kind ~= "", "easybar.add(kind, id, props) requires kind")
		assert(type(id) == "string" and id ~= "", "easybar.add(kind, id, props) requires id")

		local is_new = state.items[id] == nil

		state.items[id] = {
			id = id,
			kind = kind,
			props = merged_with_defaults(props or {}),
		}

		if is_new then
			state.item_order[#state.item_order + 1] = id
		end

		if state.items[id].props.update_freq ~= nil then
			state.needs_second_tick = true
		end
	end

	--- Merges properties into one item.
	function api.set(id, props)
		local item = ensure_item_exists(id)
		deep_merge(item.props, normalize_props(props or {}))

		if item.props.update_freq ~= nil then
			state.needs_second_tick = true
		end
	end

	--- Small UX helper.
	--- EasyBar already animates visual state changes on the SwiftUI side,
	--- so animate(...) writes through the normal set(...) path.
	function api.animate(id, props, options)
		local _ = options
		api.set(id, props)
	end

	--- Returns one copied item property table.
	function api.get(id)
		local item = ensure_item_exists(id)
		return deep_copy(item.props)
	end

	--- Removes one item and its descendants.
	function api.remove(id)
		remove_recursive(id)
	end

	--- Runs one shell command.
	function api.exec(command, callback)
		assert(type(command) == "string" and command ~= "", "easybar.exec(command, callback) requires command")

		local pipe = io.popen(command .. " 2>/dev/null")
		local output = ""

		if pipe then
			output = trim_trailing_newlines(pipe:read("*a") or "")
			pipe:close()
		end

		if type(callback) == "function" then
			return callback(output)
		end

		return output
	end

	--- Subscribes one item to one or more events.
	function api.subscribe(id, events, handler)
		ensure_item_exists(id)
		assert(type(handler) == "function", "easybar.subscribe(id, events, handler) requires handler")

		if type(events) == "string" then
			events = { events }
		end

		assert(type(events) == "table", "easybar.subscribe(id, events, handler) requires events")

		local bucket = state.subscriptions[id] or {}
		state.subscriptions[id] = bucket

		for _, event_name in ipairs(events) do
			bucket[event_name] = bucket[event_name] or {}
			bucket[event_name][#bucket[event_name] + 1] = handler

			if event_name == "routine" then
				state.needs_second_tick = true
			end
		end
	end

	local function make_env(id, event_name, payload)
		return {
			NAME = id,
			SENDER = event_name,
			INFO = deep_copy(payload or {}),
		}
	end

	local function maybe_run_click_script(id, event_name)
		if event_name ~= "mouse.clicked" then
			return
		end

		local item = state.items[id]
		if not item then
			return
		end

		local command = item.props.click_script
		if type(command) ~= "string" or command == "" then
			return
		end

		api.exec(command)
	end

	local function dispatch_handlers_for(id, event_name, payload)
		local bucket = state.subscriptions[id]
		if not bucket then
			return
		end

		local handlers = bucket[event_name]
		if type(handlers) ~= "table" then
			return
		end

		maybe_run_click_script(id, event_name)

		local env = make_env(id, event_name, payload)

		for _, handler in ipairs(handlers) do
			local ok, err = pcall(handler, env)

			if not ok and log then
				log.error(
					"lua handler failed id="
						.. tostring(id)
						.. " event="
						.. tostring(event_name)
						.. " error="
						.. tostring(err)
				)
			end
		end
	end

	local function dispatch_targeted(event_name, payload)
		local target = payload and payload.widget or nil

		for _, id in ipairs(state.item_order) do
			if state.items[id] ~= nil then
				if target == nil or target == id then
					dispatch_handlers_for(id, event_name, payload)
				end
			end
		end
	end

	local function dispatch_routine_if_due()
		local now = os.time()

		for _, id in ipairs(state.item_order) do
			local item = state.items[id]

			if item ~= nil then
				local bucket = state.subscriptions[id]

				if bucket and type(bucket.routine) == "table" and #bucket.routine > 0 then
					local interval = tonumber(item.props.update_freq or 0) or 0

					if interval > 0 then
						local next_due = state.routine_next_due[id] or 0

						if now >= next_due then
							state.routine_next_due[id] = now + interval
							dispatch_handlers_for(id, "routine", {})
						end
					end
				end
			end
		end
	end

	--- Handles one incoming EasyBar event.
	function api.handle_event(event_name, payload)
		if event_name == "second_tick" then
			dispatch_routine_if_due()
		end

		dispatch_targeted(event_name, payload)
	end

	--- Returns the driver events required by the runtime.
	function api.required_events()
		local events = {}

		for _, id in ipairs(state.item_order) do
			local bucket = state.subscriptions[id]

			if bucket then
				for event_name in pairs(bucket) do
					if DRIVER_EVENTS[event_name] then
						events[event_name] = true
					end
				end
			end
		end

		if state.needs_second_tick then
			events.second_tick = true
		end

		local result = {}

		for event_name in pairs(events) do
			result[#result + 1] = event_name
		end

		table.sort(result)
		return result
	end

	--- Returns one widget-scoped EasyBar API.
	function api.make_widget_api(source)
		local widget_api = {}

		local function copy(name)
			widget_api[name] = api[name]
		end

		copy("default")
		copy("clear_defaults")
		copy("add")
		copy("set")
		copy("animate")
		copy("get")
		copy("remove")
		copy("exec")
		copy("subscribe")
		copy("handle_event")
		copy("required_events")

		--- Writes one widget log line through the host logger.
		function widget_api.log(level, ...)
			log_widget(source, level, ...)
		end

		return widget_api
	end

	api._state = state

	return api
end

return M
