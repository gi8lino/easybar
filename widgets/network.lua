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

local function read_ssid()
	local handle = io.popen(wifisnitchctl .. " field wifi.ssid --format=lines 2>/dev/null")
	if not handle then
		return "offline"
	end

	local output = handle:read("*a") or ""
	handle:close()

	for line in output:gmatch("[^\r\n]+") do
		local key, value = line:match("^([^=]+)=(.*)$")
		if key == "wifi.ssid" then
			value = trim(value)
			if value ~= "" then
				return value
			end
		end
	end

	return "offline"
end

easybar.add(easybar.kind.item, "network", {
	position = "right",
	order = 35,
	interval = 30,
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
	on_interval = function()
		easybar.set("network", {
			label = {
				string = read_ssid(),
			},
		})
	end,
})

easybar.subscribe("network", {
	easybar.events.network_change,
	easybar.events.wifi_change,
	easybar.events.system_woke,
	easybar.events.forced,
}, function()
	easybar.set("network", {
		label = {
			string = read_ssid(),
		},
	})
end)

easybar.set("network", {
	label = {
		string = read_ssid(),
	},
})
