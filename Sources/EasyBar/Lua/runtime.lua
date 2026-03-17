local function runtime_dir()
	local source = debug.getinfo(1, "S").source
	if source:sub(1, 1) == "@" then
		source = source:sub(2)
	end
	return source:match("^(.*)/[^/]+$") or "."
end

local base_dir = runtime_dir()

local function load_module(name)
	local path = base_dir .. "/easybar/" .. name .. ".lua"
	local chunk, err = loadfile(path)

	if not chunk then
		error("failed to load module '" .. name .. "' from " .. path .. ": " .. tostring(err))
	end

	return chunk()
end

local log = load_module("log")
local json = load_module("json")
local api = load_module("api")
local loader = load_module("loader")
local events = load_module("events")
local render = load_module("render")

local widget_dir = arg[1]

if not widget_dir or widget_dir == "" then
	local home = os.getenv("HOME")
	widget_dir = home .. "/.config/easybar/widgets"
end

local registry = api.new(log)

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

loader.load_widgets(widget_dir, registry, log)

io.stdout:write(json.encode({
	type = "subscriptions",
	events = registry.required_events(),
}) .. "\n")
io.stdout:write('{"type":"ready"}' .. "\n")
io.stdout:flush()

render.emit_all(registry, log, json)

while true do
	local line = io.read()

	if not line then
		break
	end

	log.debug("runtime stdin " .. tostring(line))

	local ok, payload = pcall(json.decode, line)

	if not ok or type(payload) ~= "table" or not payload.event then
		log.error("runtime ignored invalid json payload=" .. tostring(line))
	else
		events.dispatch_event(registry, payload.event, payload, render, log, json)
	end
end
