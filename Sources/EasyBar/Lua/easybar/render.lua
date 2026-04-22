--- Module contract:
--- Owns registry-to-render-tree conversion and change-aware tree emission.
--- Returns helpers that emit flattened widget trees for the Swift host.
local M = {}

local last_emitted = {}
local DEFAULT_ROOT_SHELL_STYLE = {
	background = {
		color = "#1a1a1a",
		border_color = "#333333",
		border_width = 1,
		corner_radius = 8,
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
}
local DEFAULT_POPUP_TEXT_COLOR = "#cdd6f4"
local DEFAULT_POPUP_STYLE = {
	background = {
		color = "#111111",
		border_color = "#444444",
		border_width = 1,
		corner_radius = 8,
	},
	padding_x = 8,
	padding_y = 6,
	margin_x = 0,
	margin_y = 8,
	spacing = 4,
}

--- Deep-copies one Lua value tree.
local function deep_copy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}

	for key, item in pairs(value) do
		copy[key] = deep_copy(item)
	end

	return copy
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
			target[key] = deep_copy(value)
		end
	end

	return target
end

--- Normalizes one root position into the supported bar positions.
local function normalize_position(position)
	if position == "left" or position == "center" or position == "right" then
		return position
	end

	return "right"
end

--- Extracts the rendered label text from one item prop table.
local function label_string(label)
	if type(label) == "table" then
		return label.string or ""
	end

	if type(label) == "string" then
		return label
	end

	return ""
end

--- Extracts the rendered icon text from one item prop table.
local function icon_string(icon)
	if type(icon) == "table" then
		return icon.string or ""
	end

	if type(icon) == "string" then
		return icon
	end

	return ""
end

--- Resolves the primary foreground color for one node.
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

--- Resolves the label color override for one node.
local function resolve_label_color(props)
	if type(props.label) == "table" then
		return props.label.color
	end

	return nil
end

--- Resolves the icon color override for one node.
local function resolve_icon_color(props)
	if type(props.icon) == "table" then
		return props.icon.color
	end

	return nil
end

--- Resolves the configured label font size.
local function resolve_label_font_size(props)
	if type(props.label) == "table" and type(props.label.font) == "table" then
		return tonumber(props.label.font.size)
	end

	return nil
end

--- Resolves the configured icon font size.
local function resolve_icon_font_size(props)
	if type(props.icon) == "table" and type(props.icon.font) == "table" then
		return tonumber(props.icon.font.size)
	end

	return nil
end

--- Resolves the configured image path for one node.
local function resolve_image_path(props)
	if type(props.icon) == "table" and type(props.icon.image) == "string" then
		return props.icon.image
	end

	if type(props.image) == "table" and type(props.image.path) == "string" then
		return props.image.path
	end

	return nil
end

--- Resolves the configured image size for one node.
local function resolve_image_size(props)
	if type(props.icon) == "table" and props.icon.image_size ~= nil then
		return tonumber(props.icon.image_size)
	end

	if type(props.image) == "table" and props.image.size ~= nil then
		return tonumber(props.image.size)
	end

	return nil
end

--- Resolves the configured image corner radius for one node.
local function resolve_image_corner_radius(props)
	if type(props.icon) == "table" and props.icon.image_corner_radius ~= nil then
		return tonumber(props.icon.image_corner_radius)
	end

	if type(props.image) == "table" and type(props.image.corner_radius) ~= "nil" then
		return tonumber(props.image.corner_radius)
	end

	return nil
end

--- Resolves child spacing for rows, groups, and popup content.
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

--- Resolves one numeric box-model value from direct props or nested tables.
local function resolve_box_value(props, key, box)
	if props[key] ~= nil then
		return tonumber(props[key])
	end

	if type(props[box]) == "table" and props[box][key] ~= nil then
		return tonumber(props[box][key])
	end

	return nil
end

--- Resolves whether one node should be visible.
local function resolve_drawing(props, default)
	if props.drawing == nil then
		return default
	end

	return props.drawing ~= false
end

--- Returns the popup anchor parent id for popup-positioned items.
local function popup_parent_id(item)
	local position = item.props.position

	if type(position) == "string" then
		return position:match("^popup%.(.+)$")
	end

	return nil
end

--- Returns the regular parent id for nested child items.
local function regular_parent_id(item)
	if type(item.props.parent) == "string" and item.props.parent ~= "" then
		return item.props.parent
	end

	return nil
end

--- Returns whether one item is rendered inside popup content.
local function is_popup_item(item)
	return popup_parent_id(item) ~= nil
end

--- Returns whether one item is one bar-root widget node.
local function is_bar_root_item(item)
	return regular_parent_id(item) == nil and popup_parent_id(item) == nil
end

--- Returns whether one item should receive the default root shell styling.
local function uses_default_root_shell(item)
	return is_bar_root_item(item) and item.kind ~= "popup"
end

--- Builds one minimal render node with shared defaults applied.
local function base_node(id, kind, root_position, order, visible)
	return {
		id = id,
		kind = kind,
		position = normalize_position(root_position),
		order = tonumber(order or 0) or 0,
		visible = visible ~= false,
		receivesMouseHover = false,
		receivesMouseDown = false,
		receivesMouseUp = false,
		receivesMouseClick = false,
		receivesMouseScroll = false,
	}
end

--- Applies shared box-model and frame styling props to one node.
local function apply_box_style(node, props)
	node.paddingX = tonumber(props.padding_x or props.paddingX)
	node.paddingY = tonumber(props.padding_y or props.paddingY)
	node.paddingLeft = resolve_box_value(props, "padding_left", "background")
	node.paddingRight = resolve_box_value(props, "padding_right", "background")
	node.paddingTop = resolve_box_value(props, "padding_top", "background")
	node.paddingBottom = resolve_box_value(props, "padding_bottom", "background")
	node.marginX = tonumber(props.margin_x or props.marginX)
	node.marginY = tonumber(props.margin_y or props.marginY)
	node.marginLeft = resolve_box_value(props, "margin_left", "margin")
	node.marginRight = resolve_box_value(props, "margin_right", "margin")
	node.marginTop = resolve_box_value(props, "margin_top", "margin")
	node.marginBottom = resolve_box_value(props, "margin_bottom", "margin")
	node.spacing = resolve_spacing(props)
	node.backgroundColor = type(props.background) == "table" and props.background.color or props.backgroundColor
	node.borderColor = type(props.background) == "table" and props.background.border_color or props.borderColor
	node.borderWidth = type(props.background) == "table" and tonumber(props.background.border_width)
		or tonumber(props.borderWidth)
	node.cornerRadius = type(props.background) == "table" and tonumber(props.background.corner_radius)
		or tonumber(props.cornerRadius)
	node.opacity = tonumber(props.opacity)
	node.width = tonumber(props.width)
	node.height = tonumber(props.height)
	node.yOffset = tonumber(props.y_offset)
	return node
end

--- Applies resolved mouse interaction flags to one node.
local function apply_interaction(node, interaction)
	node.receivesMouseHover = interaction.hover
	node.receivesMouseDown = interaction.down
	node.receivesMouseUp = interaction.up
	node.receivesMouseClick = interaction.click
	node.receivesMouseScroll = interaction.scroll
	return node
end

--- Resolves which mouse capabilities the node should expose.
local function resolve_mouse_interaction(registry, id)
	local subscriptions = registry._state.subscriptions[id]
	if type(subscriptions) ~= "table" then
		return {
			hover = false,
			down = false,
			up = false,
			click = false,
			scroll = false,
		}
	end

	local hover = false
	local down = false
	local up = false
	local click = false
	local scroll = false

	for event_name in pairs(subscriptions) do
		if type(event_name) == "string" then
			if event_name == "mouse.entered" or event_name == "mouse.exited" then
				hover = true
			elseif event_name == "mouse.down" then
				down = true
			elseif event_name == "mouse.up" then
				up = true
			elseif event_name == "mouse.clicked" then
				click = true
			elseif event_name == "mouse.scrolled" then
				scroll = true
			end
		end
	end

	return {
		hover = hover,
		down = down,
		up = up,
		click = click,
		scroll = scroll,
	}
end

--- Builds one render node from an item record and its child nodes.
local function make_node(registry, id, item, root_position, children)
	local props = item.props
	local resolved_props = props
	local kind = item.kind or "item"

	if kind == "item" and type(children) == "table" and #children > 0 then
		kind = "row"
	end

	if uses_default_root_shell(item) then
		resolved_props = {}
		deep_merge(resolved_props, DEFAULT_ROOT_SHELL_STYLE)
		deep_merge(resolved_props, props)
	end

	local node = base_node(id, kind, root_position, resolved_props.order, resolve_drawing(resolved_props, true))
	node.icon = icon_string(resolved_props.icon)
	node.text = label_string(resolved_props.label)
	node.color = resolve_color(resolved_props)
	node.iconColor = resolve_icon_color(resolved_props)
	node.labelColor = resolve_label_color(resolved_props)
	node.imagePath = resolve_image_path(resolved_props)
	node.imageSize = resolve_image_size(resolved_props)
	node.imageCornerRadius = resolve_image_corner_radius(resolved_props)
	node.iconFontSize = resolve_icon_font_size(resolved_props)
	node.labelFontSize = resolve_label_font_size(resolved_props)
	node.value = tonumber(resolved_props.value)
	node.min = tonumber(resolved_props.min)
	node.max = tonumber(resolved_props.max)
	node.step = tonumber(resolved_props.step)
	node.values = resolved_props.values
	node.lineWidth = tonumber(resolved_props.line_width or resolved_props.lineWidth)
	node.children = children

	if is_popup_item(item) and node.color == "" then
		node.color = DEFAULT_POPUP_TEXT_COLOR
	end

	return apply_interaction(apply_box_style(node, resolved_props), resolve_mouse_interaction(registry, id))
end

--- Builds the popup content container for one popup-enabled item.
local function make_popup_container(id, root_position, popup_props, children)
	local resolved_popup_props = {}
	deep_merge(resolved_popup_props, DEFAULT_POPUP_STYLE)
	deep_merge(resolved_popup_props, popup_props or {})

	local node = base_node(id, "column", root_position, 0, resolve_drawing(resolved_popup_props, false))
	node.icon = ""
	node.text = ""
	node.color = ""
	node.children = children
	return apply_box_style(node, resolved_popup_props)
end

--- Flattens one render tree into the payload expected by Swift.
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
		receivesMouseHover = node.receivesMouseHover == true,
		receivesMouseDown = node.receivesMouseDown == true,
		receivesMouseUp = node.receivesMouseUp == true,
		receivesMouseClick = node.receivesMouseClick == true,
		receivesMouseScroll = node.receivesMouseScroll == true,
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
		marginX = node.marginX,
		marginY = node.marginY,
		marginLeft = node.marginLeft,
		marginRight = node.marginRight,
		marginTop = node.marginTop,
		marginBottom = node.marginBottom,
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

	if type(node.popupChildren) == "table" then
		for _, child in ipairs(node.popupChildren) do
			child.role = "popup-content"
			flatten_node(child, root_id, id, position, out)
		end
	end

	if type(node.children) == "table" then
		for _, child in ipairs(node.children) do
			flatten_node(child, root_id, id, position, out)
		end
	end
end

--- Returns item ids in their declared widget order.
local function ordered_ids(registry)
	return registry._state.item_order
end

--- Returns one registry item by id.
local function item_by_id(registry, id)
	return registry._state.items[id]
end

--- Returns direct non-popup child ids for one parent node.
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

--- Returns direct popup child ids for one popup anchor node.
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

--- Returns one internal id that cannot collide with user-declared ids.
local function internal_popup_id(id, suffix)
	return id .. "__easybar_" .. suffix
end

--- Builds the render tree for one root widget id.
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
		return make_node(registry, id, item, root_position, child_nodes)
	end

	local popup_props = item.props.popup or {}
	local popup_container =
		make_popup_container(internal_popup_id(id, "popup_content"), root_position, popup_props, popup_child_nodes)

	-- Real popup roots need dedicated anchor children because Swift renders `.popup`
	-- nodes through `popupAnchor`. Normal item/row/group widgets should keep their
	-- regular children directly on the root and only attach popup content separately.
	if item.kind == "popup" then
		local anchor = make_node(registry, internal_popup_id(id, "popup_anchor"), item, root_position, child_nodes)
		anchor.order = 0

		local root = make_node(registry, id, item, root_position, nil)
		root.anchorChildren = { anchor }
		root.popupChildren = { popup_container }
		return root
	end

	local root = make_node(registry, id, item, root_position, child_nodes)
	root.popupChildren = { popup_container }
	return root
end

--- Returns root widget ids in render order.
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

--- Emits one root tree when it differs from the previous payload.
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
			log.trace("render skipped unchanged tree root=" .. root_id)
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

--- Emits all root widget trees for the current registry state.
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
