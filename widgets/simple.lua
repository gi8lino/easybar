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

easybar.add(easybar.kind.item, "toggle_test", {
	position = "right",
	order = 1,
})

easybar.subscribe("toggle_test", easybar.events.forced, function()
	render()
end)

easybar.subscribe("toggle_test", easybar.events.mouse.clicked, function()
	enabled = not enabled
	render()
end)

render()
