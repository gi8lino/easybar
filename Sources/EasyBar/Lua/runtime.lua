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

registry = api.new(log, {
	on_mutation = mark_render_dirty,
	before_exec_callback = flush_pending_render,
	before_async_callback = flush_pending_render,
	on_async_jobs_changed = emit_subscriptions,
	on_async_job_started = function(token, command)
		log.debug("lua async started token=" .. tostring(token) .. " command=" .. tostring(command))
	end,
	on_async_job_completed = function(token, code)
		log.debug("lua async completed token=" .. tostring(token) .. " code=" .. tostring(code))
	end,
	on_async_callback_error = function(command, err)
		log.error("lua async callback failed command=" .. tostring(command) .. " error=" .. tostring(err))
	end,
})

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

-- Load every user widget before announcing subscriptions to the host.
loader.load_widgets(widget_dir, widget_files, registry, log)

emit_subscriptions(true)
io.stdout:write(json.encode({
	protocol_version = PROTOCOL_VERSION,
	type = "ready",
}) .. "\n")
io.stdout:flush()

-- Emit the full initial widget trees once the runtime handshake is complete.
flush_pending_render(true)

while true do
	local line = io.read()

	if not line then
		break
	end

	log.trace("runtime stdin " .. tostring(line))

	local ok, payload = pcall(json.decode, line)

	if not ok or type(payload) ~= "table" or type(payload.name) ~= "string" or payload.name == "" then
		log.error("runtime ignored invalid json payload=" .. tostring(line))
	else
		local event = events.normalize_event(payload)
		events.dispatch_event(registry, event, flush_pending_render, log)
	end
end
