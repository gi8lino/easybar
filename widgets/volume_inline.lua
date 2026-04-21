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

local function text_for_state(state)
	if state.muted then
		return "􀊣"
	end
	return tostring(state.volume) .. "%"
end

local function refresh(expanded)
	local state = get_audio_state()

	easybar.set("volume_inline_label", {
		label = {
			string = text_for_state(state),
			color = "#8aadf4",
		},
	})

	easybar.set("volume_inline_slider", {
		drawing = expanded,
		value = state.muted and 0 or state.volume,
	})
end

easybar.add(easybar.kind.row, "volume_inline", {
	position = "right",
	order = 52,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	spacing = 8,
})

easybar.add(easybar.kind.item, "volume_inline_label", {
	parent = "volume_inline",
})

easybar.add(easybar.kind.slider, "volume_inline_slider", {
	parent = "volume_inline",
	min = 0,
	max = 100,
	step = 1,
	width = 120,
	drawing = false,
})

local expanded = false

easybar.subscribe("volume_inline", { easybar.events.volume_change, easybar.events.forced }, function()
	refresh(expanded)
end)

easybar.subscribe("volume_inline", easybar.events.mouse.entered, function()
	expanded = true
	refresh(true)
end)

easybar.subscribe("volume_inline", easybar.events.mouse.exited, function()
	expanded = false
	refresh(false)
end)

easybar.subscribe("volume_inline", easybar.events.mouse.scrolled, function(event)
	local direction = event.direction
	local delta = direction == easybar.events.mouse.up_scroll and 5 or -5
	set_volume(get_audio_state().volume + delta)
	refresh(true)
end)

easybar.subscribe("volume_inline_slider", easybar.events.slider.preview, function(event)
	easybar.set("volume_inline_slider", {
		value = tonumber(event.value) or get_audio_state().volume,
	})
end)

easybar.subscribe("volume_inline_slider", easybar.events.slider.changed, function(event)
	set_volume(event.value)
	refresh(true)
end)

refresh(false)
