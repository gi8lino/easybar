local function get_audio_state()
	local handle = io.popen(
		"osascript -e 'set s to get volume settings' -e 'return (output volume of s as string) & \",\" & (output muted of s as string)' 2>/dev/null"
	)

	if not handle then
		return { volume = 0, muted = false }
	end

	local output = handle:read("*a") or ""
	handle:close()

	local volume_string, muted_string = output:match("^%s*(.-)%s*,%s*(.-)%s*$")

	return {
		volume = math.max(0, math.min(100, tonumber(volume_string) or 0)),
		muted = muted_string == "true",
	}
end

local function set_volume(value)
	value = math.max(0, math.min(100, tonumber(value) or 0))
	os.execute("osascript -e 'set volume output volume " .. value .. "'")
	return value
end

local function icon_for_state(state)
	if state.muted or state.volume <= 0 then
		return "󰖁"
	elseif state.volume < 35 then
		return "󰕿"
	elseif state.volume < 70 then
		return "󰖀"
	else
		return "󰕾"
	end
end

local function text_for_state(state)
	if state.muted then
		return "Muted"
	end
	return tostring(state.volume) .. "%"
end

local function refresh()
	local state = get_audio_state()

	easybar.set("volume_progress_anchor", {
		icon = {
			string = icon_for_state(state),
			color = "#8aadf4",
		},
		label = {
			string = text_for_state(state),
			color = "#8aadf4",
		},
	})

	easybar.set("volume_progress_bar", {
		value = state.muted and 0 or state.volume,
	})

	easybar.set("volume_progress_popup_label", {
		icon = {
			string = icon_for_state(state),
			color = "#cad3f5",
		},
		label = {
			string = "Volume " .. text_for_state(state),
			color = "#cad3f5",
		},
	})

	easybar.set("volume_progress_popup_slider", {
		value = state.muted and 0 or state.volume,
	})
end

easybar.add("row", "volume_progress", {
	position = "right",
	order = 50,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	spacing = 8,
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

easybar.add("item", "volume_progress_anchor", {
	parent = "volume_progress",
})

easybar.add("progress", "volume_progress_bar", {
	parent = "volume_progress",
	min = 0,
	max = 100,
	value = 0,
	width = 64,
	height = 8,
	color = "#8aadf4",
})

easybar.add("item", "volume_progress_popup_label", {
	position = "popup.volume_progress",
})

easybar.add("slider", "volume_progress_popup_slider", {
	position = "popup.volume_progress",
	min = 0,
	max = 100,
	step = 1,
	width = 140,
})

easybar.subscribe("volume_progress", { easybar.events.volume_change, easybar.events.forced }, refresh)

easybar.subscribe("volume_progress", easybar.events.mouse.entered, function()
	easybar.set("volume_progress", {
		popup = { drawing = true },
	})
	refresh()
end)

easybar.subscribe("volume_progress", easybar.events.mouse.exited, function()
	easybar.set("volume_progress", {
		popup = { drawing = false },
	})
end)

easybar.subscribe("volume_progress", easybar.events.mouse.scrolled, function(event)
	local direction = event.direction
	local delta = direction == "up" and 5 or -5
	set_volume(get_audio_state().volume + delta)
	refresh()
end)

easybar.subscribe("volume_progress_popup_slider", easybar.events.slider.preview, function(event)
	easybar.set("volume_progress_popup_slider", {
		value = tonumber(event.value) or get_audio_state().volume,
	})
end)

easybar.subscribe("volume_progress_popup_slider", easybar.events.slider.changed, function(event)
	set_volume(event.value)
	refresh()
end)

refresh()
