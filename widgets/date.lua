return {
	id = "calendar_date",
	position = "right",
	order = 80,
	icon = "",
	text = "",
	color = "#cad3f5",

	subscribe = { "init", "minute_tick", "system_woke", "mouse.clicked" },

	on_event = function(event, payload)
		if event == "init" or event == "minute_tick" or event == "system_woke" then
			return {
				icon = "",
				text = os.date("%a %d. %b"),
				color = "#cad3f5",
			}
		end

		if event == "mouse.clicked" and payload and payload.button == "left" then
			os.execute("open -a Calendar")
			return {
				icon = "",
				text = os.date("%a %d. %b"),
				color = "#cad3f5",
			}
		end
	end,
}
