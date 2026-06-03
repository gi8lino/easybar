--- Module contract:
--- Owns Lua process startup, host handshake, and socket-backed standard-stream event processing.
--- Returns nothing and runs the EasyBar Lua runtime loop.
--- Returns the directory containing `runtime.lua`.
local function runtime_dir()
	local source = debug.getinfo(1, "S").source
	if source:sub(1, 1) == "@" then
		source = source:sub(2)
	end
	return source:match("^(.*)/[^/]+$") or "."
end

--- Runtime module root directory.
local base_dir = runtime_dir()
local PROTOCOL_VERSION = 1
--- Adds bundled runtime modules to the Lua module path.
package.path = base_dir .. "/?.lua;" .. package.path

--- Loads one bundled runtime module by name.
local function load_module(name)
	local path = base_dir .. "/easybar/" .. name .. ".lua"
	local chunk, err = loadfile(path)

	if not chunk then
		error("failed to load module '" .. name .. "' from " .. path .. ": " .. tostring(err))
	end

	return chunk()
end

--- Runtime logger module.
local log = load_module("log")
--- Runtime JSON codec module.
local json = load_module("json")
--- Public EasyBar API module.
local api = load_module("api")
--- Widget loader module.
local loader = load_module("loader")
--- Event normalization and dispatch module.
local events = load_module("events")
--- Registry renderer module.
local render = load_module("render")

--- Widget directory passed by the Swift host.
local widget_dir = arg[1]
local widget_files = {}

if not widget_dir or widget_dir == "" then
	local home = os.getenv("HOME")
	widget_dir = home .. "/.config/easybar/widgets"
end

for index = 2, #arg do
	widget_files[#widget_files + 1] = arg[index]
end

--- Runtime registry and widget API instance.
local registry
local render_dirty = false
local last_subscription_payload = nil
local next_command_sequence = 0
local runtime_command_session = tostring({}):gsub("[^%w]", "_")
local default_exec_options = {
	timeout_seconds = tonumber(os.getenv("EASYBAR_LUA_COMMAND_TIMEOUT_SECONDS")),
	max_output_bytes = tonumber(os.getenv("EASYBAR_LUA_COMMAND_MAX_OUTPUT_BYTES")),
}

--- Marks the current runtime state as needing one render flush.
local function mark_render_dirty()
	render_dirty = true
end

--- Emits the current tree snapshot when a Lua turn mutated widget state.
local function flush_pending_render(force)
	if not force and not render_dirty then
		return
	end

	render.emit_all(registry, log, json)
	render_dirty = false
end

--- Emits runtime subscription requirements when they changed.
local function emit_subscriptions(force)
	local payload = json.encode({
		protocol_version = PROTOCOL_VERSION,
		type = "subscriptions",
		events = registry.required_events(),
	})

	if not force and payload == last_subscription_payload then
		return
	end

	last_subscription_payload = payload
	io.stdout:write(payload .. "\n")
	io.stdout:flush()
end

--- Flushes pending runtime outputs after one logical Lua turn.
local function flush_pending_outputs(force_render, force_subscriptions)
	flush_pending_render(force_render)
	emit_subscriptions(force_subscriptions)
end

--- Sends one structured payload to the Swift host.
local function send_payload(payload)
	io.stdout:write(json.encode(payload) .. "\n")
	io.stdout:flush()
end

--- Returns one unique command token.
local function next_command_token()
	next_command_sequence = next_command_sequence + 1
	return runtime_command_session .. ":" .. tostring(next_command_sequence)
end

--- Sends one command request to the Swift host.
local function send_command_request(command, synchronous, options)
	local token = next_command_token()

	local payload = {
		protocol_version = PROTOCOL_VERSION,
		type = "command_request",
		token = token,
		command = tostring(command),
		sync = synchronous == true,
	}

	if type(options) == "table" then
		if options.timeout_seconds ~= nil then
			payload.timeout_seconds = options.timeout_seconds
		end

		if options.max_output_bytes ~= nil then
			payload.max_output_bytes = options.max_output_bytes
		end
	end

	send_payload(payload)

	return token
end

--- Dispatches one host command response into the registry and flushes any callback mutations.
local function handle_command_response(payload)
	if type(payload.token) ~= "string" or payload.token == "" then
		log.error("runtime ignored command response missing token")
		return
	end

	local output = payload.output
	if output == nil then
		output = ""
	elseif type(output) ~= "string" then
		output = tostring(output)
	end

	registry.handle_command_response(payload.token, output, tonumber(payload.status) or 1)
	flush_pending_outputs(false, false)
end

--- Dispatches one JSON-decoded host payload by kind.
local function handle_host_payload(payload, raw_line)
	if type(payload) ~= "table" then
		log.error("runtime ignored non-table host payload=" .. tostring(raw_line))
		return
	end

	if payload.type == "command_response" then
		handle_command_response(payload)
		return
	end

	if type(payload.name) ~= "string" or payload.name == "" then
		log.error("runtime ignored invalid json payload=" .. tostring(raw_line))
		return
	end

	local event = events.normalize_event(payload)
	events.dispatch_event(registry, event, function(force_render)
		flush_pending_outputs(force_render, false)
	end, log)
end

--- Reads, decodes, and handles one host payload line.
local function process_next_host_message()
	local line = io.read()

	if not line then
		return false
	end

	log.trace("runtime stdin " .. tostring(line))

	local ok, payload = pcall(json.decode, line)

	if not ok then
		log.error("runtime ignored invalid json payload=" .. tostring(line))
		return true
	end

	handle_host_payload(payload, line)
	return true
end

--- Runs one host-owned command synchronously and returns trimmed output plus exit code.
local function request_sync_command(command, options)
	local token = send_command_request(command, true, options)

	while true do
		local response = registry.take_pending_command_response(token)
		if response ~= nil then
			return response.output, response.code
		end

		if not process_next_host_message() then
			return "", 1
		end
	end
end

--- Starts one host-owned asynchronous command and returns its token.
local function request_async_command(command, options)
	return send_command_request(command, false, options)
end

registry = api.new(log, {
	on_mutation = mark_render_dirty,
	before_exec_callback = flush_pending_render,
	before_async_callback = flush_pending_render,
	request_sync_command = request_sync_command,
	request_async_command = request_async_command,
	on_async_job_started = function(token, command)
		log.debug("lua async started token=" .. tostring(token) .. " command=" .. tostring(command))
	end,
	on_async_job_completed = function(token, code)
		log.debug("lua async completed token=" .. tostring(token) .. " code=" .. tostring(code))
	end,
	on_async_callback_error = function(command, err)
		log.error("lua async callback failed command=" .. tostring(command) .. " error=" .. tostring(err))
	end,
	on_invalid_public_api = function(path, value, expected)
		log.error(
			"lua rejected invalid public api value path="
				.. tostring(path)
				.. " value="
				.. tostring(value)
				.. " expected="
				.. tostring(expected)
		)
	end,
	default_exec_options = default_exec_options,
})

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

-- Load every user widget before announcing subscriptions to the host.
loader.load_widgets(widget_dir, widget_files, registry, log)

emit_subscriptions(true)
send_payload({
	protocol_version = PROTOCOL_VERSION,
	type = "ready",
})

-- Emit the full initial widget trees once the runtime handshake is complete.
flush_pending_outputs(true, false)

while process_next_host_message() do
end
