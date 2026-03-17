local function read_ssid()
	local handle = io.popen(
		"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk -F': ' '/ SSID/ {print $2}' 2>/dev/null"
	)

	if not handle then
		return "offline"
	end

	local value = handle:read("*a") or ""
	handle:close()

	value = value:gsub("\r", ""):gsub("\n", "")
	if value == "" then
		return "offline"
	end

	return value
end

easybar.add("item", "network", {
	position = "right",
	order = 35,
	update_freq = 30,
	icon = {
		string = "📶",
	},
	label = "",
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
})

easybar.subscribe("network", { "routine", "network_change", "wifi_change", "system_woke", "forced" }, function()
	easybar.set("network", {
		label = read_ssid(),
	})
end)
