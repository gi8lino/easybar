local function first_line(s)
	if not s then
		return ""
	end

	s = s:gsub("\r", "")
	return (s:match("([^\n]*)") or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function read_vpn_status()
	local handle = io.popen("scutil --nwi 2>/dev/null")
	if not handle then
		return {
			icon = "󰌾",
			text = "VPN Off",
			color = "#6e738d",
		}
	end

	local output = handle:read("*a") or ""
	handle:close()

	local vpnConnected = output:match("utun") ~= nil

	if vpnConnected then
		return {
			icon = "󰦝",
			text = "VPN On",
			color = "#91d7e3",
		}
	end

	return {
		icon = "󰌾",
		text = "VPN Off",
		color = "#6e738d",
	}
end

return {
	id = "vpn",
	position = "right",
	order = 41,
	icon = "",
	text = "",
	color = "",

	subscribe = { "init", "wifi_change", "network_change", "system_woke" },

	on_event = function(event, _)
		if event == "init" or event == "wifi_change" or event == "network_change" or event == "system_woke" then
			return read_vpn_status()
		end
	end,
}
