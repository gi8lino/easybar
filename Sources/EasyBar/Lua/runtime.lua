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

local function normalize_kind(node)
	if node.kind == "row" or node.kind == "column" or node.kind == "group" or node.kind == "popup" then
		return node.kind
	end

	if type(node.children) == "table" and #node.children > 0 then
		return "row"
	end

	return "item"
end

local function flatten_node(node, root_id, parent_id, inherited_position, out)
	local id = node.id or (root_id .. "_" .. tostring(#out + 1))
	local position = normalize_position(node.position or inherited_position or "right")
	local kind = normalize_kind(node)

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
		paddingX = node.paddingX,
		paddingY = node.paddingY,
		spacing = node.spacing,
		backgroundColor = node.backgroundColor,
		borderColor = node.borderColor,
		borderWidth = node.borderWidth,
		cornerRadius = node.cornerRadius,
		opacity = node.opacity,
	})

	if type(node.children) == "table" then
		for _, child in ipairs(node.children) do
			flatten_node(child, root_id, id, position, out)
		end
	end
end

local function encode_bool(value)
	return value and "true" or "false"
end

local function encode_nullable_number(value)
	if value == nil then
		return "null"
	end
	return tostring(value)
end

local function encode_nullable_string(value)
	if value == nil or value == "" then
		return "null"
	end
	return '"' .. escape_json(value) .. '"'
end

local function encode_node(node)
	return string.format(
		'{"id":"%s","root":"%s","kind":"%s","parent":%s,"position":"%s","order":%d,"icon":"%s","text":"%s","color":%s,"visible":%s,"paddingX":%s,"paddingY":%s,"spacing":%s,"backgroundColor":%s,"borderColor":%s,"borderWidth":%s,"cornerRadius":%s,"opacity":%s}',
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

local function emit_tree(widget)
	local root_id = widget.id or "unknown"
	local nodes = {}

	flatten_node(widget, root_id, nil, widget.position, nodes)

	local encoded = {}
	for _, node in ipairs(nodes) do
		table.insert(encoded, encode_node(node))
	end

	local json =
		string.format('{"type":"tree","root":"%s","nodes":[%s]}', escape_json(root_id), table.concat(encoded, ","))

	io.stdout:write(json .. "\n")
	io.stdout:flush()

	log("emit tree root=" .. root_id .. " nodes=" .. tostring(#nodes))
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

					emit_tree(widget)
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
				emit_tree(widget)
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
