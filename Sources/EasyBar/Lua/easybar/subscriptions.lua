--- Module contract:
--- Owns event subscriptions, routine scheduling, and handler dispatch.
--- Returns one helper object with subscribe/handle_event/required_events.
local M = {}

--- Returns one handler event table scoped to one subscribed item.
local function make_handler_event(id, event, deep_copy)
	return {
		name = event.name,
		widget_id = id,
		target_widget_id = event.target_widget_id or event.widget_id,
		app_name = event.app_name,
		interface_name = event.interface_name,
		button = event.button,
		direction = event.direction,
		charging = event.charging,
		muted = event.muted,
		value = event.value,
		delta_x = event.delta_x,
		delta_y = event.delta_y,
		raw = deep_copy(event.raw or {}),
	}
end

--- Deep-copies one Lua value tree.
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

--- Returns one new subscription helper object.
function M.new(state, ensure_item_exists, log, event_tokens)
	local subscriptions = {}

	--- Dispatches one normalized event to one widget id.
	local function dispatch_handlers_for(id, event)
		local bucket = state.subscriptions[id]
		if not bucket then
			return
		end

		local handlers = bucket[event.name]
		if type(handlers) ~= "table" then
			return
		end

		local handler_event = make_handler_event(id, event, deep_copy)

		for _, handler in ipairs(handlers) do
			local ok, err = pcall(handler, handler_event)

			if not ok and log then
				log.error(
					"lua handler failed id="
						.. tostring(id)
						.. " event="
						.. tostring(event.name)
						.. " error="
						.. tostring(err)
				)
			end
		end
	end

	--- Dispatches one targeted event to the owner and subscribed target.
	local function dispatch_targeted(event)
		local owner = event.widget_id
		local target = event.target_widget_id or owner
		local dispatched = {}

		for _, id in ipairs(state.item_order) do
			if state.items[id] ~= nil then
				if target == nil or target == id then
					dispatch_handlers_for(id, event)
					dispatched[id] = true
				end

				if owner ~= nil and owner ~= target and owner == id and not dispatched[id] then
					dispatch_handlers_for(id, event)
				end
			end
		end
	end

	--- Emits due `routine` events for items with `update_freq`.
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

							dispatch_handlers_for(id, {
								name = "routine",
								widget_id = nil,
								raw = {},
							})
						end
					end
				end
			end
		end
	end

	--- Subscribes one item to one or more events.
	function subscriptions.subscribe(id, events, handler)
		ensure_item_exists(id)
		assert(type(handler) == "function", "easybar.subscribe(id, events, handler) requires handler")

		if type(events) == "table" and type(events.name) == "string" then
			events = { events }
		end

		assert(type(events) == "table", "easybar.subscribe(id, events, handler) requires events")

		local bucket = state.subscriptions[id] or {}
		state.subscriptions[id] = bucket

		for _, event in ipairs(events) do
			local event_name = event_tokens.normalize(event)
			bucket[event_name] = bucket[event_name] or {}
			bucket[event_name][#bucket[event_name] + 1] = handler

			if event_name == "routine" then
				state.needs_second_tick = true
			end
		end
	end

	--- Handles one incoming normalized EasyBar event.
	function subscriptions.handle_event(event)
		if event.name == "second_tick" then
			dispatch_routine_if_due()
		end

		dispatch_targeted(event)
	end

	--- Returns the driver events required by the runtime.
	function subscriptions.required_events()
		local events = {}

		for _, id in ipairs(state.item_order) do
			local bucket = state.subscriptions[id]

			if bucket then
				for event_name in pairs(bucket) do
					if event_tokens.driver_events[event_name] then
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

	return subscriptions
end

return M
