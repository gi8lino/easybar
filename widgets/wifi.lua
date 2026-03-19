local secrets = require("secrets")

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell(command)
	local pipe = io.popen(command .. " 2>/dev/null")
	if not pipe then
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
	local home = os.getenv("HOME") or ""
	local command = home .. "/.local/bin/wifisnitchctl get wifi.ssid,network.primary_interface --format=lines"

	local output = shell(command)

	local result = {
		ssid = "",
		primary_interface = "",
	}

	for line in output:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		value = trim(value)

		if key == "wifi.ssid" then
			result.ssid = value
		elseif key == "network.primary_interface" then
			result.primary_interface = value
		end
	end

	return result
end

local function get_wifi_status()
	local fields = get_network_fields()
	local ssid = fields.ssid
	local primary_interface = fields.primary_interface

	if ssid ~= "" then
		return ssid, true
	end

	if primary_interface == "en0" then
		return "", true
	end

	return "", false
end

local function get_vpn_status()
	local fields = get_network_fields()
	local primary_interface = fields.primary_interface

	-- Show VPN only when the active primary route goes through a utun device.
	return primary_interface:match("^utun%d+$") ~= nil
end

local function toggle_vpn()
	local vpn_name = secrets.vpn_name or ""
	if vpn_name == "" then
		easybar.log("warn", "missing vpn name")
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

local function refresh(show_label)
	local ssid, wifi_connected = get_wifi_status()
	local vpn_connected = get_vpn_status()

	local wifi_icon = "􀙇"
	local wifi_label = ""
	local wifi_color = "#ff9f0a"

	if not wifi_connected then
		wifi_icon = "􀙈"
		wifi_label = "Not Connected"
		wifi_color = "#ff4f8b"
	elseif ssid ~= "" then
		wifi_label = ssid
	end

	easybar.set("wifi_vpn_wifi", {
		icon = {
			string = wifi_icon,
			color = wifi_color,
		},
		label = {
			string = show_label and wifi_label or "",
			color = wifi_color,
		},
	})

	easybar.set("wifi_vpn_vpn", {
		drawing = vpn_connected,
		icon = {
			string = "󰦝 ",
			color = "#30d158",
			font = { size = 14 },
		},
		label = {
			string = "",
		},
	})
end

easybar.add("row", "wifi_vpn", {
	position = "right",
	order = 25,
	background = {
		color = "#1a1a1a",
		border_color = "#333333",
		border_width = 1,
		corner_radius = 8,
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	spacing = 15,
	click_script = "",
})

easybar.add("item", "wifi_vpn_wifi", {
	parent = "wifi_vpn",
})

easybar.add("item", "wifi_vpn_vpn", {
	parent = "wifi_vpn",
	drawing = false,
})

local show_label = false

easybar.subscribe("wifi_vpn", { "wifi_change", "network_change", "minute_tick", "forced" }, function(event)
	local _ = event
	refresh(show_label)
end)

easybar.subscribe("wifi_vpn", "mouse.entered", function(event)
	local _ = event
	show_label = true
	refresh(true)
end)

easybar.subscribe("wifi_vpn", "mouse.exited", function(event)
	local _ = event
	show_label = false
	refresh(false)
end)

easybar.subscribe("wifi_vpn", "mouse.clicked", function(event)
	if event.button == nil or event.button == "left" then
		toggle_vpn()
		refresh(show_label)
	end
end)
