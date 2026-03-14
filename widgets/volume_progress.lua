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
		id = "volume_progress",
		kind = "popup",
		position = "right",
		order = 50,

		icon = "",
		text = "",
		color = "#8aadf4",

		paddingX = 8,
		paddingY = 4,
		spacing = 6,

		anchorChildren = {
			{
				id = "volume_progress_anchor",
				kind = "row",
				spacing = 6,
				children = {
					{
						id = "volume_progress_icon",
						kind = "item",
						icon = icon_for_state(state),
						text = text_for_state(state),
						color = "#8aadf4",
					},
					{
						id = "volume_progress_bar",
						kind = "progress",
						min = 0,
						max = 100,
						value = state.muted and 0 or state.volume,
						color = "#8aadf4",
					},
				},
			},
		},

		children = {
			{
				id = "volume_progress_popup_column",
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
						id = "volume_progress_popup_label",
						kind = "item",
						icon = icon_for_state(state),
						text = "Volume " .. text_for_state(state),
						color = "#cad3f5",
					},
					{
						id = "volume_progress_popup_slider",
						kind = "slider",
						min = 0,
						max = 100,
						step = 1,
						value = state.muted and 0 or state.volume,
						color = "#8aadf4",
					},
				},
			},
		},
	}
end

return {
	id = "volume_progress",
	kind = "popup",
	position = "right",
	order = 50,

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
