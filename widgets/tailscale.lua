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
	status_detail = "Inactive",
}

local refresh

local function status_label(connected)
	if connected then
		return "Active"
	end

	return "Inactive"
end

local function cli_status()
	local output, ok = shell(quote(tailscale) .. " status --json")
	if not ok or output == "" then
		easybar.log(easybar.level.warn, "tailscale status failed", output ~= "" and output or "<empty>")
		return false, state.status_detail
	end

	local backend_state = output:match([["BackendState"%s*:%s*"([^"]+)"]])
	local health_message = output:match([["Health"%s*:%s*%[%s*"([^"]*)"]])
	local connected = backend_state == "Running"
	local detail = health_message or backend_state or status_label(connected)

	if detail == "" then
		detail = status_label(connected)
	end

	if state.tailscale_connected ~= connected then
		easybar.log(
			easybar.level.debug,
			"tailscale state changed",
			connected and "active" or "inactive",
			backend_state or "<unknown>"
		)
	end

	state.tailscale_connected = connected
	state.status_detail = detail
	return connected, detail
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

refresh = function()
	local tailscale_connected, detail = cli_status()
	local logo_path = tailscale_connected and asset_path("tailscale-active.png") or asset_path("tailscale-inactive.png")

	easybar.set("tailscale_icon", {
		icon = {
			string = "",
			image = logo_path,
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
			string = detail or status_label(tailscale_connected),
			color = "#cad3f5",
		},
	})
end

easybar.add("group", "tailscale", {
	position = "right",
	order = 2,
	interval = 10,
	background = {
		color = "#202020",
		border_color = "#4a4a4a",
		border_width = 1,
		corner_radius = 8,
		padding_left = 12,
		padding_right = 12,
		padding_top = 4,
		padding_bottom = 4,
	},
	spacing = 0,
	popup = {
		drawing = true,
	},
	on_interval = function()
		refresh()
	end,
})

easybar.add("item", "tailscale_icon", {
	parent = "tailscale",
	icon = {
		string = "",
		image = asset_path("tailscale-inactive.png"),
		image_size = 22,
		image_corner_radius = 0,
	},
	label = {
		string = "",
	},
})

easybar.add("item", "tailscale_popup_label", {
	position = "popup.tailscale",
	label = {
		string = "",
	},
})

easybar.subscribe("tailscale", {
	easybar.events.network_change,
	easybar.events.system_woke,
	easybar.events.forced,
}, function()
	refresh()
end)

easybar.subscribe("tailscale", easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == "left" then
		toggle_tailscale()
	end
end)

refresh()
