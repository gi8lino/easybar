local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/config/easybar/?.lua"

local secrets = require("secrets")

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell(command)
	local pipe = io.popen(command .. " 2>/dev/null")
	if not pipe then
		easybar.log("error", "shell popen failed")
		return ""
	end

	local output = pipe:read("*a") or ""
	pipe:close()

	return output
end

local function debug_shell(command)
	local pipe = io.popen(command .. " 2>&1")
	if not pipe then
		easybar.log("error", "debug shell popen failed", command)
		return ""
	end

	local output = pipe:read("*a") or ""
	pipe:close()

	easybar.log("info", "command", command, "output", trim(output))
	return output
end

local function quote(s)
	return string.format("%q", s or "")
end

local function get_network_fields()
	local command = "wifisnitchctl field network.primary_interface_is_tunnel --format=lines"
	local output = shell(command)

	local result = {
		primary_interface_is_tunnel = false,
	}

	for line in output:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		value = trim(value)

		if key == "network.primary_interface_is_tunnel" then
			result.primary_interface_is_tunnel = value == "true"
		end
	end

	return result
end

local function get_wireguard_status(fields)
	return fields.primary_interface_is_tunnel
end

local function status_label(wireguard_connected)
	if wireguard_connected then
		return "Active"
	end

	return "Inactive"
end

local function toggle_wireguard()
	local vpn_name = secrets.vpn_name or ""
	if vpn_name == "" then
		easybar.log("warn", "wireguard toggle skipped because secrets.vpn_name is empty")
		return
	end

	local name = quote(vpn_name)
	local status = trim(debug_shell("scutil --nc status " .. name)):lower()
	easybar.log("info", "vpn_name", vpn_name, "status", status)

	if status:match("^connected") or status:match("^connecting") or status:match("^on demand") then
		debug_shell("scutil --nc stop " .. name)
	else
		debug_shell("scutil --nc start " .. name)
	end
end

local function refresh()
	local fields = get_network_fields()
	local wireguard_connected = get_wireguard_status(fields)
	local logo_path = home .. "/.config/easybar/assets/wireguard.png"
	local logo_exists = io.open(logo_path, "rb") ~= nil
	local icon_opacity = wireguard_connected and 1.0 or 0.7

	if logo_exists then
		local handle = io.open(logo_path, "rb")
		if handle then
			handle:close()
		end
	end

	easybar.set("wireguard_icon", {
		icon = {
			string = logo_exists and "" or "WG",
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
		string = "WG",
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

easybar.subscribe("wireguard", { easybar.events.network_change, easybar.events.wifi_change, easybar.events.minute_tick, easybar.events.forced }, function(_)
	refresh()
end)

easybar.subscribe("wireguard", easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == "left" then
		toggle_wireguard()
		refresh()
	end
end)

refresh()
