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

local function quote(s)
	return string.format("%q", s or "")
end

local function get_network_fields()
	local command = "wifisnitchctl get network.primary_interface_is_tunnel --format=lines"
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
	local status = trim(shell("scutil --nc status " .. name)):lower()

	if status:match("^connected") or status:match("^connecting") or status:match("^on demand") then
		shell("scutil --nc stop " .. name)
	else
		shell("scutil --nc start " .. name)
	end
end

local function set_popup_visible(visible)
	easybar.set("wireguard", {
		popup = { drawing = visible },
	})
end

local function refresh()
	local fields = get_network_fields()
	local wireguard_connected = get_wireguard_status(fields)
	local logo_path = home .. "/.config/easybar/assets/wireguard.png"
	local logo_opacity = wireguard_connected and 1.0 or 0.45
	local logo_exists = io.open(logo_path, "rb") ~= nil

	if logo_exists then
		local handle = io.open(logo_path, "rb")
		if handle then
			handle:close()
		end
	end

	easybar.set("wireguard", {
		icon = {
			string = logo_exists and "" or "WG",
			image = logo_path,
			image_size = 16,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = logo_opacity,
	})

	easybar.set("wireguard_popup_label", {
		label = {
			string = status_label(wireguard_connected),
			color = "#cad3f5",
		},
	})
end

easybar.add("item", "wireguard", {
	position = "right",
	order = 42,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	popup = {
		drawing = false,
		background = {
			color = "#1e2030",
			border_color = "#494d64",
			border_width = 1,
			corner_radius = 10,
		},
		padding_left = 8,
		padding_right = 8,
		padding_top = 6,
		padding_bottom = 6,
		spacing = 0,
	},
	icon = {
		string = "WG",
		image = home .. "/.config/easybar/assets/wireguard.png",
		image_size = 16,
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

easybar.subscribe("wireguard", { "network_change", "wifi_change", "minute_tick", "forced" }, function(_)
	refresh()
end)

easybar.subscribe("wireguard", "mouse.entered", function(_)
	set_popup_visible(true)
	refresh()
end)

easybar.subscribe("wireguard", "mouse.exited", function(_)
	set_popup_visible(false)
end)

easybar.subscribe("wireguard", "mouse.clicked", function(event)
	if event.button == nil or event.button == "left" then
		toggle_wireguard()
		refresh()
	end
end)

easybar.subscribe("wireguard_popup_label", "mouse.clicked", function(event)
	if event.button == nil or event.button == "left" then
		toggle_wireguard()
		refresh()
	end
end)

refresh()
