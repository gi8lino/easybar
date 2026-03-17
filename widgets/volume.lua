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

local function refresh()
	local value = get_volume()

	easybar.set("volume", {
		icon = {
			string = icon_for_volume(value),
			color = "#8aadf4",
		},
		label = {
			string = tostring(value) .. "%",
			color = "#8aadf4",
		},
	})

	easybar.set("volume_popup_label", {
		icon = {
			string = "󰕾",
			color = "#cad3f5",
		},
		label = {
			string = "Volume " .. tostring(value) .. "%",
			color = "#cad3f5",
		},
	})

	easybar.set("volume_slider", {
		value = value,
	})
end

easybar.add("item", "volume", {
	position = "right",
	order = 45,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	popup = {
		drawing = false,
		background = {
			color = "#1e2030",
			border_color = "#494d64",
			border_width = 1,
			corner_radius = 10,
		},
		padding_left = 12,
		padding_right = 12,
		padding_top = 12,
		padding_bottom = 12,
		spacing = 8,
	},
})

easybar.add("item", "volume_popup_label", {
	position = "popup.volume",
})

easybar.add("slider", "volume_slider", {
	position = "popup.volume",
	min = 0,
	max = 100,
	step = 1,
	width = 140,
})

easybar.subscribe("volume", { "volume_change", "forced" }, refresh)

easybar.subscribe("volume", "mouse.entered", function()
	easybar.set("volume", {
		popup = { drawing = true },
	})
	refresh()
end)

easybar.subscribe("volume", "mouse.exited", function()
	easybar.set("volume", {
		popup = { drawing = false },
	})
end)

easybar.subscribe("volume", "mouse.scrolled", function(env)
	local delta = env.INFO.direction == "up" and 5 or -5
	set_volume(get_volume() + delta)
	refresh()
end)

easybar.subscribe("volume_slider", "slider.preview", function(env)
	easybar.set("volume_slider", {
		value = tonumber(env.INFO.value) or get_volume(),
	})
end)

easybar.subscribe("volume_slider", "slider.changed", function(env)
	set_volume(env.INFO.value)
	refresh()
end)
