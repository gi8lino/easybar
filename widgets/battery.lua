local function read_battery()
	local handle = io.popen("pmset -g batt 2>/dev/null")
	if not handle then
		return {
			icon = "!",
			text = "?",
			color = "#8bd5ca",
			show_label = false,
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
		show_label = false,
	}
end

local function render(state)
	return {
		icon = state.icon or "",
		text = state.show_label and (state.label or "") or "",
		color = state.color or "#8bd5ca",
	}
end

return {
	id = "battery",
	position = "right",
	order = 20,
	icon = "",
	text = "",
	color = "",

	subscribe = {
		"init",
		"power_source_change",
		"system_woke",
		"mouse.entered",
		"mouse.exited",
	},

	on_event = function(event, _)
		if event == "init" or event == "power_source_change" or event == "system_woke" then
			local state = read_battery()
			return render(state)
		end

		if event == "mouse.entered" then
			local state = read_battery()
			state.show_label = true
			return render(state)
		end

		if event == "mouse.exited" then
			local state = read_battery()
			state.show_label = false
			return render(state)
		end
	end,
}
