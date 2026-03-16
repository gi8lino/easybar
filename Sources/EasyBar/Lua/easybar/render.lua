local M = {}

-- Cache the last emitted JSON per widget root.
-- This avoids redundant stdout traffic for unchanged trees.
local last_emitted = {}

-- Normalizes widget position.
local function normalize_position(position)
	if position == "left" or position == "center" or position == "right" then
		return position
	end

	return "right"
end

-- Normalizes the render kind.
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

-- Normalizes internal node roles.
local function normalize_role(role)
	if role == "popup-anchor" then
		return role
	end

	return nil
end

-- Flattens a widget tree into renderable nodes.
local function flatten_node(node, root_id, parent_id, inherited_position, out)
	local id = node.id or (root_id .. "_" .. tostring(#out + 1))
	local position = normalize_position(node.position or inherited_position or "right")
	local kind = normalize_kind(node)
	local role = normalize_role(node.role)

	out[#out + 1] = {
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
	}

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

-- Emits one full widget tree as JSON on stdout.
function M.emit_tree(widget, log, json)
	local root_id = widget.id or "unknown"
	local nodes = {}

	flatten_node(widget, root_id, nil, widget.position, nodes)

	local payload = {
		type = "tree",
		root = root_id,
		nodes = nodes,
	}

	local encoded = json.encode(payload)

	-- Skip unchanged trees.
	if last_emitted[root_id] == encoded then
		if log then
			log.debug("render skipped unchanged tree root=" .. root_id)
		end
		return
	end

	last_emitted[root_id] = encoded

	io.stdout:write(encoded .. "\n")
	io.stdout:flush()

	if log then
		log.debug("render emit tree root=" .. root_id .. " nodes=" .. tostring(#nodes))
	end
end

return M
