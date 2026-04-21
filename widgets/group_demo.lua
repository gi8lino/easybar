local hovered = false
local enabled = false

local function render()
	easybar.set("group_demo", {
		background = {
			color = hovered and "#2c2e45" or "#202020",
			border_color = enabled and "#8aadf4" or "#4a4a4a",
			border_width = 1,
			corner_radius = 8,
			padding_left = 8,
			padding_right = 8,
			padding_top = 4,
			padding_bottom = 4,
		},
	})

	easybar.set("group_demo_icon", {
		icon = {
			string = enabled and "󰄬" or "󰄱",
			color = enabled and "#8aadf4" or "#6e738d",
		},
	})

	easybar.set("group_demo_label", {
		label = {
			string = hovered and "Group Hover" or "Group",
			color = "#cad3f5",
		},
	})
end

easybar.add(easybar.kind.group, "group_demo", {
	position = "right",
	order = 5,
	spacing = 6,
	popup = {
		drawing = false,
	},
})

easybar.add(easybar.kind.item, "group_demo_icon", {
	parent = "group_demo",
	icon = {
		string = "󰄱",
	},
})

easybar.add(easybar.kind.item, "group_demo_label", {
	parent = "group_demo",
	label = {
		string = "Group",
	},
})

easybar.add(easybar.kind.item, "group_demo_popup", {
	position = "popup.group_demo",
	label = {
		string = "Group popup",
	},
})

easybar.subscribe("group_demo", easybar.events.mouse.entered, function()
	hovered = true
	easybar.set("group_demo", {
		popup = { drawing = true },
	})
	render()
end)

easybar.subscribe("group_demo", easybar.events.mouse.exited, function()
	hovered = false
	easybar.set("group_demo", {
		popup = { drawing = false },
	})
	render()
end)

easybar.subscribe("group_demo", easybar.events.mouse.clicked, function()
	enabled = not enabled
	render()
end)

render()
