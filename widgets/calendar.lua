local function trim(s)
	return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function first_event()
	local delimiter = "___DELIMITER___"
	local command = "icalBuddy -nc -nrd -eed -iep datetime,title -b '' -ps '|"
		.. delimiter
		.. "|' eventsToday+1 2>/dev/null"

	local handle = io.popen(command)
	if not handle then
		return "No events"
	end

	local output = handle:read("*a") or ""
	handle:close()

	output = trim(output)
	if output == "" then
		return "No events"
	end

	local firstLine = output:match("([^\n]+)") or ""
	local time, title = firstLine:match("^(.-)" .. delimiter .. "(.-)$")

	time = trim(time or "")
	title = trim(title or "")

	if time == "" and title == "" then
		return "No events"
	end

	if title == "" then
		return time
	end

	if time == "" then
		return title
	end

	return time .. " " .. title
end

return {
	id = "calendar_ical",
	position = "right",
	order = 79,
	icon = "􀉉",
	text = "",
	color = "#eed49f",

	subscribe = {
		"init",
		"system_woke",
		"mouse.entered",
		"mouse.exited",
		"mouse.clicked",
	},

	on_event = function(event, payload)
		if event == "init" or event == "system_woke" then
			return {
				icon = "􀉉",
				text = "",
				color = "#eed49f",
			}
		end

		if event == "mouse.entered" then
			return {
				icon = "􀉉",
				text = first_event(),
				color = "#eed49f",
			}
		end

		if event == "mouse.exited" then
			return {
				icon = "􀉉",
				text = "",
				color = "#eed49f",
			}
		end

		if event == "mouse.clicked" and payload and payload.button == "left" then
			os.execute("open -a Calendar")
			return {
				icon = "􀉉",
				text = first_event(),
				color = "#eed49f",
			}
		end
	end,
}
