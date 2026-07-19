--- Module contract:
--- Owns the public EasyBar Lua API surface for one runtime registry.
--- Returns a registry-like object consumed by the loader, events, and renderer.

--- Public EasyBar API module table.
local M = {}

--- Directory containing this module and its siblings.
local base_dir = debug.getinfo(1, "S").source:match("^@(.*/)")

--- Loads one sibling runtime module.
local function load_module(name)
	local chunk, err = loadfile(base_dir .. name .. ".lua")

	if not chunk then
		error("failed to load easybar module '" .. name .. "': " .. tostring(err))
	end

	return chunk()
end

--- Event token module used by node subscriptions.
local event_tokens = load_module("event_tokens")
--- JSON helper module exposed through the public widget API.
local json_module = load_module("json")
--- Active theme module exposed through the public widget API.
local theme_module = load_module("theme")
--- Registry module used to store widget node state.
local registry_module = load_module("registry")
--- Subscription module used for event and interval callbacks.
local subscriptions_module = load_module("subscriptions")

--- Supported widget log levels.
local LOG_LEVELS = {
	trace = "trace",
	debug = "debug",
	info = "info",
	warn = "warn",
	error = "error",
}

--- Supported EasyBar node kinds.
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

--- Internal environment variable containing the configured logging directory.
local LOG_DIR_ENV = "EASYBAR_INTERNAL_LOGGING_DIRECTORY"

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

--- Returns the configured log directory exposed to Lua widgets.
local function configured_log_dir()
	local configured = os.getenv(LOG_DIR_ENV)
	if type(configured) == "string" and configured ~= "" then
		return configured
	end

	return (os.getenv("HOME") or "/tmp") .. "/.local/state/easybar"
end

--- Returns a safe widget log file name, or nil plus an error message.
local function validate_log_file_name(file_name)
	file_name = tostring(file_name or "")

	if file_name == "" then
		return nil, "log file name is required"
	end

	if file_name == "." or file_name == ".." then
		return nil, "log file name must be a plain file name"
	end

	if file_name:find("/", 1, true) or file_name:find("\\", 1, true) then
		return nil, "log file name must not contain path separators"
	end

	if file_name:find("%z") or file_name:find("[\r\n]") then
		return nil, "log file name must not contain control characters"
	end

	return file_name, nil
end

--- Returns the absolute path for one widget log file inside the configured log directory.
local function widget_log_path(log_dir, file_name)
	return tostring(log_dir or configured_log_dir()) .. "/" .. file_name
end

--- Appends text to one widget log file and ensures the file ends with a newline.
local function append_widget_log(log_dir, file_name, text)
	local validated, validation_error = validate_log_file_name(file_name)
	if validated == nil then
		return false, validation_error
	end

	local file, err = io.open(widget_log_path(log_dir, validated), "a")
	if file == nil then
		return false, tostring(err)
	end

	text = tostring(text or "")
	file:write(text)
	if text == "" or text:sub(-1) ~= "\n" then
		file:write("\n")
	end
	file:close()

	return true, nil
end

--- Reads all lines from one widget log file.
local function read_widget_log_lines(log_dir, file_name)
	local validated, validation_error = validate_log_file_name(file_name)
	if validated == nil then
		return nil, validation_error
	end

	local file = io.open(widget_log_path(log_dir, validated), "r")
	if file == nil then
		return {}, nil
	end

	local lines = {}
	for line in file:lines() do
		lines[#lines + 1] = line
	end
	file:close()

	return lines, nil
end

--- Rewrites one widget log file with the provided lines.
local function write_widget_log_lines(log_dir, file_name, lines)
	local validated, validation_error = validate_log_file_name(file_name)
	if validated == nil then
		return false, validation_error
	end

	local file, err = io.open(widget_log_path(log_dir, validated), "w")
	if file == nil then
		return false, tostring(err)
	end

	for _, line in ipairs(lines or {}) do
		file:write(tostring(line or ""), "\n")
	end
	file:close()

	return true, nil
end

--- Returns the newest log lines as one newline-delimited string.
local function tail_widget_log(log_dir, file_name, limit)
	local lines, err = read_widget_log_lines(log_dir, file_name)
	if lines == nil then
		return "", err
	end

	limit = tonumber(limit) or 0
	if limit <= 0 or #lines == 0 then
		return "", nil
	end

	local start = math.max(1, #lines - limit + 1)
	local tail = {}
	for index = start, #lines do
		tail[#tail + 1] = lines[index]
	end

	return table.concat(tail, "\n"), nil
end

--- Keeps only the newest lines in one widget log file.
local function trim_widget_log(log_dir, file_name, limit)
	local lines, err = read_widget_log_lines(log_dir, file_name)
	if lines == nil then
		return false, err
	end

	limit = tonumber(limit) or 0
	if limit <= 0 then
		return write_widget_log_lines(log_dir, file_name, {})
	end

	if #lines <= limit then
		return true, nil
	end

	local start = #lines - limit + 1
	local kept = {}
	for index = start, #lines do
		kept[#kept + 1] = lines[index]
	end

	return write_widget_log_lines(log_dir, file_name, kept)
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
function M.new(log, hooks)
	local registry = registry_module.new(hooks)
	local subscriptions = subscriptions_module.new(registry._state, registry.ensure_item_exists, log, event_tokens)
	local default_exec_options = type(hooks.default_exec_options) == "table" and hooks.default_exec_options or {}
	local log_dir = configured_log_dir()
	local inbox_action_handlers = {}
	local inbox_context_action_handlers = {}

	local function readonly_copy(values, name)
		local copy = {}

		for key, value in pairs(values) do
			copy[key] = value
		end

		local proxy = {}

		return setmetatable(proxy, {
			__index = copy,
			__newindex = function()
				error(tostring(name) .. " is read-only")
			end,
			__pairs = function()
				return pairs(copy)
			end,
			__metatable = false,
		})
	end

	local function log_widget(source, level, ...)
		if not log or type(log.widget) ~= "function" then
			return
		end

		log.widget(source or "widget", normalize_log_level(level), join_message(...))
	end

	local function log_file_warning(source, message, err)
		log_widget(source, "warn", "widget log file", message, tostring(err or "unknown error"))
	end

	local function file_log_line(level, prefix, ...)
		local normalized_level = string.lower(normalize_log_level(level))
		local message
		if type(prefix) == "string" and prefix ~= "" then
			message = join_message(prefix, ...)
		else
			message = join_message(...)
		end

		return os.date("%Y-%m-%dT%H:%M:%S%z") .. " [" .. normalized_level .. "] " .. message
	end

	local function log_widget_with_prefix(source, level, prefix, ...)
		if type(prefix) == "string" and prefix ~= "" then
			log_widget(source, level, prefix, ...)
		else
			log_widget(source, level, ...)
		end
	end

	local function make_prefixed_logger(source, prefix)
		if type(prefix) ~= "string" then
			error("log prefix must be a string")
		end

		return setmetatable({}, {
			__call = function(_, level, ...)
				log_widget_with_prefix(source, level, prefix, ...)
			end,
		})
	end

	local function make_file_logger(source, file_name, options)
		local validated, validation_error = validate_log_file_name(file_name)
		if validated == nil then
			error(validation_error)
		end

		options = type(options) == "table" and options or {}
		local prefix = type(options.prefix) == "string" and options.prefix or nil
		local logger = {}

		function logger.append(text)
			return append_widget_log(log_dir, validated, text)
		end

		function logger.line(text)
			return append_widget_log(log_dir, validated, tostring(text or ""))
		end

		function logger.tail(limit)
			local tail, err = tail_widget_log(log_dir, validated, limit)
			if err ~= nil then
				log_file_warning(source, "tail failed", err)
			end
			return tail
		end

		function logger.trim(limit)
			return trim_widget_log(log_dir, validated, limit)
		end

		return setmetatable(logger, {
			__call = function(_, level, ...)
				log_widget_with_prefix(source, level, prefix, ...)

				local ok, err = append_widget_log(log_dir, validated, file_log_line(level, prefix, ...))
				if not ok then
					log_file_warning(source, "append failed", err)
				end

				return ok, err
			end,
		})
	end

	local function make_log_api(source)
		local logger = {}

		function logger.with_prefix(prefix)
			return make_prefixed_logger(source, prefix)
		end

		function logger.with_file(file_name, options)
			return make_file_logger(source, file_name, options)
		end

		return setmetatable(logger, {
			__call = function(_, level, ...)
				log_widget(source, level, ...)
			end,
		})
	end

	local function required_events()
		local merged = {}

		for _, event_name in ipairs(subscriptions.required_events()) do
			merged[event_name] = true
		end

		for _, event_name in ipairs(registry.required_driver_events()) do
			merged[event_name] = true
		end

		local result = {}

		for event_name in pairs(merged) do
			result[#result + 1] = event_name
		end

		table.sort(result)
		return result
	end

	local function handle_event(event)
		if event.name == "inbox.action" then
			local handlers = inbox_action_handlers[tostring(event.source or "")]
			for _, handler in ipairs(handlers or {}) do
				local ok, err = pcall(handler, event)
				if not ok then
					log.error("inbox action handler failed source=" .. tostring(event.source) .. " error=" .. tostring(err))
				end
			end
		end
		if event.name == "inbox.context_action" then
			local handlers = inbox_context_action_handlers[tostring(event.source or "")]
			for _, handler in ipairs(handlers or {}) do
				local ok, err = pcall(handler, event)
				if not ok then
					log.error(
						"inbox context action handler failed source=" .. tostring(event.source) .. " error=" .. tostring(err)
					)
				end
			end
		end
		subscriptions.handle_event(event)
	end

	local api = {
		_state = registry._state,
		add = registry.add,
		DEFAULT_EXEC_OPTIONS = readonly_copy(default_exec_options, "easybar.DEFAULT_EXEC_OPTIONS"),
		set = registry.set,
		unset = registry.unset,
		get = registry.get,
		remove = registry.remove,
		exec = registry.exec,
		exec_async = registry.exec_async,
		cancel_async = registry.cancel_async,
		handle_command_response = registry.handle_command_response,
		take_pending_command_response = registry.take_pending_command_response,
		subscribe = subscriptions.subscribe,
		handle_event = handle_event,
		required_events = required_events,
		log_dir = log_dir,
		theme = theme_module.current(),
	}

	--- Returns one widget-scoped EasyBar API.
	--- Defaults are isolated to this widget instance.
	function api.make_widget_api(source)
		local widget_api = {}
		local widget_defaults = {}
		local source_directory = tostring(source):match("^(.*)/[^/]+$") or "."

		--- Resolves one safe path relative to this widget's source directory.
		function widget_api.asset(path)
			if type(path) ~= "string" or path == "" then
				error("easybar.asset(path) requires a non-empty relative path")
			end

			if path:sub(1, 1) == "/" then
				error("easybar.asset(path) rejects absolute paths")
			end

			local segments = {}
			for segment in path:gmatch("[^/]+") do
				if segment == ".." then
					if #segments == 0 then
						error("easybar.asset(path) cannot escape the widget directory")
					end
					segments[#segments] = nil
				elseif segment ~= "." then
					segments[#segments + 1] = segment
				end
			end

			if #segments == 0 then
				error("easybar.asset(path) requires a non-empty relative path")
			end

			return source_directory .. "/" .. table.concat(segments, "/")
		end

		--- Merges properties into one item and optionally updates its interval callback.
		local function set_node(id, props)
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

		--- Builds one node handle for the public object-style API.
		local function make_node_handle(id)
			local handle = {
				id = id,
				name = id,
			}

			--- Merges properties into this node.
			function handle:set(props)
				return set_node(self.id, props)
			end

			--- Returns a copy of this node's current properties.
			function handle:get()
				return api.get(self.id)
			end

			--- Removes this node and all descendants.
			function handle:remove()
				return api.remove(self.id)
			end

			--- Removes one or more nested properties from this node.
			function handle:unset(paths)
				return api.unset(self.id, paths)
			end

			--- Subscribes this node to one or more events.
			function handle:subscribe(events, handler)
				return api.subscribe(self.id, events, handler)
			end

			return handle
		end

		--- Sets defaults for future add(...) calls in this widget only.
		function widget_api.default(props)
			widget_defaults = registry.merge_props(widget_defaults, props or {})
		end

		--- Clears defaults for this widget only.
		function widget_api.clear_defaults()
			widget_defaults = {}
		end

		--- Merges properties into one existing node by id.
		function widget_api.set(id, props)
			return set_node(id, props)
		end

		--- Returns a copy of one existing node's current properties.
		function widget_api.get(id)
			return api.get(id)
		end

		--- Removes one or more nested properties from one existing node.
		function widget_api.unset(id, paths)
			return api.unset(id, paths)
		end

		--- Removes one existing node and all descendants.
		function widget_api.remove(id)
			return api.remove(id)
		end

		--- Subscribes one existing node to one or more events.
		function widget_api.subscribe(id, events, handler)
			return api.subscribe(id, events, handler)
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

			return make_node_handle(id)
		end

		widget_api.exec = api.exec
		widget_api.exec_async = api.exec_async
		widget_api.cancel_async = api.cancel_async
		widget_api.DEFAULT_EXEC_OPTIONS = api.DEFAULT_EXEC_OPTIONS
		widget_api.events = event_tokens.tokens
		widget_api.json = json_module
		widget_api.kind = KINDS
		widget_api.level = LOG_LEVELS
		widget_api.log_dir = api.log_dir
		widget_api.theme = theme_module.current()
		widget_api.inbox = {}

		function widget_api.inbox.replace(source, items)
			assert(type(source) == "string" and source ~= "", "inbox source must be a non-empty string")
			assert(type(items) == "table", "inbox items must be an array")
			hooks.publish_inbox(source, items)
		end

		function widget_api.inbox.clear(source)
			assert(type(source) == "string" and source ~= "", "inbox source must be a non-empty string")
			hooks.clear_inbox(source)
		end

		function widget_api.inbox.configure(source, configuration)
			assert(type(source) == "string" and source ~= "", "inbox source must be a non-empty string")
			assert(type(configuration) == "table", "inbox configuration must be a table")
			local actions = configuration.actions or {}
			assert(type(actions) == "table", "inbox configuration actions must be an array")
			hooks.configure_inbox(source, actions)
		end

		function widget_api.inbox.on_action(source, handler)
			assert(type(source) == "string" and source ~= "", "inbox source must be a non-empty string")
			assert(type(handler) == "function", "inbox action handler must be a function")
			inbox_action_handlers[source] = inbox_action_handlers[source] or {}
			table.insert(inbox_action_handlers[source], handler)
		end

		function widget_api.inbox.on_context_action(source, handler)
			assert(type(source) == "string" and source ~= "", "inbox source must be a non-empty string")
			assert(type(handler) == "function", "inbox context action handler must be a function")
			inbox_context_action_handlers[source] = inbox_context_action_handlers[source] or {}
			table.insert(inbox_context_action_handlers[source], handler)
		end

		widget_api.log = make_log_api(source)

		return widget_api
	end

	return api
end

return M
