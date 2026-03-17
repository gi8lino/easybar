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

local function get_wifi_status()
	local ssid = ""
	local output = shell(os.getenv("HOME") .. "/.local/bin/wifisnitchctl get wifi.ssid --format=lines")

	for line in output:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		value = trim(value)

		if key == "wifi.ssid" then
			ssid = value
		end
	end

	if ssid ~= "" then
		return ssid, true
	end

	local summary = shell("ipconfig getsummary en0")
	local connected = summary:match("LinkStatusActive : TRUE") ~= nil

	return "", connected
end

local function get_vpn_status()
	return shell("scutil --nwi"):match("utun") ~= nil
end

local function toggle_vpn()
	local vpn_name = trim(os.getenv("EASYBAR_VPN_NAME") or "")
	if vpn_name == "" then
		return
	end

	local name = quote(vpn_name)
	local status = trim(shell("scutil --nc status " .. name)):lower()

	if status == "connected" or status:match("^connecting") or status:match("^on demand") then
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
			string = "󰦝",
			color = "#30d158",
			font = { size = 14 },
		},
		label = "",
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

easybar.subscribe("wifi_vpn", { "wifi_change", "network_change", "minute_tick", "forced" }, function()
	refresh(show_label)
end)

easybar.subscribe("wifi_vpn", "mouse.entered", function()
	show_label = true
	refresh(true)
end)

easybar.subscribe("wifi_vpn", "mouse.exited", function()
	show_label = false
	refresh(false)
end)

easybar.subscribe("wifi_vpn", "mouse.clicked", function()
	toggle_vpn()
	refresh(show_label)
end)
