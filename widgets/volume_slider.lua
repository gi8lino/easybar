local function get_audio_state()
	local handle = io.popen(
		"osascript -e 'set s to get volume settings' -e 'return (output volume of s as string) & \",\" & (output muted of s as string)' 2>/dev/null"
	)

	if not handle then
		return { volume = 0, muted = false }
	end

	local output = handle:read("*a") or ""
	handle:close()

	local volumeString, mutedString = output:match("^%s*(.-)%s*,%s*(.-)%s*$")

	return {
		volume = math.max(0, math.min(100, tonumber(volumeString) or 0)),
		muted = mutedString == "true",
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

local function build_widget(state)
	state = state or get_audio_state()

	return {
		id = "volume_slider",
		kind = "row",
		position = "right",
		order = 51,

		spacing = 8,
		paddingX = 8,
		paddingY = 4,

		children = {
			{
				id = "volume_slider_label",
				kind = "item",
				icon = icon_for_state(state),
				text = text_for_state(state),
				color = "#8aadf4",
			},
			{
				id = "volume_slider_control",
				kind = "slider",
				min = 0,
				max = 100,
				step = 1,
				value = state.muted and 0 or state.volume,
				color = "#8aadf4",
			},
		},
	}
end

return {
	id = "volume_slider",
	kind = "row",
	position = "right",
	order = 51,

	subscribe = {
		"init",
		"volume_change",
		"mouse.scrolled",
		"slider.preview",
		"slider.changed",
	},

	on_event = function(event, payload)
		if event == "init" or event == "volume_change" then
			return build_widget(get_audio_state())
		end

		if event == "mouse.scrolled" and payload then
			local state = get_audio_state()
			local delta = payload.direction == "up" and 5 or -5
			local updated = set_volume(state.volume + delta)
			return build_widget({ volume = updated, muted = false })
		end

		if event == "slider.preview" and payload and payload.value then
			return build_widget({
				volume = tonumber(payload.value) or get_audio_state().volume,
				muted = false,
			})
		end

		if event == "slider.changed" and payload and payload.value then
			local updated = set_volume(payload.value)
			return build_widget({ volume = updated, muted = false })
		end
	end,
}
