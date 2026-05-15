--- Module contract:
--- Owns widget item state, property normalization, and item tree mutation.
--- Returns one registry object with item CRUD helpers and raw `_state`.
--- Registry module table.
local M = {}
--- Shared table-copy helpers.
local helpers = require("easybar.helpers")

--- Returns one no-op callback when a hook is missing.
local function noop()
end

--- Quotes one shell argument for POSIX sh.
local function shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

--- Deep-merges one source table into one target table.
local function deep_merge(target, source)
	if type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" and type(target[key]) == "table" then
			deep_merge(target[key], value)
		else
			target[key] = helpers.deep_copy(value)
		end
	end

	return target
end

--- Normalizes one flexible boolean option into a real Lua boolean.
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

--- Normalizes item props into the shape expected by the renderer.
local function normalize_props(props)
	local normalized = helpers.deep_copy(props or {})

	if normalized.label ~= nil then
		normalized.label = normalize_string_prop(normalized.label)
	end

	if normalized.icon ~= nil then
		normalized.icon = normalize_string_prop(normalized.icon)
	end

	if normalized.drawing ~= nil then
		normalized.drawing = normalize_bool(normalized.drawing, true)
	end

	if type(normalized.popup) == "table" and normalized.popup.drawing ~= nil then
		normalized.popup.drawing = normalize_bool(normalized.popup.drawing, false)
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
	state.interval_next_due[id] = nil

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
	local before_async_callback =
		type(hooks.before_async_callback) == "function" and hooks.before_async_callback or noop
	local on_async_jobs_changed =
		type(hooks.on_async_jobs_changed) == "function" and hooks.on_async_jobs_changed or noop
	local on_async_job_started =
		type(hooks.on_async_job_started) == "function" and hooks.on_async_job_started or noop
	local on_async_job_completed =
		type(hooks.on_async_job_completed) == "function" and hooks.on_async_job_completed or noop
	local on_async_callback_error =
		type(hooks.on_async_callback_error) == "function" and hooks.on_async_callback_error or noop

	local state = {
		items = {},
		item_order = {},
		subscriptions = {},
		interval_handlers = {},
		interval_next_due = {},
		async_jobs = {},
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
		deep_merge(merged, normalize_props(defaults or {}))
		deep_merge(merged, normalize_props(props or {}))

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
		deep_merge(merged, normalize_props(defaults or {}))
		deep_merge(merged, normalize_props(props or {}))
		return merged
	end

	--- Merges properties into one item.
	function registry.set(id, props)
		local item = registry.ensure_item_exists(id)
		deep_merge(item.props, normalize_props(props or {}))
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

	--- Returns one unique identifier for a background job.
	local function make_async_job_token()
		local micros = math.floor((os.clock() or 0) * 1000000)
		return tostring(os.time()) .. "_" .. tostring(micros) .. "_" .. tostring(#state.async_jobs + 1)
	end

	--- Returns one temp-file base path for a background job.
	local function async_job_base_path(token)
		local tmpdir = os.getenv("TMPDIR") or "/tmp"
		return tmpdir .. "/easybar-async-" .. token
	end

	--- Reads one whole file or returns the fallback.
	local function read_file(path, fallback)
		local handle = io.open(path, "r")
		if not handle then
			return fallback
		end

		local content = handle:read("*a")
		handle:close()
		return content or fallback
	end

	--- Deletes one async job's temp files.
	local function clear_async_job_files(job)
		os.remove(job.output_path)
		os.remove(job.rc_path)
	end

	--- Returns extra driver events required by registry-owned background jobs.
	function registry.required_driver_events()
		if #state.async_jobs == 0 then
			return {}
		end

		return { "interval_tick:0.25" }
	end

	--- Starts one background shell command and completes it through later polling.
	function registry.exec_async(command, callback)
		assert(
			type(command) == "string" and command ~= "",
			"easybar.exec_async(command, callback) requires command"
		)
		assert(type(callback) == "function", "easybar.exec_async(command, callback) requires callback")

		local previous_count = #state.async_jobs
		local token = make_async_job_token()
		local base_path = async_job_base_path(token)
		local job = {
			token = token,
			command = command,
			callback = callback,
			output_path = base_path .. ".out",
			rc_path = base_path .. ".rc",
		}

		local launch_script = "out="
			.. shell_quote(job.output_path)
			.. " rc="
			.. shell_quote(job.rc_path)
			.. ' ; rm -f "$out" "$rc" ; ( ( '
			.. command
			.. ' ) >"$out" 2>&1 ; printf \'%s\\n\' "$?" >"$rc" ) >/dev/null 2>&1 &'

		local ok = os.execute("/bin/sh -c " .. shell_quote(launch_script) .. " >/dev/null 2>&1")
		if ok == nil then
			error("failed to start async command")
		end

		state.async_jobs[#state.async_jobs + 1] = job

		if previous_count ~= #state.async_jobs then
			on_async_jobs_changed()
		end

		on_async_job_started(token, command)

		return token
	end

	--- Polls background jobs and runs ready callbacks.
	function registry.poll_async_jobs()
		local index = 1

		while index <= #state.async_jobs do
			local job = state.async_jobs[index]
			local rc_text = read_file(job.rc_path, nil)

			if rc_text == nil then
				index = index + 1
			else
				local previous_count = #state.async_jobs
				table.remove(state.async_jobs, index)

				local code = tonumber((rc_text or ""):match("^%s*(%-?%d+)")) or 1
				local output = trim_trailing_newlines(read_file(job.output_path, ""))
				clear_async_job_files(job)

				if previous_count ~= #state.async_jobs then
					on_async_jobs_changed()
				end

				on_async_job_completed(job.token, code)

				before_async_callback()

				local ok, err = pcall(job.callback, output, code)
				if not ok then
					on_async_callback_error(job.command, err)
				end
			end
		end
	end

	--- Runs one shell command.
	function registry.exec(command, callback)
		assert(type(command) == "string" and command ~= "", "easybar.exec(command, callback) requires command")

		local pipe = io.popen(command .. " 2>/dev/null")
		local output = ""

		if pipe then
			output = trim_trailing_newlines(pipe:read("*a") or "")
			pipe:close()
		end

		if type(callback) == "function" then
			before_exec_callback()
			return callback(output)
		end

		return output
	end

	return registry
end

return M
