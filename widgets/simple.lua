local enabled = false

local function render()
	easybar.set("toggle_test", {
		icon = {
			string = enabled and "󰄬" or "󰄱",
			color = enabled and "#30d158" or "#ff453a",
		},
		label = {
			string = enabled and "ON" or "OFF",
			color = enabled and "#30d158" or "#ff453a",
		},
	})
end

easybar.add("item", "toggle_test", {
	position = "right",
	order = 1,
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
		color = "#1a1a1a",
		border_color = "#333333",
		border_width = 1,
		corner_radius = 8,
	},
})

easybar.subscribe("toggle_test", easybar.events.forced, function()
	render()
end)

easybar.subscribe("toggle_test", easybar.events.mouse.clicked, function()
	enabled = not enabled
	render()
end)

render()
