local M = {}

function M.dispatch_event(registry, event_name, payload, render, log, json)
	log.debug("runtime dispatch event=" .. tostring(event_name))
	registry.handle_event(event_name, payload)
	render.emit_all(registry, log, json)
end

return M
