local popup_padding_x = 14
local popup_padding_y = 10
local popup_spacing = 8
local popup_corner_radius = 10
local popup_background = "#1e2030"
local popup_border = "#494d64"
local popup_border_width = 1

local anchor_clock_color = "#cad3f5"
local anchor_date_color = "#a6adc8"
local popup_date_color = "#eed49f"
local popup_separator_color = "#6e738d"
local popup_title_color = "#cad3f5"

local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function next_event()
	local delimiter = "___DELIMITER___"
	local command = "icalBuddy -nc -nrd -eed -iep datetime,title -b '' -ps '|"
		.. delimiter
		.. "|' eventsToday+1 2>/dev/null"

	local handle = io.popen(command)
	if not handle then
		return "", "No events"
	end

	local output = handle:read("*a") or ""
	handle:close()

	output = trim(output)
	if output == "" then
		return "", "No events"
	end

	local line = output:match("([^\n]+)") or ""
	local title, datetime = line:match("^(.-)" .. delimiter .. "(.-)$")

	datetime = trim(datetime or "")
	title = trim(title or "")

	if datetime == "" and title == "" then
		return "", "No events"
	end

	local date_only = datetime:gsub("%s+at%s+%d%d?:%d%d.*$", "")
	date_only = trim(date_only)

	return date_only, title
end

local function build_widget()
	local event_date, event_title = next_event()

	return {
		id = "calendar",
		kind = "popup",
		position = "right",
		order = 90,
		icon = "",
		text = "",
		color = "",
		visible = true,

		paddingX = 8,
		paddingY = 4,
		spacing = 0,

		anchorChildren = {
			{
				id = "calendar_anchor",
				kind = "column",
				spacing = 0,
				children = {
					{
						id = "calendar_anchor_clock",
						kind = "item",
						text = os.date("%H:%M"),
						color = anchor_clock_color,
					},
					{
						id = "calendar_anchor_date",
						kind = "item",
						text = os.date("%a %d. %b"),
						color = anchor_date_color,
					},
				},
			},
		},

		children = {
			{
				id = "calendar_popup_row",
				kind = "row",
				spacing = popup_spacing,
				paddingX = popup_padding_x,
				paddingY = popup_padding_y,
				cornerRadius = popup_corner_radius,
				backgroundColor = popup_background,
				borderColor = popup_border,
				borderWidth = popup_border_width,

				children = {
					{
						id = "calendar_popup_date",
						kind = "item",
						text = event_date ~= "" and event_date or "No date",
						color = popup_date_color,
					},
					{
						id = "calendar_popup_separator",
						kind = "item",
						text = "|",
						color = popup_separator_color,
					},
					{
						id = "calendar_popup_title",
						kind = "item",
						text = event_title ~= "" and event_title or "No events",
						color = popup_title_color,
					},
				},
			},
		},
	}
end

return {
	id = "calendar",
	kind = "popup",
	position = "right",
	order = 90,

	subscribe = {
		"init",
		"minute_tick",
		"system_woke",
		"mouse.clicked",
	},

	on_event = function(event, payload)
		if event == "init" or event == "minute_tick" or event == "system_woke" then
			return build_widget()
		end

		if event == "mouse.clicked" and payload and payload.button == "left" then
			os.execute("open -a Calendar")
			return build_widget()
		end
	end,
}
