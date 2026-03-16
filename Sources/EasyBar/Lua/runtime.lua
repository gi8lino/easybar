local function runtime_dir()
	local source = debug.getinfo(1, "S").source
	if source:sub(1, 1) == "@" then
		source = source:sub(2)
	end
	return source:match("^(.*)/[^/]+$") or "."
end

local base_dir = runtime_dir()

-- Loads one bundled helper module from the copied easybar directory.
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
local loader = load_module("loader")
local events = load_module("events")
local render = load_module("render")

local widget_dir = arg[1]

if not widget_dir or widget_dir == "" then
	local home = os.getenv("HOME")
	widget_dir = home .. "/.config/easybar/widgets"
end

local widgets = {}

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

-- Load all widget files and emit the initial ready message.
loader.load_widgets(widget_dir, widgets, render, log, json)

while true do
	local line = io.read()

	if not line then
		break
	end

	log.debug("runtime stdin " .. tostring(line))

	-- Swift sends JSON lines to Lua stdin.
	local ok, payload = pcall(json.decode, line)

	if not ok or type(payload) ~= "table" or not payload.event then
		log.error("runtime ignored invalid json payload=" .. tostring(line))
	else
		events.dispatch_event(widgets, payload.event, payload, render, log, json)
	end
end
