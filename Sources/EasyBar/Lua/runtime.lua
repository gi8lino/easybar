local home = os.getenv("HOME")
local widget_dir = home .. "/.config/easybar/widgets"

local widgets = {}

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

local function log(message)
	io.stderr:write(message .. "\n")
	io.stderr:flush()
end

local function escape_json(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	value = value:gsub("\n", "\\n")
	value = value:gsub("\r", "\\r")
	value = value:gsub("\t", "\\t")
	return value
end

local function normalize_position(position)
	if position == "left" or position == "center" or position == "right" then
		return position
	end
	return "right"
end

local function emit_widget(widget)
	local id = widget.id or "unknown"
	local icon = widget.icon or ""
	local text = widget.text or ""
	local position = normalize_position(widget.position)
	local order = tonumber(widget.order or 0) or 0
	local color = widget.color or ""

	local json = string.format(
		'{"id":"%s","icon":"%s","text":"%s","position":"%s","order":%d,"color":"%s"}',
		escape_json(id),
		escape_json(icon),
		escape_json(text),
		escape_json(position),
		order,
		escape_json(color)
	)

	io.stdout:write(json .. "\n")
	io.stdout:flush()

	log("emit " .. json)
end

local function merge_update(widget, update)
	if type(update) ~= "table" then
		return
	end

	for k, v in pairs(update) do
		widget[k] = v
	end
end

local function load_widgets()
	widgets = {}

	log("lua runtime started")
	log("widget dir: " .. widget_dir)

	io.stdout:write('{"type":"ready"}\n')
	io.stdout:flush()

	for file in io.popen('ls "' .. widget_dir .. '" 2>/dev/null'):lines() do
		if file:match("%.lua$") then
			local path = widget_dir .. "/" .. file
			local chunk, load_err = loadfile(path)

			if not chunk then
				log("failed to load widget file=" .. file .. " error=" .. tostring(load_err))
			else
				local ok, widget = pcall(chunk)

				if not ok then
					log("failed to execute widget file=" .. file .. " error=" .. tostring(widget))
				elseif type(widget) ~= "table" then
					log("widget file=" .. file .. " returned " .. type(widget) .. " instead of table")
				else
					widget.__file = file
					widget.id = widget.id or file
					widget.position = normalize_position(widget.position)
					widget.order = tonumber(widget.order or 0) or 0

					widgets[widget.id] = widget
					log("loaded widget file=" .. file .. " id=" .. widget.id)

					if type(widget.on_event) == "function" then
						local init_ok, init_result = pcall(widget.on_event, "init", {})
						if init_ok and type(init_result) == "table" then
							merge_update(widget, init_result)
						elseif not init_ok then
							log("init failed for widget id=" .. widget.id .. " error=" .. tostring(init_result))
						end
					end

					emit_widget(widget)
				end
			end
		end
	end
end

local function widget_subscribed(widget, event_name)
	if type(widget.subscribe) ~= "table" then
		return false
	end

	for _, value in ipairs(widget.subscribe) do
		if value == event_name then
			return true
		end
	end

	return false
end

local function parse_event(line)
	local event = line:match('"event"%s*:%s*"([^"]+)"')
	if not event then
		return nil
	end

	local payload = { event = event }

	for key, value in line:gmatch('"([%w_]+)"%s*:%s*"([^"]*)"') do
		payload[key] = value
	end

	return payload
end

local function dispatch_event(event_name, payload)
	log("dispatch event=" .. tostring(event_name))

	local targetWidget = payload and payload.widget or nil

	for _, widget in pairs(widgets) do
		local matchesTarget = (targetWidget == nil) or (widget.id == targetWidget)

		if matchesTarget and widget_subscribed(widget, event_name) and type(widget.on_event) == "function" then
			local ok, result = pcall(widget.on_event, event_name, payload)

			if not ok then
				log(
					"widget id="
						.. tostring(widget.id)
						.. " failed on event="
						.. tostring(event_name)
						.. " error="
						.. tostring(result)
				)
			elseif type(result) == "table" then
				merge_update(widget, result)
				emit_widget(widget)
			end
		end
	end
end

load_widgets()

while true do
	local line = io.read()

	if line then
		log("stdin " .. tostring(line))

		local payload = parse_event(line)

		if payload and payload.event then
			dispatch_event(payload.event, payload)
		else
			log("ignored invalid event payload: " .. tostring(line))
		end
	end
end
