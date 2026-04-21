local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function quote(s)
	return string.format("%q", s or "")
end

local function script_dir()
	local source = debug.getinfo(1, "S").source or ""
	local path = source:gsub("^@", "")
	return path:match("(.*/)")
end

local function asset_path(name)
	local dir = script_dir()
	if dir == nil then
		return name
	end

	return dir .. "assets/" .. name
end

local function shell(command)
	local handle = io.popen(command .. " 2>&1")
	if not handle then
		return "", false
	end

	local output = handle:read("*a") or ""
	local ok = handle:close()
	return trim(output), ok == true
end

local function resolve_tailscale()
	local configured = trim(os.getenv("TAILSCALE") or "")
	if configured ~= "" then
		return configured
	end

	return "tailscale"
end

local tailscale = resolve_tailscale()

local state = {
	tailscale_connected = false,
	exit_node_enabled = false,
	status_detail = "Inactive",
	exit_node_detail = "Exit node off",
}

local refresh

local function status_label(connected)
	if connected then
		return "Active"
	end

	return "Inactive"
end

local function parse_backend_state(output)
	return output:match([["BackendState"%s*:%s*"([^"]+)"]])
end

local function parse_health_message(output)
	return output:match([["Health"%s*:%s*%[%s*"([^"]*)"]])
end

local function parse_exit_node_enabled(output)
	if output:match([["ExitNodeStatus"%s*:%s*{]]) then
		return true
	end

	if output:match([["ExitNodeStatus"%s*:%s*null]]) then
		return false
	end

	return false
end

local function recommended_exit_node()
	local output, ok = shell(quote(tailscale) .. " exit-node suggest")
	if not ok or output == "" then
		return nil
	end

	local suggested = output:match("Suggested exit node:%s*([^\n]+)")
	if suggested == nil or trim(suggested) == "" then
		return nil
	end

	return trim(suggested)
end

local function cli_status()
	local output, ok = shell(quote(tailscale) .. " status --json")
	if not ok or output == "" then
		easybar.log(easybar.level.warn, "tailscale status failed", output ~= "" and output or "<empty>")
		return false, state.status_detail, state.exit_node_enabled, state.exit_node_detail
	end

	local backend_state = parse_backend_state(output)
	local health_message = parse_health_message(output)
	local connected = backend_state == "Running"
	local detail = health_message or backend_state or status_label(connected)

	if detail == "" then
		detail = status_label(connected)
	end

	local exit_node_enabled = connected and parse_exit_node_enabled(output) or false
	local suggested_exit_node = connected and recommended_exit_node() or nil
	local exit_node_detail

	if not connected then
		exit_node_detail = "Exit node unavailable"
	elseif exit_node_enabled then
		exit_node_detail = suggested_exit_node and ("Exit node on (" .. suggested_exit_node .. ")") or "Exit node on"
	else
		exit_node_detail = suggested_exit_node and ("Exit node off (" .. suggested_exit_node .. ")") or "Exit node off"
	end

	if state.tailscale_connected ~= connected then
		easybar.log(
			easybar.level.debug,
			"tailscale state changed",
			connected and "active" or "inactive",
			backend_state or "<unknown>"
		)
	end

	if state.exit_node_enabled ~= exit_node_enabled then
		easybar.log(easybar.level.debug, "tailscale exit node changed", exit_node_enabled and "enabled" or "disabled")
	end

	state.tailscale_connected = connected
	state.exit_node_enabled = exit_node_enabled
	state.status_detail = detail
	state.exit_node_detail = exit_node_detail

	return connected, detail, exit_node_enabled, exit_node_detail
end

local function toggle_tailscale()
	local connected = cli_status()
	local command = connected and (quote(tailscale) .. " down") or (quote(tailscale) .. " up")
	local output, ok = shell(command)

	if not ok then
		easybar.log(easybar.level.warn, "tailscale toggle failed", command, output ~= "" and output or "<empty>")
	else
		easybar.log(easybar.level.info, "tailscale toggle ok", command, output ~= "" and output or "<empty>")
	end

	cli_status()
	refresh()
end

local function toggle_exit_node()
	local connected = cli_status()
	if not connected then
		easybar.log(easybar.level.warn, "tailscale exit node toggle ignored", "tailscale inactive")
		refresh()
		return
	end

	local command
	if state.exit_node_enabled then
		command = quote(tailscale) .. " set --exit-node= --accept-routes"
	else
		command = quote(tailscale) .. " set --exit-node=auto:any --accept-routes"
	end

	local output, ok = shell(command)
	if not ok then
		easybar.log(
			easybar.level.warn,
			"tailscale exit node toggle failed",
			command,
			output ~= "" and output or "<empty>"
		)
	else
		easybar.log(easybar.level.info, "tailscale exit node toggle ok", command, output ~= "" and output or "<empty>")
	end

	cli_status()
	refresh()
end

local function current_icon_name(connected, exit_node_enabled)
	if not connected then
		return "tailscale-inactive.png"
	end

	if exit_node_enabled then
		return "tailscale-active-exit-node.png"
	end

	return "tailscale-active.png"
end

refresh = function()
	local tailscale_connected, detail, exit_node_enabled, exit_node_detail = cli_status()
	local tailscale_logo_path = asset_path(current_icon_name(tailscale_connected, exit_node_enabled))

	easybar.set("tailscale_icon", {
		icon = {
			string = "",
			image = tailscale_logo_path,
			image_size = 18,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = 1.0,
	})

	easybar.set("tailscale_popup_label", {
		label = {
			string = detail or status_label(tailscale_connected),
			color = "#cad3f5",
		},
	})

	easybar.set("tailscale_popup_exit_node_label", {
		drawing = tailscale_connected,
		label = {
			string = exit_node_detail,
			color = "#cad3f5",
		},
	})
end

easybar.add("item", "tailscale_icon", {
	position = "right",
	order = 2,
	interval = 10,
	icon = {
		string = "",
		image = asset_path("tailscale-inactive.png"),
		image_size = 22,
		image_corner_radius = 0,
	},
	label = {
		string = "",
	},
	background = {
		color = "#202020",
		border_color = "#4a4a4a",
		border_width = 1,
		corner_radius = 8,
		padding_left = 12,
		padding_right = 12,
		padding_top = 2,
		padding_bottom = 2,
	},
	popup = {
		drawing = true,
	},
	on_interval = function()
		refresh()
	end,
})

easybar.add("item", "tailscale_popup_label", {
	position = "popup.tailscale_icon",
	label = {
		string = "",
	},
})

easybar.add("item", "tailscale_popup_exit_node_label", {
	position = "popup.tailscale_icon",
	drawing = false,
	label = {
		string = "",
	},
})

easybar.subscribe("tailscale_icon", {
	easybar.events.network_change,
	easybar.events.system_woke,
	easybar.events.forced,
}, function()
	refresh()
end)

easybar.subscribe("tailscale_icon", easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == "left" then
		toggle_tailscale()
		return
	end

	if event.button == "right" then
		toggle_exit_node()
	end
end)

refresh()
