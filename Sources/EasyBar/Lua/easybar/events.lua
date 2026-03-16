local M = {}

-- Returns whether one widget subscribed to an event.
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

-- Merges one event result table back into the live widget state.
local function merge_update(widget, update)
	if type(update) ~= "table" then
		return
	end

	for key, value in pairs(update) do
		widget[key] = value
	end
end

-- Dispatches one event to all matching widgets.
function M.dispatch_event(widgets, event_name, payload, render, log, json)
	log.debug("runtime dispatch event=" .. tostring(event_name))

	local target_widget = payload and payload.widget or nil

	for _, widget in pairs(widgets) do
		local matches_target = (target_widget == nil) or (widget.id == target_widget)

		if not matches_target then
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
			log.error(
				"widget "
					.. tostring(widget.id)
					.. " failed event="
					.. tostring(event_name)
					.. " error="
					.. tostring(result)
			)
			goto continue
		end

		if type(result) == "table" then
			merge_update(widget, result)
			render.emit_tree(widget, log, json)
		end

		::continue::
	end
end

return M
