local M = {}

local last_emitted = {}

local function normalize_position(position)
	if position == "left" or position == "center" or position == "right" then
		return position
	end

	return "right"
end

local function label_string(label)
	if type(label) == "table" then
		return label.string or ""
	end

	if type(label) == "string" then
		return label
	end

	return ""
end

local function icon_string(icon)
	if type(icon) == "table" then
		return icon.string or ""
	end

	if type(icon) == "string" then
		return icon
	end

	return ""
end

local function resolve_color(props)
	if props.color ~= nil then
		return props.color
	end

	if type(props.label) == "table" and props.label.color ~= nil then
		return props.label.color
	end

	if type(props.icon) == "table" and props.icon.color ~= nil then
		return props.icon.color
	end

	return ""
end

local function resolve_label_color(props)
	if type(props.label) == "table" then
		return props.label.color
	end

	return nil
end

local function resolve_icon_color(props)
	if type(props.icon) == "table" then
		return props.icon.color
	end

	return nil
end

local function resolve_label_font_size(props)
	if type(props.label) == "table" and type(props.label.font) == "table" then
		return tonumber(props.label.font.size)
	end

	return nil
end

local function resolve_icon_font_size(props)
	if type(props.icon) == "table" and type(props.icon.font) == "table" then
		return tonumber(props.icon.font.size)
	end

	return nil
end

local function resolve_image_path(props)
	if type(props.icon) == "table" and type(props.icon.image) == "string" then
		return props.icon.image
	end

	if type(props.image) == "table" and type(props.image.path) == "string" then
		return props.image.path
	end

	return nil
end

local function resolve_image_size(props)
	if type(props.icon) == "table" and props.icon.image_size ~= nil then
		return tonumber(props.icon.image_size)
	end

	if type(props.image) == "table" and props.image.size ~= nil then
		return tonumber(props.image.size)
	end

	return nil
end

local function resolve_image_corner_radius(props)
	if type(props.icon) == "table" and props.icon.image_corner_radius ~= nil then
		return tonumber(props.icon.image_corner_radius)
	end

	if type(props.image) == "table" and props.image.corner_radius ~= nil then
		return tonumber(props.image.corner_radius)
	end

	return nil
end

local function resolve_spacing(props)
	if props.spacing ~= nil then
		return tonumber(props.spacing)
	end

	if type(props.icon) == "table" then
		if props.icon.padding_right ~= nil then
			return tonumber(props.icon.padding_right)
		end
	end

	return nil
end

local function resolve_drawing(props, default)
	if props.drawing == nil then
		return default
	end

	return props.drawing ~= false
end

local function popup_parent_id(item)
	local position = item.props.position

	if type(position) == "string" then
		return position:match("^popup%.(.+)$")
	end

	return nil
end

local function regular_parent_id(item)
	if type(item.props.parent) == "string" and item.props.parent ~= "" then
		return item.props.parent
	end

	return nil
end

local function make_node(id, item, root_position, children)
	local props = item.props

	local kind = item.kind or "item"

	if kind == "item" and type(children) == "table" and #children > 0 then
		kind = "row"
	end

	return {
		id = id,
		kind = kind,
		position = normalize_position(root_position),
		order = tonumber(props.order or 0) or 0,
		icon = icon_string(props.icon),
		text = label_string(props.label),
		color = resolve_color(props),
		iconColor = resolve_icon_color(props),
		labelColor = resolve_label_color(props),
		imagePath = resolve_image_path(props),
		imageSize = resolve_image_size(props),
		imageCornerRadius = resolve_image_corner_radius(props),
		iconFontSize = resolve_icon_font_size(props),
		labelFontSize = resolve_label_font_size(props),
		visible = resolve_drawing(props, true),
		value = tonumber(props.value),
		min = tonumber(props.min),
		max = tonumber(props.max),
		step = tonumber(props.step),
		values = props.values,
		lineWidth = tonumber(props.line_width or props.lineWidth),
		paddingX = tonumber(props.padding_x or props.paddingX),
		paddingY = tonumber(props.padding_y or props.paddingY),
		paddingLeft = tonumber(props.padding_left),
		paddingRight = tonumber(props.padding_right),
		paddingTop = tonumber(props.padding_top),
		paddingBottom = tonumber(props.padding_bottom),
		spacing = resolve_spacing(props),
		backgroundColor = type(props.background) == "table" and props.background.color or props.backgroundColor,
		borderColor = type(props.background) == "table" and props.background.border_color or props.borderColor,
		borderWidth = type(props.background) == "table" and tonumber(props.background.border_width)
			or tonumber(props.borderWidth),
		cornerRadius = type(props.background) == "table" and tonumber(props.background.corner_radius)
			or tonumber(props.cornerRadius),
		opacity = tonumber(props.opacity),
		width = tonumber(props.width),
		height = tonumber(props.height),
		yOffset = tonumber(props.y_offset),
		children = children,
	}
end

local function flatten_node(node, root_id, parent_id, inherited_position, out)
	local id = node.id or (root_id .. "_" .. tostring(#out + 1))
	local position = normalize_position(node.position or inherited_position or "right")

	out[#out + 1] = {
		id = id,
		root = root_id,
		kind = node.kind or "item",
		parent = parent_id,
		position = position,
		order = tonumber(node.order or 0) or 0,
		icon = node.icon or "",
		text = node.text or "",
		color = node.color or "",
		iconColor = node.iconColor,
		labelColor = node.labelColor,
		imagePath = node.imagePath,
		imageSize = tonumber(node.imageSize),
		imageCornerRadius = tonumber(node.imageCornerRadius),
		iconFontSize = tonumber(node.iconFontSize),
		labelFontSize = tonumber(node.labelFontSize),
		visible = node.visible ~= false,
		role = node.role,
		value = tonumber(node.value),
		min = tonumber(node.min),
		max = tonumber(node.max),
		step = tonumber(node.step),
		values = node.values,
		lineWidth = tonumber(node.lineWidth),
		paddingX = node.paddingX,
		paddingY = node.paddingY,
		paddingLeft = node.paddingLeft,
		paddingRight = node.paddingRight,
		paddingTop = node.paddingTop,
		paddingBottom = node.paddingBottom,
		spacing = node.spacing,
		backgroundColor = node.backgroundColor,
		borderColor = node.borderColor,
		borderWidth = node.borderWidth,
		cornerRadius = node.cornerRadius,
		opacity = node.opacity,
		width = node.width,
		height = node.height,
		yOffset = node.yOffset,
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

local function ordered_ids(registry)
	return registry._state.item_order
end

local function item_by_id(registry, id)
	return registry._state.items[id]
end

local function regular_children_of(registry, parent_id)
	local children = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)

		if item ~= nil and regular_parent_id(item) == parent_id then
			children[#children + 1] = id
		end
	end

	return children
end

local function popup_children_of(registry, anchor_id)
	local children = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)

		if item ~= nil and popup_parent_id(item) == anchor_id then
			children[#children + 1] = id
		end
	end

	return children
end

local function build_tree(registry, id, root_position)
	local item = item_by_id(registry, id)
	if item == nil then
		return nil
	end

	local child_nodes = {}
	for _, child_id in ipairs(regular_children_of(registry, id)) do
		local child = build_tree(registry, child_id, root_position)
		if child then
			child_nodes[#child_nodes + 1] = child
		end
	end

	local popup_child_nodes = {}
	for _, child_id in ipairs(popup_children_of(registry, id)) do
		local child = build_tree(registry, child_id, root_position)
		if child then
			popup_child_nodes[#popup_child_nodes + 1] = child
		end
	end

	local has_popup = type(item.props.popup) == "table" or #popup_child_nodes > 0

	if not has_popup then
		return make_node(id, item, root_position, child_nodes)
	end

	local anchor = make_node(id .. "_anchor", item, root_position, child_nodes)
	anchor.order = 0

	local popup_props = item.props.popup or {}
	local popup_drawing = resolve_drawing(popup_props, false)

	local popup_container = {
		id = id .. "_popup_content",
		kind = "column",
		position = normalize_position(root_position),
		order = 0,
		icon = "",
		text = "",
		color = "",
		visible = popup_drawing,
		paddingLeft = tonumber(popup_props.padding_left),
		paddingRight = tonumber(popup_props.padding_right),
		paddingTop = tonumber(popup_props.padding_top),
		paddingBottom = tonumber(popup_props.padding_bottom),
		backgroundColor = type(popup_props.background) == "table" and popup_props.background.color or nil,
		borderColor = type(popup_props.background) == "table" and popup_props.background.border_color or nil,
		borderWidth = type(popup_props.background) == "table" and tonumber(popup_props.background.border_width)
			or nil,
		cornerRadius = type(popup_props.background) == "table" and tonumber(popup_props.background.corner_radius)
			or nil,
		width = tonumber(popup_props.width),
		height = tonumber(popup_props.height),
		yOffset = tonumber(popup_props.y_offset),
		spacing = tonumber(popup_props.spacing),
		children = popup_child_nodes,
	}

	return {
		id = id,
		kind = "popup",
		position = normalize_position(root_position),
		order = tonumber(item.props.order or 0) or 0,
		icon = icon_string(item.props.icon),
		text = label_string(item.props.label),
		color = resolve_color(item.props),
		iconColor = resolve_icon_color(item.props),
		labelColor = resolve_label_color(item.props),
		imagePath = resolve_image_path(item.props),
		imageSize = resolve_image_size(item.props),
		imageCornerRadius = resolve_image_corner_radius(item.props),
		iconFontSize = resolve_icon_font_size(item.props),
		labelFontSize = resolve_label_font_size(item.props),
		visible = resolve_drawing(item.props, true),
		paddingX = tonumber(item.props.padding_x or item.props.paddingX),
		paddingY = tonumber(item.props.padding_y or item.props.paddingY),
		paddingLeft = tonumber(item.props.padding_left),
		paddingRight = tonumber(item.props.padding_right),
		paddingTop = tonumber(item.props.padding_top),
		paddingBottom = tonumber(item.props.padding_bottom),
		spacing = resolve_spacing(item.props),
		backgroundColor = type(item.props.background) == "table" and item.props.background.color
			or item.props.backgroundColor,
		borderColor = type(item.props.background) == "table" and item.props.background.border_color
			or item.props.borderColor,
		borderWidth = type(item.props.background) == "table" and tonumber(item.props.background.border_width)
			or tonumber(item.props.borderWidth),
		cornerRadius = type(item.props.background) == "table" and tonumber(item.props.background.corner_radius)
			or tonumber(item.props.cornerRadius),
		opacity = tonumber(item.props.opacity),
		width = tonumber(item.props.width),
		height = tonumber(item.props.height),
		yOffset = tonumber(item.props.y_offset),
		anchorChildren = #child_nodes > 0 and { anchor } or {},
		children = { popup_container },
	}
end

local function root_ids(registry)
	local roots = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)

		if item ~= nil and regular_parent_id(item) == nil and popup_parent_id(item) == nil then
			roots[#roots + 1] = id
		end
	end

	return roots
end

local function emit_tree(tree, log, json)
	local root_id = tree.id or "unknown"
	local nodes = {}

	flatten_node(tree, root_id, nil, tree.position, nodes)

	local payload = {
		type = "tree",
		root = root_id,
		nodes = nodes,
	}

	local encoded = json.encode(payload)

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

function M.emit_all(registry, log, json)
	for _, id in ipairs(root_ids(registry)) do
		local item = item_by_id(registry, id)

		if item ~= nil then
			local root_position = normalize_position(item.props.position)
			local tree = build_tree(registry, id, root_position)

			if tree ~= nil then
				emit_tree(tree, log, json)
			end
		end
	end
end

return M
