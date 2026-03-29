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

--- Joins log arguments into one message string.
local function join_message(...)
	local parts = {}

	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end

	return table.concat(parts, " ")
end

--- Builds one widget-scoped EasyBar API instance.
function M.new(log)
	local registry = registry_module.new()
	local subscriptions = subscriptions_module.new(registry._state, registry.ensure_item_exists, log, event_tokens)

	local function log_widget(source, level, ...)
		if not log or type(log.widget) ~= "function" then
			return
		end

		log.widget(source or "widget", level or "INFO", join_message(...))
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

	--- Writes through the normal set(...) path.
	function api.animate(id, props, options)
		local _ = options
		api.set(id, props)
	end

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
			api.add(kind, id, props, widget_defaults)
		end

		widget_api.set = api.set
		widget_api.animate = api.animate
		widget_api.get = api.get
		widget_api.remove = api.remove
		widget_api.exec = api.exec
		widget_api.subscribe = api.subscribe
		widget_api.events = event_tokens.tokens

		--- Writes one widget log line through the host logger.
		function widget_api.log(level, ...)
			log_widget(source, level, ...)
		end

		return widget_api
	end

	return api
end

return M
