local widget_dir = arg[1]

if not widget_dir or widget_dir == "" then
	local home = os.getenv("HOME")
	widget_dir = home .. "/.config/easybar/widgets"
end

local widgets = {}

io.stdout:setvbuf("line")
io.stderr:setvbuf("line")

-- Writes one structured log line to stderr.
-- stdout stays reserved for JSON widget updates only.
local function log(level, message)
	io.stderr:write(level .. ": " .. message .. "\n")
	io.stderr:flush()
end

-- Escapes a string for safe manual JSON encoding.
local function escape_json(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	value = value:gsub("\n", "\\n")
	value = value:gsub("\r", "\\r")
	value = value:gsub("\t", "\\t")
	return value
end

-- Normalizes widget position to one of the supported bar sections.
local function normalize_position(position)
	if position == "left" or position == "center" or position == "right" then
		return position
	end

	return "right"
end

-- Resolves the widget node kind.
-- Container-like nodes default to row when children exist.
local function normalize_kind(node)
	if
		node.kind == "row"
		or node.kind == "column"
		or node.kind == "group"
		or node.kind == "popup"
		or node.kind == "slider"
		or node.kind == "progress"
		or node.kind == "progress_slider"
		or node.kind == "sparkline"
	then
		return node.kind
	end

	if type(node.children) == "table" and #node.children > 0 then
		return "row"
	end

	return "item"
end

-- Only known internal roles are preserved.
local function normalize_role(role)
	if role == "popup-anchor" then
		return role
	end

	return nil
end

-- Flattens a widget tree into a list of renderable nodes.
local function flatten_node(node, root_id, parent_id, inherited_position, out)
	local id = node.id or (root_id .. "_" .. tostring(#out + 1))
	local position = normalize_position(node.position or inherited_position or "right")
	local kind = normalize_kind(node)
	local role = normalize_role(node.role)

	table.insert(out, {
		id = id,
		root = root_id,
		kind = kind,
		parent = parent_id,
		position = position,
		order = tonumber(node.order or 0) or 0,
		icon = node.icon or "",
		text = node.text or "",
		color = node.color or "",
		visible = node.visible ~= false,
		role = role,
		value = tonumber(node.value),
		min = tonumber(node.min),
		max = tonumber(node.max),
		step = tonumber(node.step),
		values = node.values,
		lineWidth = tonumber(node.lineWidth),
		paddingX = node.paddingX,
		paddingY = node.paddingY,
		spacing = node.spacing,
		backgroundColor = node.backgroundColor,
		borderColor = node.borderColor,
		borderWidth = node.borderWidth,
		cornerRadius = node.cornerRadius,
		opacity = node.opacity,
	})

	-- Anchor children are rendered separately from normal popup children.
	if type(node.anchorChildren) == "table" then
		for _, child in ipairs(node.anchorChildren) do
			child.role = "popup-anchor"
			flatten_node(child, root_id, id, position, out)
		end
	end

	if type(node.children) == "table" then
		for _, child in ipairs(node.children) do
			flatten_node(child, root_id, id, position, out)
		end
	end
end

-- Encodes a Lua boolean for JSON.
local function encode_bool(value)
	return value and "true" or "false"
end

-- Encodes a nullable number for JSON.
local function encode_nullable_number(value)
	if value == nil then
		return "null"
	end

	return tostring(value)
end

-- Encodes a nullable string for JSON.
local function encode_nullable_string(value)
	if value == nil or value == "" then
		return "null"
	end

	return '"' .. escape_json(value) .. '"'
end

-- Encodes a numeric array for JSON.
local function encode_number_array(values)
	if type(values) ~= "table" then
		return "null"
	end

	local out = {}
	for _, value in ipairs(values) do
		table.insert(out, tostring(tonumber(value) or 0))
	end

	return "[" .. table.concat(out, ",") .. "]"
end

-- Encodes one flattened widget node into JSON.
local function encode_single_node(node)
	return string.format(
		'{"id":"%s","root":"%s","kind":"%s","parent":%s,"position":"%s","order":%d,"icon":"%s","text":"%s","color":%s,"visible":%s,"role":%s,"value":%s,"min":%s,"max":%s,"step":%s,"values":%s,"lineWidth":%s,"paddingX":%s,"paddingY":%s,"spacing":%s,"backgroundColor":%s,"borderColor":%s,"borderWidth":%s,"cornerRadius":%s,"opacity":%s}',
		escape_json(node.id),
		escape_json(node.root),
		escape_json(node.kind),
		encode_nullable_string(node.parent),
		escape_json(node.position),
		tonumber(node.order or 0) or 0,
		escape_json(node.icon or ""),
		escape_json(node.text or ""),
		encode_nullable_string(node.color),
		encode_bool(node.visible ~= false),
		encode_nullable_string(node.role),
		encode_nullable_number(node.value),
		encode_nullable_number(node.min),
		encode_nullable_number(node.max),
		encode_nullable_number(node.step),
		encode_number_array(node.values),
		encode_nullable_number(node.lineWidth),
		encode_nullable_number(node.paddingX),
		encode_nullable_number(node.paddingY),
		encode_nullable_number(node.spacing),
		encode_nullable_string(node.backgroundColor),
		encode_nullable_string(node.borderColor),
		encode_nullable_number(node.borderWidth),
		encode_nullable_number(node.cornerRadius),
		encode_nullable_number(node.opacity)
	)
end

-- Emits one full widget tree update on stdout.
local function emit_tree(widget)
	local root_id = widget.id or "unknown"
	local nodes = {}

	flatten_node(widget, root_id, nil, widget.position, nodes)

	local encoded = {}
	for _, node in ipairs(nodes) do
		table.insert(encoded, encode_single_node(node))
	end

	local json =
		string.format('{"type":"tree","root":"%s","nodes":[%s]}', escape_json(root_id), table.concat(encoded, ","))

	io.stdout:write(json .. "\n")
	io.stdout:flush()

	log("DEBUG", "emit tree root=" .. root_id .. " nodes=" .. tostring(#nodes))
end

-- Merges a widget update table back into the widget state.
local function merge_update(widget, update)
	if type(update) ~= "table" then
		return
	end

	for k, v in pairs(update) do
		widget[k] = v
	end
end

-- Lists all Lua widget files in the configured widget directory.
local function list_widget_files()
	local files = {}
	local command = 'ls "' .. widget_dir .. '" 2>/dev/null'

	local pipe = io.popen(command)
	if not pipe then
		return files
	end

	for file in pipe:lines() do
		if file:match("%.lua$") then
			table.insert(files, file)
		end
	end

	pipe:close()
	table.sort(files)

	return files
end

-- Runs the synthetic init event for a widget, if supported.
local function run_widget_init(widget)
	if type(widget.on_event) ~= "function" then
		return
	end

	local ok, result = pcall(widget.on_event, "init", {})
	if ok and type(result) == "table" then
		merge_update(widget, result)
		return
	end

	if not ok then
		log("ERROR", "init failed for widget id=" .. widget.id .. " error=" .. tostring(result))
	end
end

-- Loads and executes one widget file.
local function load_widget_file(file)
	local path = widget_dir .. "/" .. file
	local chunk, load_err = loadfile(path)

	if not chunk then
		log("ERROR", "failed to load widget file=" .. file .. " error=" .. tostring(load_err))
		return
	end

	local ok, widget = pcall(chunk)
	if not ok then
		log("ERROR", "failed to execute widget file=" .. file .. " error=" .. tostring(widget))
		return
	end

	if type(widget) ~= "table" then
		log("ERROR", "widget file=" .. file .. " returned " .. type(widget) .. " instead of table")
		return
	end

	widget.__file = file
	widget.id = widget.id or file
	widget.position = normalize_position(widget.position)
	widget.order = tonumber(widget.order or 0) or 0

	widgets[widget.id] = widget
	log("INFO", "loaded widget file=" .. file .. " id=" .. widget.id)

	run_widget_init(widget)
	emit_tree(widget)
end

-- Loads all widgets and emits the runtime ready message.
local function load_widgets()
	widgets = {}

	log("INFO", "lua runtime started")
	log("INFO", "widget dir: " .. widget_dir)

	io.stdout:write('{"type":"ready"}\n')
	io.stdout:flush()

	for _, file in ipairs(list_widget_files()) do
		load_widget_file(file)
	end
end

-- Returns whether a widget subscribed to a given event.
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

-- Parses the JSON line sent from Swift into a minimal Lua payload table.
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

-- Dispatches one event to all subscribed widgets.
local function dispatch_event(event_name, payload)
	log("DEBUG", "dispatch event=" .. tostring(event_name))

	local targetWidget = payload and payload.widget or nil

	for _, widget in pairs(widgets) do
		local matchesTarget = (targetWidget == nil) or (widget.id == targetWidget)

		if not matchesTarget then
			goto continue
		end

		if not widget_subscribed(widget, event_name) then
			goto continue
		end

		if type(widget.on_event) ~= "function" then
			goto continue
		end

		local ok, result = pcall(widget.on_event, event_name, payload)

		if not ok then
			log(
				"ERROR",
				"widget id="
					.. tostring(widget.id)
					.. " failed on event="
					.. tostring(event_name)
					.. " error="
					.. tostring(result)
			)
			goto continue
		end

		if type(result) == "table" then
			merge_update(widget, result)
			emit_tree(widget)
		end

		::continue::
	end
end

load_widgets()

while true do
	local line = io.read()

	if not line then
		break
	end

	log("DEBUG", "stdin " .. tostring(line))

	local payload = parse_event(line)

	if payload and payload.event then
		dispatch_event(payload.event, payload)
	else
		log("ERROR", "ignored invalid event payload: " .. tostring(line))
	end
end
