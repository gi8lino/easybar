--- Module contract:
--- Owns registry-to-render-tree conversion and deterministic root ordering.
--- Returns helpers consumed by `render.lua`.
local M = {}

local style = require("easybar.render.style")

local function item_by_id(registry, id)
	return registry._state.items[id]
end

local function ordered_ids(registry)
	return registry._state.item_order or {}
end

local function regular_children_of(registry, parent_id)
	local children = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)
		if item ~= nil and style.regular_parent_id(item) == parent_id then
			children[#children + 1] = id
		end
	end

	return children
end

local function popup_children_of(registry, parent_id)
	local children = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)
		if item ~= nil and style.popup_parent_id(item) == parent_id then
			children[#children + 1] = id
		end
	end

	return children
end

local function internal_popup_id(id, suffix)
	return id .. "__" .. suffix
end

function M.build_tree(registry, id, root_position)
	local item = item_by_id(registry, id)
	if item == nil then
		return nil
	end

	local child_nodes = {}
	for _, child_id in ipairs(regular_children_of(registry, id)) do
		local child = M.build_tree(registry, child_id, root_position)
		if child then
			child_nodes[#child_nodes + 1] = child
		end
	end

	local popup_child_nodes = {}
	for _, child_id in ipairs(popup_children_of(registry, id)) do
		local child = M.build_tree(registry, child_id, root_position)
		if child then
			popup_child_nodes[#popup_child_nodes + 1] = child
		end
	end

	local has_popup = type(item.props.popup) == "table" or #popup_child_nodes > 0

	if not has_popup then
		return style.make_node(registry, id, item, root_position, child_nodes)
	end

	local popup_props = item.props.popup or {}
	local popup_container =
		style.make_popup_container(internal_popup_id(id, "popup_content"), root_position, popup_props, popup_child_nodes)

	if item.kind == "popup" then
		local anchor = style.make_node(registry, internal_popup_id(id, "popup_anchor"), item, root_position, child_nodes)
		anchor.order = 0

		local root = style.make_node(registry, id, item, root_position, nil)
		root.anchorChildren = { anchor }
		root.popupChildren = { popup_container }
		return root
	end

	local root = style.make_node(registry, id, item, root_position, child_nodes)
	root.popupChildren = { popup_container }
	return root
end

function M.root_ids(registry)
	local roots = {}

	for _, id in ipairs(ordered_ids(registry)) do
		local item = item_by_id(registry, id)

		if item ~= nil and style.regular_parent_id(item) == nil and style.popup_parent_id(item) == nil then
			roots[#roots + 1] = id
		end
	end

	return roots
end

return M
