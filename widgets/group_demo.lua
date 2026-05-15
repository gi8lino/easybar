local hovered = false
local enabled = false

local group
local icon
local label

local function render()
	group:set({
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

	icon:set({
		icon = {
			string = enabled and "󰄬" or "󰄱",
			color = enabled and "#8aadf4" or "#6e738d",
		},
	})

	label:set({
		label = {
			string = hovered and "Group Hover" or "Group",
			color = "#cad3f5",
		},
	})
end

group = easybar.add(easybar.kind.group, "group_demo", {
	position = "right",
	order = 5,
	spacing = 6,
	popup = {
		drawing = false,
	},
})

icon = easybar.add(easybar.kind.item, "group_demo_icon", {
	parent = group.name,
	icon = {
		string = "󰄱",
	},
})

label = easybar.add(easybar.kind.item, "group_demo_label", {
	parent = group.name,
	label = {
		string = "Group",
	},
})

easybar.add(easybar.kind.item, "group_demo_popup", {
	position = "popup." .. group.name,
	label = {
		string = "Group popup",
	},
})

group:subscribe(easybar.events.mouse.entered, function()
	hovered = true
	group:set({
		popup = { drawing = true },
	})
	render()
end)

group:subscribe(easybar.events.mouse.exited, function()
	hovered = false
	group:set({
		popup = { drawing = false },
	})
	render()
end)

group:subscribe(easybar.events.mouse.clicked, function()
	enabled = not enabled
	render()
end)

render()
