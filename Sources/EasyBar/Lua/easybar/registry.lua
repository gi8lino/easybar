--- Module contract:
--- Owns widget item state, property normalization, and item tree mutation.
--- Returns one registry object with item CRUD helpers and raw `_state`.
local M = {}

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

--- Normalizes one flexible boolean option into a real Lua boolean.
local function normalize_bool(value, default)
	if value == nil then
		return default
	end

	if value == true or value == "on" then
		return true
	end

	if value == false or value == "off" then
		return false
	end

	return default
end

--- Normalizes shorthand label values into a label table.
local function normalize_label(value)
	if value == nil then
		return nil
	end

	if type(value) == "table" then
		return value
	end

	return {
		string = tostring(value),
	}
end

--- Normalizes shorthand icon values into an icon table.
local function normalize_icon(value)
	if value == nil then
		return nil
	end

	if type(value) == "table" then
		return value
	end

	return {
		string = tostring(value),
	}
end

--- Normalizes item props into the shape expected by the renderer.
local function normalize_props(props)
	local normalized = deep_copy(props or {})

	if normalized.label ~= nil then
		normalized.label = normalize_label(normalized.label)
	end

	if normalized.icon ~= nil then
		normalized.icon = normalize_icon(normalized.icon)
	end

	if normalized.drawing ~= nil then
		normalized.drawing = normalize_bool(normalized.drawing, true)
	end

	if type(normalized.popup) == "table" and normalized.popup.drawing ~= nil then
		normalized.popup.drawing = normalize_bool(normalized.popup.drawing, false)
	end

	return normalized
end

--- Trims command output for `easybar.exec(...)`.
local function trim_trailing_newlines(value)
	if not value then
		return ""
	end

	value = value:gsub("\r", "")
	value = value:gsub("\n+$", "")
	return value
end

--- Returns child ids for one parent, including popup-positioned children.
local function child_ids_of(state, id)
	local result = {}

	for child_id, item in pairs(state.items) do
		local parent = item.props.parent
		local position = item.props.position

		if parent == id then
			result[#result + 1] = child_id
		elseif type(position) == "string" and position == ("popup." .. id) then
			result[#result + 1] = child_id
		end
	end

	table.sort(result)
	return result
end

--- Removes one item and all descendants from the registry state.
local function remove_recursive(state, id)
	local children = child_ids_of(state, id)

	for _, child_id in ipairs(children) do
		remove_recursive(state, child_id)
	end

	state.items[id] = nil
	state.subscriptions[id] = nil
	state.routine_next_due[id] = nil

	for index, value in ipairs(state.item_order) do
		if value == id then
			table.remove(state.item_order, index)
			break
		end
	end
end

--- Returns one new registry object.
function M.new()
	local state = {
		items = {},
		item_order = {},
		subscriptions = {},
		routine_next_due = {},
		needs_second_tick = false,
	}

	local registry = {
		_state = state,
	}

	--- Returns one existing item or raises a user-facing error.
	function registry.ensure_item_exists(id)
		local item = state.items[id]

		if not item then
			error("easybar item does not exist: " .. tostring(id))
		end

		return item
	end

	--- Adds one item using optional scoped defaults.
	function registry.add(kind, id, props, defaults)
		assert(type(kind) == "string" and kind ~= "", "easybar.add(kind, id, props) requires kind")
		assert(type(id) == "string" and id ~= "", "easybar.add(kind, id, props) requires id")

		local merged = {}
		deep_merge(merged, normalize_props(defaults or {}))
		deep_merge(merged, normalize_props(props or {}))

		local is_new = state.items[id] == nil

		state.items[id] = {
			id = id,
			kind = kind,
			props = merged,
		}

		if is_new then
			state.item_order[#state.item_order + 1] = id
		end

		if state.items[id].props.update_freq ~= nil then
			state.needs_second_tick = true
		end
	end

	--- Returns one merged property table using registry normalization rules.
	function registry.merge_props(defaults, props)
		local merged = {}
		deep_merge(merged, normalize_props(defaults or {}))
		deep_merge(merged, normalize_props(props or {}))
		return merged
	end

	--- Merges properties into one item.
	function registry.set(id, props)
		local item = registry.ensure_item_exists(id)
		deep_merge(item.props, normalize_props(props or {}))

		if item.props.update_freq ~= nil then
			state.needs_second_tick = true
		end
	end

	--- Returns one copied item property table.
	function registry.get(id)
		local item = registry.ensure_item_exists(id)
		return deep_copy(item.props)
	end

	--- Removes one item and its descendants.
	function registry.remove(id)
		remove_recursive(state, id)
	end

	--- Runs one shell command.
	function registry.exec(command, callback)
		assert(type(command) == "string" and command ~= "", "easybar.exec(command, callback) requires command")

		local pipe = io.popen(command .. " 2>/dev/null")
		local output = ""

		if pipe then
			output = trim_trailing_newlines(pipe:read("*a") or "")
			pipe:close()
		end

		if type(callback) == "function" then
			return callback(output)
		end

		return output
	end

	return registry
end

return M
