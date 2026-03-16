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

local function first_line(s)
	if not s then
		return ""
	end

	return trim((s:gsub("\r", "")):match("([^\n]*)") or "")
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
	local output = shell("scutil --nwi")
	return output:match("utun") ~= nil
end

local function toggle_vpn()
	local vpn_name = trim(os.getenv("EASYBAR_VPN_NAME") or "")
	if vpn_name == "" then
		io.stderr:write("ERROR: wifi_vpn missing EASYBAR_VPN_NAME\n")
		io.stderr:flush()
		return
	end

	local name = quote(vpn_name)
	local status = first_line(shell("scutil --nc status " .. name)):lower()

	io.stderr:write("INFO: wifi_vpn toggle click vpn_name=" .. vpn_name .. " status=" .. status .. "\n")
	io.stderr:flush()

	if status == "connected" or status:match("^connecting") or status:match("^on demand") then
		shell("scutil --nc stop " .. name)
	else
		shell("scutil --nc start " .. name)
	end
end

local function build_widget(show_wifi_label)
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

	local children = {
		{
			id = "wifi_vpn_wifi",
			kind = "item",
			icon = wifi_icon,
			text = show_wifi_label and wifi_label or "",
			color = wifi_color,
			spacing = 8,
		},
	}

	if vpn_connected then
		children[#children + 1] = {
			id = "wifi_vpn_vpn",
			kind = "item",
			icon = "󰦝 ",
			text = "",
			color = "#30d158",
		}
	end

	return children
end

local show_wifi_label = false

return {
	id = "wifi_vpn",
	kind = "row",
	position = "right",
	order = 25,
	paddingX = 8,
	paddingY = 4,
	spacing = 15,
	backgroundColor = "#1a1a1a",
	borderColor = "#333333",
	borderWidth = 1,
	cornerRadius = 8,
	subscribe = {
		"init",
		"wifi_change",
		"network_change",
		"minute_tick",
		"mouse.entered",
		"mouse.exited",
		"mouse.clicked",
	},
	on_event = function(event, payload)
		io.stderr:write(
			"INFO: wifi_vpn event=" .. tostring(event) .. " widget=" .. tostring(payload and payload.widget) .. "\n"
		)
		io.stderr:flush()

		if payload and payload.widget ~= "wifi_vpn" and payload.widget ~= nil then
			if event == "wifi_change" or event == "network_change" or event == "minute_tick" or event == "init" then
				return {
					children = build_widget(show_wifi_label),
				}
			end

			return nil
		end

		if event == "mouse.entered" then
			show_wifi_label = true
		elseif event == "mouse.exited" then
			show_wifi_label = false
		elseif event == "mouse.clicked" then
			toggle_vpn()
		end

		return {
			children = build_widget(show_wifi_label),
		}
	end,
}
