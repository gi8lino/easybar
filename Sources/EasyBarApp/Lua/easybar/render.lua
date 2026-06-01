--- Module contract:
--- Owns high-level rendering orchestration across style, tree, flatten, and emission helpers.
--- Returns one helper that emits the current widget trees for the Swift host.
local M = {}

local style = require("easybar.render.style")
local tree = require("easybar.render.tree")
local emitter = require("easybar.render.emitter")

function M.emit_all(registry, log, json)
	local trees = {}
	local live_roots = {}

	for _, id in ipairs(tree.root_ids(registry)) do
		local item = registry._state.items[id]

		if item ~= nil then
			live_roots[id] = true
			local root_position = style.normalize_position(item.props.position)
			local built = tree.build_tree(registry, id, root_position)

			if built ~= nil then
				trees[#trees + 1] = built
			end
		end
	end

	emitter.emit_all(trees, live_roots, log, json)
end

return M
