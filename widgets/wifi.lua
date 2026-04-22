local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/config/easybar/?.lua"

local secrets = require("secrets")

local state = {
	interface_name = nil,
	primary_interface_is_tunnel = false,
}

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shell(command)
	local pipe = io.popen(command .. " 2>/dev/null")
	if not pipe then
		easybar.log("error", "shell popen failed")
		return ""
	end

	local output = pipe:read("*a") or ""
	pipe:close()

	return output
end

local function quote(s)
	return string.format("%q", s or "")
end

local function apply_event(event)
	if event == nil or type(event.network) ~= "table" then
		return
	end

	if event.network.interface_name ~= nil then
		state.interface_name = trim(event.network.interface_name)
		if state.interface_name == "" then
			state.interface_name = nil
		end
	end

	if type(event.network.primary_interface_is_tunnel) == "boolean" then
		state.primary_interface_is_tunnel = event.network.primary_interface_is_tunnel
	end
end

local function get_wifi_status()
	local interface_name = state.interface_name

	if interface_name ~= nil and interface_name ~= "" then
		return interface_name, true
	end

	return "", false
end

local function get_vpn_status()
	return state.primary_interface_is_tunnel
end

local function toggle_vpn()
	local vpn_name = secrets.vpn_name or ""
	if vpn_name == "" then
		return
	end

	local name = quote(vpn_name)
	local status = trim(shell("scutil --nc status " .. name)):lower()

	if status:match("^connected") or status:match("^connecting") or status:match("^on demand") then
		shell("scutil --nc stop " .. name)
	else
		shell("scutil --nc start " .. name)
	end
end

local function refresh(show_label)
	local interface_name, wifi_connected = get_wifi_status()
	local vpn_connected = get_vpn_status()

	local wifi_icon = "􀙇"
	local wifi_label = ""
	local wifi_color = "#ff9f0a"

	if not wifi_connected then
		wifi_icon = "􀙈"
		wifi_label = "Not Connected"
		wifi_color = "#ff4f8b"
	else
		wifi_label = interface_name
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
			string = "󰦝 ",
			color = "#30d158",
			font = { size = 14 },
		},
		label = {
			string = "",
		},
	})
end

easybar.add(easybar.kind.row, "wifi_vpn", {
	position = "right",
	order = 25,
	spacing = 15,
})

easybar.add(easybar.kind.item, "wifi_vpn_wifi", {
	parent = "wifi_vpn",
})

easybar.add(easybar.kind.item, "wifi_vpn_vpn", {
	parent = "wifi_vpn",
	drawing = false,
})

local show_label = false

easybar.subscribe(
	"wifi_vpn",
	{ easybar.events.wifi_change, easybar.events.network_change, easybar.events.system_woke, easybar.events.forced },
	function(event)
		apply_event(event)
		refresh(show_label)
	end
)

easybar.subscribe("wifi_vpn", easybar.events.mouse.entered, function(event)
	show_label = true
	refresh(true)
end)

easybar.subscribe("wifi_vpn", easybar.events.mouse.exited, function(event)
	show_label = false
	refresh(false)
end)

easybar.subscribe("wifi_vpn", easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == easybar.events.mouse.left_button then
		toggle_vpn()
		refresh(show_label)
	end
end)

refresh(show_label)
