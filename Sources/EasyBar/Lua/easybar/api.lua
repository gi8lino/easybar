--- Module contract:
--- Owns the public EasyBar Lua API surface for one runtime registry.
--- Returns a registry-like object consumed by the loader, events, and renderer.
local M = {}

local base_dir = debug.getinfo(1, "S").source:match("^@(.*/)")

--- Loads one sibling runtime module.
local function load_module(name)
	local chunk, err = loadfile(base_dir .. name .. ".lua")

	if not chunk then
		error("failed to load easybar module '" .. name .. "': " .. tostring(err))
	end

	return chunk()
end

local event_tokens = load_module("event_tokens")
local registry_module = load_module("registry")
local subscriptions_module = load_module("subscriptions")

local LOG_LEVELS = {
	trace = "trace",
	debug = "debug",
	info = "info",
	warn = "warn",
	error = "error",
}

local KINDS = {
	item = "item",
	row = "row",
	column = "column",
	group = "group",
	popup = "popup",
	slider = "slider",
	progress = "progress",
	progress_slider = "progress_slider",
	sparkline = "sparkline",
	spaces = "spaces",
}

--- Joins log arguments into one message string.
local function join_message(...)
	local parts = {}

	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end

	return table.concat(parts, " ")
end

--- Returns one normalized uppercase host log level.
local function normalize_log_level(level)
	if type(level) ~= "string" then
		return "INFO"
	end

	local normalized = LOG_LEVELS[string.lower(level)]
	if normalized == nil then
		return "INFO"
	end

	return string.upper(normalized)
end

--- Returns one shallow copy of props without `on_interval`.
local function strip_interval_handler(props)
	if type(props) ~= "table" then
		return props
	end

	local copy = {}

	for key, value in pairs(props) do
		if key ~= "on_interval" then
			copy[key] = value
		end
	end

	return copy
end

--- Returns whether one interval value is valid.
local function valid_interval(value)
	local interval = tonumber(value)
	return interval ~= nil and interval > 0
end

--- Builds one widget-scoped EasyBar API instance.
function M.new(log)
	local registry = registry_module.new()
	local subscriptions = subscriptions_module.new(registry._state, registry.ensure_item_exists, log, event_tokens)

	local function log_widget(source, level, ...)
		if not log or type(log.widget) ~= "function" then
			return
		end

		log.widget(source or "widget", normalize_log_level(level), join_message(...))
	end

	local api = {
		_state = registry._state,
		add = registry.add,
		set = registry.set,
		get = registry.get,
		remove = registry.remove,
		exec = registry.exec,
		subscribe = subscriptions.subscribe,
		handle_event = subscriptions.handle_event,
		required_events = subscriptions.required_events,
	}

	--- Returns one widget-scoped EasyBar API.
	--- Defaults are isolated to this widget instance.
	function api.make_widget_api(source)
		local widget_api = {}
		local widget_defaults = {}

		--- Sets defaults for future add(...) calls in this widget only.
		function widget_api.default(props)
			widget_defaults = registry.merge_props(widget_defaults, props or {})
		end

		--- Clears defaults for this widget only.
		function widget_api.clear_defaults()
			widget_defaults = {}
		end

		--- Adds one item using this widget's scoped defaults.
		function widget_api.add(kind, id, props)
			local interval_handler = type(props) == "table" and props.on_interval or nil
			local item_props = strip_interval_handler(props)
			local merged = registry.merge_props(widget_defaults, item_props or {})

			if interval_handler ~= nil then
				assert(valid_interval(merged.interval), "on_interval requires interval > 0")
			elseif type(props) == "table" and props.interval ~= nil then
				error("interval requires on_interval")
			end

			api.add(kind, id, item_props, widget_defaults)

			if interval_handler ~= nil then
				subscriptions.set_interval_handler(id, interval_handler)
			end
		end

		--- Merges properties into one item and optionally updates its interval callback.
		function widget_api.set(id, props)
			local interval_handler = type(props) == "table" and props.on_interval or nil
			local item_props = strip_interval_handler(props)
			local merged = registry.merge_props(api.get(id), item_props or {})

			if interval_handler ~= nil then
				assert(valid_interval(merged.interval), "on_interval requires interval > 0")
			end

			api.set(id, item_props)

			if type(props) == "table" and props.interval ~= nil then
				subscriptions.reset_interval_schedule(id)
			end

			if interval_handler ~= nil then
				subscriptions.set_interval_handler(id, interval_handler)
			end
		end

		widget_api.get = api.get
		widget_api.remove = api.remove
		widget_api.exec = api.exec
		widget_api.subscribe = api.subscribe
		widget_api.events = event_tokens.tokens
		widget_api.kind = KINDS
		widget_api.level = LOG_LEVELS

		--- Writes one widget log line through the host logger.
		function widget_api.log(level, ...)
			log_widget(source, level, ...)
		end

		return widget_api
	end

	return api
end

return M
