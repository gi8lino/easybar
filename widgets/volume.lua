local function get_volume()
	local handle = io.popen("osascript -e 'output volume of (get volume settings)' 2>/dev/null")
	if not handle then
		return 0
	end

	local value = tonumber(handle:read("*a")) or 0
	handle:close()

	return math.max(0, math.min(100, value))
end

local function set_volume(value)
	value = math.max(0, math.min(100, tonumber(value) or 0))
	os.execute("osascript -e 'set volume output volume " .. value .. "'")
	return value
end

local function icon_for_volume(value)
	if value <= 0 then
		return "󰖁"
	elseif value < 35 then
		return "󰕿"
	elseif value < 70 then
		return "󰖀"
	else
		return "󰕾"
	end
end

local function build_widget()
	local value = get_volume()

	return {
		id = "volume",
		kind = "popup",
		position = "right",
		order = 45,

		icon = icon_for_volume(value),
		text = tostring(value) .. "%",
		color = "#8aadf4",

		paddingX = 8,
		paddingY = 4,
		spacing = 6,

		anchorChildren = {
			{
				id = "volume_anchor",
				kind = "item",
				icon = icon_for_volume(value),
				text = tostring(value) .. "%",
				color = "#8aadf4",
			},
		},

		children = {
			{
				id = "volume_popup_column",
				kind = "column",
				spacing = 8,
				paddingX = 12,
				paddingY = 12,
				cornerRadius = 10,
				backgroundColor = "#1e2030",
				borderColor = "#494d64",
				borderWidth = 1,

				children = {
					{
						id = "volume_popup_label",
						kind = "item",
						icon = "󰕾",
						text = "Volume " .. tostring(value) .. "%",
						color = "#cad3f5",
					},
					{
						id = "volume_slider",
						kind = "slider",
						min = 0,
						max = 100,
						step = 1,
						value = value,
						color = "#8aadf4",
					},
				},
			},
		},
	}
end

return {
	id = "volume",
	kind = "popup",
	position = "right",
	order = 45,

	subscribe = {
		"init",
		"volume_change",
		"mouse.scrolled",
		"slider.changed",
	},

	on_event = function(event, payload)
		if event == "init" or event == "volume_change" then
			return build_widget()
		end

		if event == "mouse.scrolled" and payload then
			local current = get_volume()
			local delta = payload.direction == "up" and 5 or -5
			set_volume(current + delta)
			return build_widget()
		end

		if event == "slider.changed" and payload and payload.value then
			set_volume(payload.value)
			return build_widget()
		end
	end,
}
