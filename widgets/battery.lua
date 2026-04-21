local function read_battery()
	local handle = io.popen("pmset -g batt 2>/dev/null")
	if not handle then
		return {
			icon = "!",
			label = "?",
			color = "#8bd5ca",
		}
	end

	local batt_info = handle:read("*a") or ""
	handle:close()

	local charge = tonumber((batt_info:match("(%d+)%%"))) or 0
	local charging = batt_info:find("AC Power") ~= nil

	local icon = "!"
	local color = "#8bd5ca"

	if charging then
		if charge == 100 then
			icon, color = "󰂅", "#8bd5ca"
		elseif charge >= 90 then
			icon, color = "󰂋", "#8bd5ca"
		elseif charge >= 80 then
			icon, color = "󰂊", "#8bd5ca"
		elseif charge >= 70 then
			icon, color = "󰢞", "#8bd5ca"
		elseif charge >= 60 then
			icon, color = "󰂉", "#eed49f"
		elseif charge >= 50 then
			icon, color = "󰢝", "#eed49f"
		elseif charge >= 40 then
			icon, color = "󰂈", "#f5a97f"
		elseif charge >= 30 then
			icon, color = "󰂇", "#f5a97f"
		elseif charge >= 20 then
			icon, color = "󰂆", "#ed8796"
		elseif charge >= 10 then
			icon, color = "󰢜", "#ed8796"
		else
			icon, color = "󰂃", "#ed8796"
		end
	else
		if charge == 100 then
			icon, color = "󰁹", "#8bd5ca"
		elseif charge >= 90 then
			icon, color = "󰂂", "#8bd5ca"
		elseif charge >= 80 then
			icon, color = "󰂁", "#8bd5ca"
		elseif charge >= 70 then
			icon, color = "󰂀", "#8bd5ca"
		elseif charge >= 60 then
			icon, color = "󰁿", "#eed49f"
		elseif charge >= 50 then
			icon, color = "󰁾", "#eed49f"
		elseif charge >= 40 then
			icon, color = "󰁽", "#f5a97f"
		elseif charge >= 30 then
			icon, color = "󰁼", "#f5a97f"
		elseif charge >= 20 then
			icon, color = "󰁻", "#ed8796"
		elseif charge >= 10 then
			icon, color = "󰁺", "#ed8796"
		else
			icon, color = "󰂃", "#ed8796"
		end
	end

	return {
		icon = icon,
		label = tostring(charge) .. "%",
		color = color,
	}
end

local function apply(show_label)
	local state = read_battery()

	easybar.set("battery", {
		icon = {
			string = state.icon,
			color = state.color,
			font = { size = 16 },
		},
		label = {
			string = show_label and state.label or "",
			color = state.color,
		},
	})
end

easybar.add(easybar.kind.item, "battery", {
	position = "right",
	order = 20,
})

easybar.subscribe(
	"battery",
	{ easybar.events.forced, easybar.events.power_source_change, easybar.events.system_woke },
	function()
		apply(false)
	end
)

easybar.subscribe("battery", easybar.events.mouse.entered, function()
	apply(true)
end)

easybar.subscribe("battery", easybar.events.mouse.exited, function()
	apply(false)
end)

apply(false)
