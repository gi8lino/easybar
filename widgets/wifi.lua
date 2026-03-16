local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function current_wifi_state()
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
		return {
			icon = "􀙇",
			label = ssid,
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
			label = "Connected",
			color = "#f5a97f",
		}
	end

	return {
		icon = "􀙈",
		label = "Not Connected",
		color = "#c6a0f6",
	}
end

local function full_state(label_visible)
	local state = current_wifi_state()

	return {
		children = {
			{
				id = "wifi_icon",
				kind = "item",
				icon = state.icon,
				text = "",
				color = state.color,
				visible = true,
			},
			{
				id = "wifi_label",
				kind = "item",
				icon = "",
				text = state.label,
				color = state.color,
				visible = label_visible,
			},
		},
	}
end

return {
	id = "wifi",
	kind = "row",
	position = "right",
	order = 20,
	spacing = 6,
	paddingX = 8,
	paddingY = 4,

	children = {
		{
			id = "wifi_icon",
			kind = "item",
			icon = "􀙈",
			text = "",
			color = "#f5a97f",
			visible = true,
		},
		{
			id = "wifi_label",
			kind = "item",
			icon = "",
			text = "",
			color = "#f5a97f",
			visible = false,
		},
	},

	subscribe = {
		"init",
		"wifi_change",
		"network_change",
		"system_woke",
		"mouse.entered",
		"mouse.exited",
	},

	on_event = function(event, _)
		if event == "mouse.entered" then
			return full_state(true)
		end

		if event == "mouse.exited" then
			return full_state(false)
		end

		if event == "init" or event == "wifi_change" or event == "network_change" or event == "system_woke" then
			return full_state(false)
		end
	end,
}
