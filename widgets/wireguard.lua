local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/config/easybar/?.lua"

local secrets = require("secrets")

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function quote(s)
	return string.format("%q", s or "")
end

local state = {
	wireguard_connected = false,
}

local function status_label(connected)
	if connected then
		return "Active"
	end

	return "Inactive"
end

local function run_shell(command)
	local pipe = io.popen(command .. " 2>&1")
	if not pipe then
		easybar.log(easybar.level.error, "shell popen failed", command)
		return nil, "popen failed"
	end

	local output = pipe:read("*a") or ""
	local ok, _, code = pipe:close()

	local trimmed = trim(output)

	if ok then
		if trimmed ~= "" then
			easybar.log(easybar.level.trace, "shell ok", command, trimmed)
		else
			easybar.log(easybar.level.trace, "shell ok", command, "<empty>")
		end
		return trimmed, nil
	end

	easybar.log(
		easybar.level.warn,
		"shell command failed",
		command,
		"code",
		tostring(code),
		"output",
		trimmed ~= "" and trimmed or "<empty>"
	)
	return trimmed, code or "command failed"
end

local function current_status(vpn_name)
	local name = quote(vpn_name)
	local output, err = run_shell("scutil --nc status " .. name)
	if err ~= nil then
		return nil, err
	end

	return (output or ""):lower(), nil
end

local function apply_network_event(event)
	if event == nil or event.network == nil then
		return
	end

	local value = event.network.primary_interface_is_tunnel
	if value ~= nil then
		local connected = value == true
		if state.wireguard_connected ~= connected then
			state.wireguard_connected = connected
			easybar.log(easybar.level.debug, "wireguard tunnel state changed", connected and "active" or "inactive")
		else
			state.wireguard_connected = connected
		end
	end
end

local function toggle_wireguard()
	local vpn_name = secrets.vpn_name or ""
	if vpn_name == "" then
		easybar.log(easybar.level.warn, "wireguard toggle skipped because secrets.vpn_name is empty")
		return
	end

	local status, err = current_status(vpn_name)
	if err ~= nil or status == nil then
		easybar.log(easybar.level.warn, "failed to read wireguard status", vpn_name)
		return
	end

	easybar.log(easybar.level.debug, "wireguard status", vpn_name, status)

	local name = quote(vpn_name)

	if status:match("^connected") or status:match("^connecting") or status:match("^on demand") then
		easybar.log(easybar.level.info, "stopping wireguard", vpn_name)
		run_shell("scutil --nc stop " .. name)
	else
		easybar.log(easybar.level.info, "starting wireguard", vpn_name)
		run_shell("scutil --nc start " .. name)
	end
end

local function refresh()
	local wireguard_connected = state.wireguard_connected
	local logo_path = home .. "/.config/easybar/assets/wireguard.png"
	local icon_opacity = wireguard_connected and 1.0 or 0.45

	easybar.set("wireguard_icon", {
		icon = {
			string = "",
			image = logo_path,
			image_size = 16,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = icon_opacity,
	})

	easybar.set("wireguard_popup_label", {
		label = {
			string = status_label(wireguard_connected),
			color = "#cad3f5",
		},
	})
end

easybar.add("group", "wireguard", {
	position = "right",
	order = 2,
	background = {
		color = "#202020",
		border_color = "#4a4a4a",
		border_width = 1,
		corner_radius = 8,
		padding_left = 12,
		padding_right = 12,
		padding_top = 6,
		padding_bottom = 6,
	},
	spacing = 0,
	popup = {
		drawing = true,
	},
})

easybar.add("item", "wireguard_icon", {
	parent = "wireguard",
	icon = {
		string = "",
		image = home .. "/.config/easybar/assets/wireguard.png",
		image_size = 22,
		image_corner_radius = 0,
	},
	label = {
		string = "",
	},
})

easybar.add("item", "wireguard_popup_label", {
	position = "popup.wireguard",
	label = {
		string = "",
	},
})

easybar.subscribe("wireguard", {
	easybar.events.network_change,
	easybar.events.forced,
}, function(event)
	apply_network_event(event)
	refresh()
end)

easybar.subscribe("wireguard", easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == "left" then
		toggle_wireguard()
	end
end)

refresh()
