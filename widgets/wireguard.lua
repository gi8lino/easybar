local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/config/easybar/?.lua"

local secrets = require("secrets")

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
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

local state = {
	wireguard_connected = false,
}

local function status_label(connected)
	if connected then
		return "Active"
	end

	return "Inactive"
end

local function apply_network_event(event)
	if event == nil or event.network == nil then
		return
	end

	local value = event.network.primary_interface_is_tunnel
	if value ~= nil then
		state.wireguard_connected = value == true
	end
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
	easybar.events.wifi_change,
	easybar.events.minute_tick,
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
