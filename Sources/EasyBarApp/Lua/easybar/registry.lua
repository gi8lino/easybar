--- Module contract:
--- Owns widget item state, property normalization, and item tree mutation.
--- Returns one registry object with item CRUD helpers and raw `_state`.
--- Registry module table.
local M = {}
--- Shared table-copy helpers.
local helpers = require("easybar.helpers")

--- Returns one no-op callback when a hook is missing.
local function noop() end

--- Deep-merges one source table into one target table.
local function deep_merge(target, source)
	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if key == "context_menu" then
			target[key] = helpers.deep_copy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			deep_merge(target[key], value)
		else
			target[key] = helpers.deep_copy(value)
		end
	end

	return target
end

--- Splits one dot-separated property path into stable segments.
local function split_path(path)
	local segments = {}

	for segment in tostring(path):gmatch("[^%.]+") do
		segments[#segments + 1] = segment
	end

	return segments
end

--- Removes one nested key path from a table and prunes emptied tables.
local function unset_path(target, path)
	if type(target) ~= "table" then
		return false
	end

	local segments = split_path(path)
	if #segments == 0 then
		return false
	end

	local stack = {}
	local cursor = target

	for index = 1, #segments - 1 do
		local key = segments[index]
		if type(cursor[key]) ~= "table" then
			return false
		end

		stack[#stack + 1] = {
			parent = cursor,
			key = key,
		}
		cursor = cursor[key]
	end

	local leaf = segments[#segments]
	if cursor[leaf] == nil then
		return false
	end

	cursor[leaf] = nil

	for index = #stack, 1, -1 do
		local entry = stack[index]
		if next(entry.parent[entry.key]) ~= nil then
			break
		end
		entry.parent[entry.key] = nil
	end

	return true
end

--- Reports one invalid public API value and raises a user-facing error.
local function invalid_public_value(path, value, expected, report)
	report(path, value, expected)
	error(
		"invalid easybar value for " .. tostring(path) .. ": expected " .. tostring(expected) .. ", got " .. tostring(value)
	)
end

--- Normalizes one flexible boolean option into a real Lua boolean.
local function normalize_bool(value, default, path, report)
	if value == nil then
		return default
	end

	if value == true or value == "on" then
		return true
	end

	if value == false or value == "off" then
		return false
	end

	return invalid_public_value(path, value, "true, false, 'on', or 'off'", report)
end

--- Normalizes shorthand string-ish values into `{ string = ... }` tables.
local function normalize_string_prop(value)
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

local MAX_INLINE_SVG_BYTES = 256 * 1024
local MAX_CONTEXT_MENU_DEPTH = 8
local MAX_CONTEXT_MENU_ITEMS = 256
local MAX_CONTEXT_MENU_TEXT_BYTES = 1024

local function normalize_menu_bool(value, default, path, report)
	if value == nil then
		return default
	elseif value == true or value == "on" then
		return true
	elseif value == false or value == "off" then
		return false
	end
	report(path, value, "true, false, 'on', or 'off'")
	return default
end

--- Normalizes one recursive native context menu, dropping invalid entries safely.
local function normalize_context_menu(menu, path, report)
	if type(menu) ~= "table" then
		report(path, menu, "array of context menu entries")
		return {}
	end

	local item_count = 0
	local action_ids = {}

	local function normalize_entries(entries, entry_path, depth)
		if depth > MAX_CONTEXT_MENU_DEPTH then
			report(entry_path, entries, "context menu nesting at most 8 levels")
			return {}
		end

		local normalized = {}
		for index, entry in ipairs(entries) do
			item_count = item_count + 1
			local current_path = entry_path .. "[" .. tostring(index) .. "]"
			if item_count > MAX_CONTEXT_MENU_ITEMS then
				report(current_path, entry, "at most 256 context menu entries")
				break
			elseif type(entry) ~= "table" then
				report(current_path, entry, "context menu entry table")
			elseif entry.separator == true then
				normalized[#normalized + 1] = { separator = true }
			else
				local title = entry.title
				local submenu = entry.submenu
				local has_submenu = type(submenu) == "table"
				local id = entry.id
				if type(title) ~= "string" or title == "" or #title > MAX_CONTEXT_MENU_TEXT_BYTES then
					report(current_path .. ".title", title, "non-empty string at most 1024 UTF-8 bytes")
				elseif has_submenu then
					local children = normalize_entries(submenu, current_path .. ".submenu", depth + 1)
					if id ~= nil then
						report(current_path .. ".id", id, "no id on submenu headings")
					elseif #children == 0 then
						report(current_path .. ".submenu", submenu, "non-empty valid submenu")
					else
						normalized[#normalized + 1] = { title = title, submenu = children }
					end
				elseif type(id) ~= "string" or id == "" or #id > MAX_CONTEXT_MENU_TEXT_BYTES then
					report(current_path .. ".id", id, "non-empty string at most 1024 UTF-8 bytes")
				else
					if action_ids[id] then
						report(current_path .. ".id", id, "unique action id within this context menu")
					end
					action_ids[id] = true
					normalized[#normalized + 1] = {
						id = id,
						title = title,
						enabled = normalize_menu_bool(entry.enabled, true, current_path .. ".enabled", report),
						checked = normalize_menu_bool(entry.checked, false, current_path .. ".checked", report),
					}
				end
			end
		end
		return normalized
	end

	return normalize_entries(menu, path, 1)
end

--- Validates one structured image source while preserving its display options.
local function normalize_image_prop(image, path, report)
	if type(image) ~= "table" then
		return image
	end

	if image.path ~= nil and image.svg ~= nil then
		report(path, image, "path or svg, but not both")
		image.path = nil
		image.svg = nil
		return image
	end

	if image.path ~= nil and type(image.path) ~= "string" then
		report(path .. ".path", image.path, "string")
		image.path = nil
	end

	if image.svg ~= nil then
		if type(image.svg) ~= "string" or image.svg == "" then
			report(path .. ".svg", image.svg, "non-empty SVG string")
			image.svg = nil
		elseif #image.svg > MAX_INLINE_SVG_BYTES then
			report(path .. ".svg", image.svg, "SVG string at most 262144 UTF-8 bytes")
			image.svg = nil
		end
	end

	return image
end

--- Normalizes item props into the shape expected by the renderer.
local function normalize_props(props, report)
	local normalized = helpers.deep_copy(props or {})

	if normalized.label ~= nil then
		normalized.label = normalize_string_prop(normalized.label)
	end

	if normalized.icon ~= nil then
		normalized.icon = normalize_string_prop(normalized.icon)
		if type(normalized.icon) == "table" then
			normalized.icon.image = normalize_image_prop(normalized.icon.image, "icon.image", report)
		end
	end

	normalized.image = normalize_image_prop(normalized.image, "image", report)

	if normalized.context_menu ~= nil then
		normalized.context_menu = normalize_context_menu(normalized.context_menu, "context_menu", report)
	end

	if normalized.drawing ~= nil then
		normalized.drawing = normalize_bool(normalized.drawing, true, "drawing", report)
	end

	if type(normalized.popup) == "table" and normalized.popup.drawing ~= nil then
		normalized.popup.drawing = normalize_bool(normalized.popup.drawing, false, "popup.drawing", report)
	end

	return normalized
end

--- Trims command output for `easybar.exec(...)`.
local function trim_trailing_newlines(value)
	if not value then
		return ""
	end

	value = value:gsub("\r", "")
	value = value:gsub("\n+$", "")
	return value
end

--- Returns child ids for one parent, including popup-positioned children.
local function child_ids_of(state, id)
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

--- Removes one item and all descendants from the registry state.
local function remove_recursive(state, id)
	local children = child_ids_of(state, id)

	for _, child_id in ipairs(children) do
		remove_recursive(state, child_id)
	end

	state.items[id] = nil
	state.subscriptions[id] = nil
	state.interval_handlers[id] = nil

	for index, value in ipairs(state.item_order) do
		if value == id then
			table.remove(state.item_order, index)
			break
		end
	end
end

--- Returns one new registry object.
function M.new(hooks)
	hooks = hooks or {}

	local on_mutation = type(hooks.on_mutation) == "function" and hooks.on_mutation or noop
	local before_exec_callback = type(hooks.before_exec_callback) == "function" and hooks.before_exec_callback or noop
	local request_sync_command = type(hooks.request_sync_command) == "function" and hooks.request_sync_command or nil
	local request_async_command = type(hooks.request_async_command) == "function" and hooks.request_async_command or nil
	local request_async_process = type(hooks.request_async_process) == "function" and hooks.request_async_process or nil
	local request_cancel_async = type(hooks.request_cancel_async) == "function" and hooks.request_cancel_async or nil
	local request_timer = type(hooks.request_timer) == "function" and hooks.request_timer or nil
	local request_cancel_timer = type(hooks.request_cancel_timer) == "function" and hooks.request_cancel_timer or nil
	local before_async_callback = type(hooks.before_async_callback) == "function" and hooks.before_async_callback or noop
	local on_async_job_started = type(hooks.on_async_job_started) == "function" and hooks.on_async_job_started or noop
	local on_async_job_completed = type(hooks.on_async_job_completed) == "function" and hooks.on_async_job_completed
		or noop
	local on_async_callback_error = type(hooks.on_async_callback_error) == "function" and hooks.on_async_callback_error
		or noop
	local on_invalid_public_api = type(hooks.on_invalid_public_api) == "function" and hooks.on_invalid_public_api or noop
	local state = {
		items = {},
		item_order = {},
		subscriptions = {},
		interval_handlers = {},
		pending_async_commands = {},
		pending_command_responses = {},
		pending_timers = {},
	}

	local registry = {
		_state = state,
	}

	--- Returns one existing item or raises a user-facing error.
	function registry.ensure_item_exists(id)
		local item = state.items[id]

		if not item then
			error("easybar item does not exist: " .. tostring(id))
		end

		return item
	end

	--- Adds one item using optional scoped defaults.
	function registry.add(kind, id, props, defaults)
		assert(type(kind) == "string" and kind ~= "", "easybar.add(kind, id, props) requires kind")
		assert(type(id) == "string" and id ~= "", "easybar.add(kind, id, props) requires id")

		local merged = {}
		deep_merge(merged, normalize_props(defaults or {}, on_invalid_public_api))
		deep_merge(merged, normalize_props(props or {}, on_invalid_public_api))

		local is_new = state.items[id] == nil

		state.items[id] = {
			id = id,
			kind = kind,
			props = merged,
		}

		if is_new then
			state.item_order[#state.item_order + 1] = id
		end

		on_mutation()
	end

	--- Returns one merged property table using registry normalization rules.
	function registry.merge_props(defaults, props)
		local merged = {}
		deep_merge(merged, normalize_props(defaults or {}, on_invalid_public_api))
		deep_merge(merged, normalize_props(props or {}, on_invalid_public_api))
		return merged
	end

	--- Merges properties into one item.
	function registry.set(id, props)
		local item = registry.ensure_item_exists(id)
		deep_merge(item.props, normalize_props(props or {}, on_invalid_public_api))
		on_mutation()
	end

	--- Returns one copied item property table.
	function registry.get(id)
		local item = registry.ensure_item_exists(id)
		return helpers.deep_copy(item.props)
	end

	--- Removes one item and its descendants.
	function registry.remove(id)
		remove_recursive(state, id)
		on_mutation()
	end

	--- Removes one or more nested property paths from one item.
	function registry.unset(id, paths)
		local item = registry.ensure_item_exists(id)
		local changed = false

		if type(paths) == "string" and paths ~= "" then
			changed = unset_path(item.props, paths) or changed
		elseif type(paths) == "table" then
			for _, path in ipairs(paths) do
				if type(path) == "string" and path ~= "" then
					changed = unset_path(item.props, path) or changed
				end
			end
		else
			error("easybar.unset(id, paths) requires one string path or an array of string paths")
		end

		if changed then
			on_mutation()
		end
	end

	--- Returns one unique identifier for a background job.
	local function make_async_job_token()
		local micros = math.floor((os.clock() or 0) * 1000000)
		return tostring(os.time()) .. "_" .. tostring(micros) .. "_" .. tostring(#state.item_order + 1)
	end

	--- Returns extra driver events required by registry-owned background jobs.
	function registry.required_driver_events()
		return {}
	end

	--- Stores or dispatches one command response delivered by the Swift host.
	function registry.handle_command_response(token, output, code)
		assert(type(token) == "string" and token ~= "", "command response requires token")

		local pending = state.pending_async_commands[token]

		if pending == nil then
			state.pending_command_responses[token] = {
				output = trim_trailing_newlines(output),
				code = tonumber(code) or 1,
			}
			return false
		end

		state.pending_async_commands[token] = nil

		local normalized_output = trim_trailing_newlines(output)
		local normalized_code = tonumber(code) or 1

		on_async_job_completed(token, normalized_code)
		before_async_callback()

		local ok, err = pcall(pending.callback, normalized_output, normalized_code)
		if not ok then
			on_async_callback_error(pending.command, err)
		end

		return true
	end

	--- Returns and clears one stored synchronous command response by token.
	function registry.take_pending_command_response(token)
		local response = state.pending_command_responses[token]
		state.pending_command_responses[token] = nil
		return response
	end

	local COMMAND_OPTION_KEYS = {
		timeout_seconds = true,
		max_output_bytes = true,
	}

	--- Normalizes optional host command overrides for one exec call.
	local function normalize_command_options(options, signature)
		if options == nil then
			return nil
		end

		assert(type(options) == "table", signature .. " requires options table or nil")

		local normalized = {}

		for key in pairs(options) do
			assert(
				COMMAND_OPTION_KEYS[key] == true,
				signature .. " received unknown option '" .. tostring(key) .. "'; expected timeout_seconds or max_output_bytes"
			)
		end

		if options.timeout_seconds ~= nil then
			local timeout_seconds = tonumber(options.timeout_seconds)
			assert(timeout_seconds ~= nil and timeout_seconds > 0, signature .. " requires options.timeout_seconds > 0")
			normalized.timeout_seconds = timeout_seconds
		end

		if options.max_output_bytes ~= nil then
			local max_output_bytes = tonumber(options.max_output_bytes)
			assert(
				max_output_bytes ~= nil and max_output_bytes > 0 and math.floor(max_output_bytes) == max_output_bytes,
				signature .. " requires options.max_output_bytes as positive integer"
			)
			normalized.max_output_bytes = max_output_bytes
		end

		if next(normalized) == nil then
			return nil
		end

		return normalized
	end

	--- Validates one direct executable argument vector.
	local function normalize_process_arguments(arguments, signature)
		assert(type(arguments) == "table", signature .. " requires an argument array")
		local normalized = {}
		local length = #arguments
		for key in pairs(arguments) do
			assert(
				type(key) == "number" and key >= 1 and key <= length and math.floor(key) == key,
				signature .. " requires a dense argument array"
			)
		end
		for index, value in ipairs(arguments) do
			assert(type(value) == "string", signature .. " requires string arguments")
			assert(not value:find("%z"), signature .. " rejects NUL bytes")
			normalized[index] = value
		end
		assert(#normalized > 0 and normalized[1] ~= "", signature .. " requires a non-empty executable")
		return normalized
	end

	--- Starts one background host-owned executable without shell parsing.
	function registry.spawn_async(arguments, options, callback, ...)
		local signature = "easybar.spawn_async(arguments, options, callback)"
		assert(select("#", ...) == 0, signature .. " does not accept extra arguments")
		assert(type(callback) == "function", signature .. " requires callback")
		assert(type(request_async_process) == "function", "easybar.spawn_async unavailable without host runner")

		local normalized_arguments = normalize_process_arguments(arguments, signature)
		local normalized_options = normalize_command_options(options, signature)
		local token = request_async_process(normalized_arguments, normalized_options) or make_async_job_token()
		local display_command = table.concat(normalized_arguments, " ")

		state.pending_async_commands[token] = {
			command = display_command,
			callback = callback,
		}

		on_async_job_started(token, display_command)
		return token
	end

	--- Schedules one host-owned, non-blocking callback.
	function registry.after(delay_seconds, callback, ...)
		local signature = "easybar.after(delay_seconds, callback)"
		assert(select("#", ...) == 0, signature .. " does not accept extra arguments")
		local delay = tonumber(delay_seconds)
		assert(
			delay ~= nil and delay == delay and delay ~= math.huge and delay ~= -math.huge and delay >= 0,
			signature .. " requires a finite delay >= 0"
		)
		assert(type(callback) == "function", signature .. " requires callback")
		assert(type(request_timer) == "function", "easybar.after unavailable without host timer")
		assert(type(request_cancel_timer) == "function", "easybar.after unavailable without host timer cancellation")

		local token = request_timer(delay) or make_async_job_token()
		state.pending_timers[token] = callback
		local handle = { token = token }

		function handle:cancel()
			if state.pending_timers[self.token] == nil then
				return false
			end
			state.pending_timers[self.token] = nil
			request_cancel_timer(self.token)
			return true
		end

		return handle
	end

	--- Dispatches one fired host timer callback exactly once.
	function registry.handle_timer_fired(token)
		local callback = state.pending_timers[token]
		if callback == nil then
			return false
		end
		state.pending_timers[token] = nil
		before_async_callback()
		local ok, err = pcall(callback)
		if not ok then
			on_async_callback_error("timer", err)
		end
		return true
	end

	--- Starts one background host-owned shell command.
	function registry.exec_async(command, options, callback, ...)
		assert(
			type(command) == "string" and command ~= "",
			"easybar.exec_async(command, options, callback) requires command"
		)
		assert(select("#", ...) == 0, "easybar.exec_async(command, options, callback) does not accept extra arguments")
		assert(type(callback) == "function", "easybar.exec_async(command, options, callback) requires callback")
		assert(type(request_async_command) == "function", "easybar.exec_async unavailable without host runner")

		local normalized_options = normalize_command_options(options, "easybar.exec_async(command, options, callback)")
		local token = request_async_command(command, normalized_options) or make_async_job_token()

		state.pending_async_commands[token] = {
			command = command,
			callback = callback,
		}

		on_async_job_started(token, command)

		return token
	end

	--- Requests cancellation of one pending background host command.
	function registry.cancel_async(token, ...)
		assert(type(token) == "string" and token ~= "", "easybar.cancel_async(token) requires token")
		assert(select("#", ...) == 0, "easybar.cancel_async(token) does not accept extra arguments")
		assert(type(request_cancel_async) == "function", "easybar.cancel_async unavailable without host runner")

		if state.pending_async_commands[token] == nil then
			return false
		end

		request_cancel_async(token)
		return true
	end

	--- Runs one host-owned shell command.
	function registry.exec(command, options, ...)
		assert(type(command) == "string" and command ~= "", "easybar.exec(command, options) requires command")
		assert(select("#", ...) == 0, "easybar.exec(command, options) does not accept a callback")
		assert(type(request_sync_command) == "function", "easybar.exec unavailable without host runner")

		local normalized_options = normalize_command_options(options, "easybar.exec(command, options)")
		before_exec_callback()
		local output, code = request_sync_command(command, normalized_options)
		output = trim_trailing_newlines(output)
		code = tonumber(code) or 1

		return output, code
	end

	return registry
end

return M
