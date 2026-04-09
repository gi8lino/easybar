local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/config/easybar/?.lua"

local secrets = require("secrets")

local state = {
	wireguard_connected = false,
}

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function debug_shell(command)
	local pipe = io.popen(command .. " 2>&1")
	if not pipe then
		easybar.log("error", "debug shell popen failed", command)
		return ""
	end

	local output = pipe:read("*a") or ""
	pipe:close()

	easybar.log("info", "command", command, "output", trim(output))
	return output
end

local function quote(s)
	return string.format("%q", s or "")
end

local function dump_table(value, depth)
	depth = depth or 0

	if type(value) ~= "table" then
		return tostring(value)
	end

	if depth > 4 then
		return "{...}"
	end

	local parts = {}
	for k, v in pairs(value) do
		table.insert(parts, tostring(k) .. "=" .. dump_table(v, depth + 1))
	end

	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

local function log_event(prefix, event)
	easybar.log("info", prefix, dump_table(event))
end

local function to_boolean(value)
	if type(value) == "boolean" then
		return value
	end

	if type(value) == "string" then
		local normalized = trim(value):lower()

		if normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on" then
			return true
		end

		if normalized == "false" or normalized == "0" or normalized == "no" or normalized == "off" then
			return false
		end
	end

	if type(value) == "number" then
		return value ~= 0
	end

	return nil
end

local function get_wireguard_status()
	return state.wireguard_connected
end

local function status_label(wireguard_connected)
	if wireguard_connected then
		return "Active"
	end

	return "Inactive"
end

local function network_event_tunnel_value(event)
	if event == nil then
		return nil
	end

	if event.raw ~= nil and event.raw.primary_interface_is_tunnel ~= nil then
		return event.raw.primary_interface_is_tunnel
	end

	if event.primary_interface_is_tunnel ~= nil then
		return event.primary_interface_is_tunnel
	end

	return nil
end

local function apply_network_event(event)
	if event == nil then
		easybar.log("debug", "wireguard apply_network_event skipped nil event")
		return false
	end

	local raw_value = network_event_tunnel_value(event)
	local resolved = to_boolean(raw_value)

	if resolved == nil then
		easybar.log(
			"debug",
			"wireguard apply_network_event skipped missing tunnel flag",
			"type",
			type(raw_value),
			"value",
			tostring(raw_value)
		)
		return false
	end

	local changed = state.wireguard_connected ~= resolved
	state.wireguard_connected = resolved

	easybar.log(
		"info",
		"wireguard state updated from network event",
		"changed",
		tostring(changed),
		"type",
		type(raw_value),
		"value",
		tostring(raw_value),
		"resolved",
		tostring(resolved)
	)

	return changed
end

local function toggle_wireguard()
	local vpn_name = secrets.vpn_name or ""
	if vpn_name == "" then
		easybar.log("warn", "wireguard toggle skipped because secrets.vpn_name is empty")
		return
	end

	local name = quote(vpn_name)
	local status = trim(debug_shell("scutil --nc status " .. name)):lower()
	easybar.log("info", "vpn_name", vpn_name, "status", status)

	if status:match("^connected") or status:match("^connecting") or status:match("^on demand") then
		debug_shell("scutil --nc stop " .. name)
	else
		debug_shell("scutil --nc start " .. name)
	end
end

local function refresh()
	local wireguard_connected = get_wireguard_status()
	local logo_path = home .. "/.config/easybar/assets/wireguard.png"
	local logo_exists = io.open(logo_path, "rb") ~= nil

	if logo_exists then
		local handle = io.open(logo_path, "rb")
		if handle then
			handle:close()
		end
	end

	easybar.log("info", "wireguard refresh connected", tostring(wireguard_connected))

	easybar.set("wireguard", {
		background = {
			color = "#202020",
			border_color = "#4a4a4a",
		},
	})

	easybar.set("wireguard_icon", {
		icon = {
			string = logo_exists and "" or "WG",
			image = logo_exists and logo_path or nil,
			image_size = 16,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = wireguard_connected and 1.0 or 0.55,
	})

	easybar.set("wireguard_popup_label", {
		label = {
			string = status_label(wireguard_connected),
			color = "#cad3f5",
		},
	})
end

easybar.add("group", "wireguard", {
	position = "right",
	order = 2,
	background = {
		color = "#202020",
		border_color = "#4a4a4a",
		border_width = 1,
		corner_radius = 8,
		padding_left = 12,
		padding_right = 12,
		padding_top = 6,
		padding_bottom = 6,
	},
	spacing = 0,
	popup = {
		drawing = true,
	},
})

easybar.add("item", "wireguard_icon", {
	parent = "wireguard",
	icon = {
		string = "WG",
		image = home .. "/.config/easybar/assets/wireguard.png",
		image_size = 16,
		image_corner_radius = 0,
	},
	label = {
		string = "",
	},
})

easybar.add("item", "wireguard_popup_label", {
	position = "popup.wireguard",
	label = {
		string = "",
	},
})

easybar.subscribe("wireguard", {
	easybar.events.network_change,
	easybar.events.wifi_change,
	easybar.events.minute_tick,
	easybar.events.forced,
}, function(event)
	log_event("wireguard payload", event)
	apply_network_event(event)
	refresh()
end)

easybar.subscribe("wireguard", easybar.events.mouse.clicked, function(event)
	log_event("wireguard click payload", event)

	if event.button == nil or event.button == "left" then
		toggle_wireguard()
	end
end)

refresh()
