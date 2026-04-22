local state = {
	vpn_connected = false,
}

local function apply_event(event)
	if event == nil or type(event.network) ~= "table" then
		return
	end

	local value = event.network.primary_interface_is_tunnel
	if type(value) == "boolean" then
		state.vpn_connected = value
	end
end

local function current_state()
	if state.vpn_connected then
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

local function render()
	local status = current_state()

	easybar.set("vpn", {
		icon = {
			string = status.icon,
			color = status.color,
		},
		label = {
			string = status.label,
			color = status.color,
		},
	})
end

easybar.add(easybar.kind.item, "vpn", {
	position = "right",
	order = 41,
})

easybar.subscribe(
	"vpn",
	{ easybar.events.network_change, easybar.events.wifi_change, easybar.events.system_woke, easybar.events.forced },
	function(event)
		apply_event(event)
		render()
	end
)

render()
