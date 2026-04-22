local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell_quote(s)
	s = tostring(s or "")
	return "'" .. s:gsub("'", [['"'"']]) .. "'"
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
		return "", false, "popen", -1
	end

	local output = handle:read("*a") or ""
	local ok, why, code = handle:close()

	output = trim(output)

	if ok == nil or ok == false then
		return output, false, why or "exit", code or 1
	end

	return output, true, why or "exit", code or 0
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
	exit_node_detail = "Exit node unavailable",
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
	return output:match([["Health"%s*:%s*%[%s*"([^"]+)"]])
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
	local output, ok = shell(shell_quote(tailscale) .. " exit-node suggest")
	if not ok or output == "" then
		return nil
	end

	local suggested = output:match("Suggested exit node:%s*([^\n]+)")
	if suggested == nil then
		return nil
	end

	suggested = trim(suggested)
	if suggested == "" then
		return nil
	end

	return suggested
end

local function update_state(snapshot)
	if state.tailscale_connected ~= snapshot.tailscale_connected then
		easybar.log(
			easybar.level.debug,
			"tailscale state changed",
			snapshot.tailscale_connected and "active" or "inactive"
		)
	end

	if state.exit_node_enabled ~= snapshot.exit_node_enabled then
		easybar.log(
			easybar.level.debug,
			"tailscale exit node changed",
			snapshot.exit_node_enabled and "enabled" or "disabled"
		)
	end

	state.tailscale_connected = snapshot.tailscale_connected
	state.exit_node_enabled = snapshot.exit_node_enabled
	state.status_detail = snapshot.status_detail
	state.exit_node_detail = snapshot.exit_node_detail

	return snapshot
end

local function cli_status()
	local output, ok, why, code = shell(shell_quote(tailscale) .. " status --json")
	if not ok or output == "" then
		local detail = output
		if detail == "" then
			detail = "tailscale status failed"
		end

		easybar.log(
			easybar.level.warn,
			"tailscale status failed",
			"reason=" .. tostring(why),
			"code=" .. tostring(code),
			detail
		)

		return update_state({
			tailscale_connected = false,
			exit_node_enabled = false,
			status_detail = "Unavailable",
			exit_node_detail = "Exit node unavailable",
		})
	end

	local backend_state = parse_backend_state(output)
	local health_message = parse_health_message(output)
	local connected = backend_state == "Running"

	local detail = trim(health_message or backend_state or "")
	if detail == "" then
		detail = status_label(connected)
	end

	local exit_node_enabled = connected and parse_exit_node_enabled(output) or false
	local suggested_exit_node = (connected and not exit_node_enabled) and recommended_exit_node() or nil

	local exit_node_detail
	if not connected then
		exit_node_detail = "Exit node unavailable"
	elseif exit_node_enabled then
		exit_node_detail = "Exit node on"
	elseif suggested_exit_node then
		exit_node_detail = "Exit node off (" .. suggested_exit_node .. ")"
	else
		exit_node_detail = "Exit node off"
	end

	return update_state({
		tailscale_connected = connected,
		exit_node_enabled = exit_node_enabled,
		status_detail = detail,
		exit_node_detail = exit_node_detail,
	})
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

local function render(snapshot)
	local tailscale_logo_path = asset_path(current_icon_name(snapshot.tailscale_connected, snapshot.exit_node_enabled))

	easybar.set("tailscale_icon", {
		icon = {
			string = "",
			image = tailscale_logo_path,
			image_size = 16,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = 1.0,
	})

	easybar.set("tailscale_popup_label", {
		label = {
			string = snapshot.status_detail or status_label(snapshot.tailscale_connected),
		},
	})

	easybar.set("tailscale_popup_exit_node_label", {
		drawing = snapshot.tailscale_connected and "on" or "off",
		label = {
			string = snapshot.exit_node_detail,
		},
	})
end

local function toggle_tailscale()
	local snapshot = cli_status()
	local command

	if snapshot.tailscale_connected then
		command = shell_quote(tailscale) .. " down"
	else
		command = shell_quote(tailscale) .. " up"
	end

	local output, ok, why, code = shell(command)

	if not ok then
		easybar.log(
			easybar.level.warn,
			"tailscale toggle failed",
			command,
			"reason=" .. tostring(why),
			"code=" .. tostring(code),
			output ~= "" and output or "<empty>"
		)
	else
		easybar.log(easybar.level.info, "tailscale toggle ok", command, output ~= "" and output or "<empty>")
	end

	refresh()
end

local function toggle_exit_node()
	local snapshot = cli_status()
	if not snapshot.tailscale_connected then
		easybar.log(easybar.level.warn, "tailscale exit node toggle ignored", "tailscale inactive")
		refresh()
		return
	end

	local command
	if snapshot.exit_node_enabled then
		command = shell_quote(tailscale) .. " set --exit-node= --accept-routes"
	else
		command = shell_quote(tailscale) .. " set --exit-node=auto:any --accept-routes"
	end

	local output, ok, why, code = shell(command)

	if not ok then
		easybar.log(
			easybar.level.warn,
			"tailscale exit node toggle failed",
			command,
			"reason=" .. tostring(why),
			"code=" .. tostring(code),
			output ~= "" and output or "<empty>"
		)
	else
		easybar.log(easybar.level.info, "tailscale exit node toggle ok", command, output ~= "" and output or "<empty>")
	end

	refresh()
end

refresh = function()
	local snapshot = cli_status()
	render(snapshot)
end

easybar.add(easybar.kind.item, "tailscale_icon", {
	position = "right",
	order = 2,
	interval = 10,
	icon = {
		image = asset_path("tailscale-inactive.png"),
		image_size = 16,
	},
	popup = {
		drawing = "on",
	},
	on_interval = function()
		refresh()
	end,
})

easybar.add(easybar.kind.item, "tailscale_popup_label", {
	position = "popup.tailscale_icon",
	label = {
		string = "",
	},
})

easybar.add(easybar.kind.item, "tailscale_popup_exit_node_label", {
	position = "popup.tailscale_icon",
	drawing = "off",
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
	if event.button == nil or event.button == easybar.events.mouse.left_button then
		toggle_tailscale()
		return
	end

	if event.button == easybar.events.mouse.right_button then
		toggle_exit_node()
	end
end)

refresh()
