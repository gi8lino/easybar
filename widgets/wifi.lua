local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function read_wifi_status()
	local ssid = ""
	local connected = false

	local home = os.getenv("HOME") or ""

	local handle = io.popen(home .. "/.local/bin/wifisnitchctl get wifi.ssid --format=lines 2>/dev/null")
	if handle then
		local output = handle:read("*a") or ""
		handle:close()

		for line in output:gmatch("[^\r\n]+") do
			local key, value = line:match("^([^=]+)=(.*)$")
			value = trim(value)

			if key == "wifi.ssid" then
				ssid = value
			end
		end
	end

	if ssid ~= "" then
		connected = true
		return {
			icon = "􀙇",
			text = ssid,
			color = "#f5a97f",
		}
	end

	local summaryHandle = io.popen("ipconfig getsummary en0 2>/dev/null")
	if summaryHandle then
		local summary = summaryHandle:read("*a") or ""
		summaryHandle:close()

		connected = summary:match("LinkStatusActive : TRUE") ~= nil
	end

	if connected then
		return {
			icon = "􀙇",
			text = "Connected",
			color = "#f5a97f",
		}
	end

	return {
		icon = "􀙈",
		text = "Not Connected",
		color = "#c6a0f6",
	}
end

return {
	id = "wifi",
	position = "right",
	order = 40,
	icon = "",
	text = "",
	color = "",

	subscribe = {
		"init",
		"wifi_change",
		"network_change",
		"system_woke",
		"mouse.entered",
		"mouse.exited",
		"mouse.clicked",
		"mouse.scrolled",
	},

	on_event = function(event, payload)
		if event == "init" or event == "wifi_change" or event == "network_change" or event == "system_woke" then
			return read_wifi_status()
		end

		if event == "mouse.entered" then
			local state = read_wifi_status()
			return {
				icon = state.icon,
				text = " " .. state.text,
				color = state.color,
			}
		end

		if event == "mouse.exited" then
			local state = read_wifi_status()
			return {
				icon = state.icon,
				text = "",
				color = state.color,
			}
		end

		if event == "mouse.clicked" then
			if payload and payload.button == "right" then
				os.execute("open -a 'System Settings'")
			end

			return read_wifi_status()
		end

		if event == "mouse.scrolled" then
			return read_wifi_status()
		end
	end,
}
