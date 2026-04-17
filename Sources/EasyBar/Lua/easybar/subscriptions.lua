--- Module contract:
--- Owns event subscriptions, interval scheduling, and handler dispatch.
--- Returns one helper object with subscribe/handle_event/required_events.
local M = {}

local INTERVAL_TICK_PREFIX = "interval_tick:"

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

--- Returns one positive whole-second interval or nil.
local function normalize_interval(value)
	local number = tonumber(value)
	if number == nil or number <= 0 then
		return nil
	end

	return math.max(1, math.floor(number))
end

--- Returns the greatest common divisor for two positive integers.
local function gcd(left, right)
	left = math.abs(left)
	right = math.abs(right)

	while right ~= 0 do
		left, right = right, left % right
	end

	return left
end

--- Returns one handler event table scoped to one subscribed item.
local function make_handler_event(id, event)
	local handler_event = deep_copy(event)
	handler_event.widget_id = id

	if handler_event.target_widget_id == nil and event.widget_id ~= nil then
		handler_event.target_widget_id = event.widget_id
	end

	return handler_event
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

		local handler_event = make_handler_event(id, event)

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

	--- Dispatches the registered interval callback for one widget id.
	local function dispatch_interval_handler_for(id)
		local handler = state.interval_handlers[id]
		if type(handler) ~= "function" then
			return
		end

		local ok, err = pcall(handler, {
			name = "interval",
			widget_id = id,
		})

		if not ok and log then
			log.error(
				"lua interval handler failed id="
					.. tostring(id)
					.. " error="
					.. tostring(err)
			)
		end
	end

	--- Returns the cadence needed to drive every registered interval callback.
	local function required_interval_tick_interval()
		local interval

		for _, id in ipairs(state.item_order) do
			local item = state.items[id]
			local handler = state.interval_handlers[id]

			if item ~= nil and type(handler) == "function" then
				local value = normalize_interval(item.props.interval)

				if value ~= nil then
					interval = interval == nil and value or gcd(interval, value)
				end
			end
		end

		return interval
	end

	--- Emits due interval callbacks for widgets with `interval`.
	local function dispatch_interval_if_due()
		local now = os.time()

		for _, id in ipairs(state.item_order) do
			local item = state.items[id]

			if item ~= nil and type(state.interval_handlers[id]) == "function" then
				local interval = normalize_interval(item.props.interval) or 0

				if interval > 0 then
					local next_due = state.interval_next_due[id] or 0

					if now >= next_due then
						state.interval_next_due[id] = now + interval
						dispatch_interval_handler_for(id)
					end
				end
			end
		end
	end

	--- Registers one widget-local interval callback.
	function subscriptions.set_interval_handler(id, handler)
		ensure_item_exists(id)
		assert(type(handler) == "function", "on_interval must be a function")
		state.interval_handlers[id] = handler
		state.interval_next_due[id] = 0
	end

	--- Resets one widget-local interval schedule after its cadence changes.
	function subscriptions.reset_interval_schedule(id)
		ensure_item_exists(id)
		state.interval_next_due[id] = 0
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
		end
	end

	--- Handles one incoming normalized EasyBar event.
	function subscriptions.handle_event(event)
		if event.name == "interval_tick" then
			dispatch_interval_if_due()
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

		local interval = required_interval_tick_interval()
		if interval ~= nil then
			events[INTERVAL_TICK_PREFIX .. tostring(interval)] = true
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
