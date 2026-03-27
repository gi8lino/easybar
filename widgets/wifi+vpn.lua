local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell(command)
	local handle = io.popen(command .. " 2>/dev/null")
	if not handle then
		return ""
	end

	local output = handle:read("*a") or ""
	handle:close()
	return output
end

local function resolve_wifisnitchctl()
	local candidates = {
		os.getenv("WIFISNITCHCTL"),
		"/opt/homebrew/bin/wifisnitchctl",
		"/usr/local/bin/wifisnitchctl",
		trim(shell("command -v wifisnitchctl")),
	}

	for _, path in ipairs(candidates) do
		if path and path ~= "" then
			return path
		end
	end

	return "wifisnitchctl"
end

local wifisnitchctl = resolve_wifisnitchctl()

local function read_vpn_status()
	local handle = io.popen(wifisnitchctl .. " field network.primary_interface_is_tunnel --format=lines 2>/dev/null")
	if not handle then
		return {
			icon = "󰌾",
			label = "VPN Off",
			color = "#6e738d",
		}
	end

	local output = handle:read("*a") or ""
	handle:close()

	local vpn_connected = false

	for line in output:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		if key == "network.primary_interface_is_tunnel" then
			vpn_connected = trim(value) == "true"
			break
		end
	end

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

do
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
end
