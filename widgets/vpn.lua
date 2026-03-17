local function read_vpn_status()
	local handle = io.popen("scutil --nwi 2>/dev/null")
	if not handle then
		return {
			icon = "󰌾",
			label = "VPN Off",
			color = "#6e738d",
		}
	end

	local output = handle:read("*a") or ""
	handle:close()

	local vpn_connected = output:match("utun") ~= nil

	if vpn_connected then
		return {
			icon = "󰦝",
			label = "VPN On",
			color = "#91d7e3",
		}
	end

	return {
		icon = "󰌾",
		label = "VPN Off",
		color = "#6e738d",
	}
end

easybar.add("item", "vpn", {
	position = "right",
	order = 41,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
})

easybar.subscribe("vpn", { "network_change", "wifi_change", "system_woke", "forced" }, function()
	local state = read_vpn_status()

	easybar.set("vpn", {
		icon = {
			string = state.icon,
			color = state.color,
		},
		label = {
			string = state.label,
			color = state.color,
		},
	})
end)
