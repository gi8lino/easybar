local enabled = false
local toggle

local function render()
	toggle:set({
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

toggle = easybar.add(easybar.kind.item, "toggle_test", {
	position = "right",
	order = 1,
})

toggle:subscribe(easybar.events.forced, function()
	render()
end)

toggle:subscribe(easybar.events.mouse.clicked, function()
	enabled = not enabled
	render()
end)

render()
