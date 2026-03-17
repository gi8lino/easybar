# EasyBar Lua widgets

EasyBar Lua widgets are item-based.

You do not return widget trees.
You create items, style them, and update them by id.

## API

### `easybar.add(kind, id, props)`

Creates one item.

Kinds:

- `item`
- `row`
- `column`
- `group`
- `slider`
- `progress`
- `progress_slider`
- `sparkline`

Example:

```lua
easybar.add("item", "clock", {
	position = "right",
	order = 10,
	icon = {
		string = "🕒",
	},
	label = {
		string = "00:00",
	},
})
```

---

### `easybar.set(id, props)`

Updates one item.

```lua
easybar.set("clock", {
	label = {
		string = os.date("%H:%M"),
	},
})
```

---

### `easybar.animate(id, props[, options])`

Small UX helper.

Use it when a change should feel intentional.
EasyBar already animates visible UI state changes in SwiftUI, so this updates through the same path as `set(...)`.

```lua
easybar.animate("calendar", {
	popup = {
		drawing = true,
	},
})
```

You can still pass an options table for readability:

```lua
easybar.animate("volume", {
	label = {
		string = "75%",
	},
}, {
	duration = 0.20,
})
```

---

### `easybar.remove(id)`

Removes one item and its children.

```lua
easybar.remove("clock")
```

---

### `easybar.get(id)`

Returns the current property table.

```lua
local props = easybar.get("clock")
```

---

### `easybar.default(props)`

Sets defaults for future `easybar.add(...)` calls.

Useful for shared padding, colors, or background.

```lua
easybar.default({
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	label = {
		color = "#cad3f5",
	},
})
```

Then later:

```lua
easybar.add("item", "clock", {
	position = "right",
	order = 10,
	label = {
		string = "--:--",
	},
})
```

The item inherits the defaults and then applies its own values on top.

---

### `easybar.clear_defaults()`

Clears all `easybar.default(...)` values.

```lua
easybar.clear_defaults()
```

---

### `easybar.subscribe(id, events, handler)`

Subscribes one item to one or more events.

```lua
easybar.subscribe("clock", { "minute_tick", "forced" }, function(env)
	easybar.set("clock", {
		label = {
			string = os.date("%H:%M"),
		},
	})
end)
```

`env` contains:

- `env.NAME` item id
- `env.SENDER` event name
- `env.INFO` event payload table

---

### `easybar.exec(command, callback)`

Runs one shell command.

```lua
local value = easybar.exec("date +%H:%M")

easybar.exec("date +%H:%M", function(output)
	easybar.set("clock", {
		label = {
			string = output,
		},
	})
end)
```

---

## Properties

## Basic

- `position = "left" | "center" | "right"`
- `order = number`
- `drawing = true | false`
- `width = number`
- `height = number`
- `y_offset = number`
- `update_freq = seconds`

## Text

### `icon`

- `icon.string`
- `icon.color`
- `icon.font.size`
- `icon.padding_right`

### `label`

You can use a string:

```lua
label = "Hello"
```

Or a table:

```lua
label = {
	string = "Hello",
	color = "#ffffff",
	font = {
		size = 13,
	},
}
```

## Background

```lua
background = {
	color = "#1a1a1a",
	border_color = "#333333",
	border_width = 1,
	corner_radius = 8,
	padding_left = 8,
	padding_right = 8,
	padding_top = 4,
	padding_bottom = 4,
}
```

## Value widgets

For `slider`, `progress`, `progress_slider`, `sparkline`:

- `value`
- `min`
- `max`
- `step`
- `values`
- `line_width`

---

## Children

Use `parent` for normal children.

```lua
easybar.add("row", "weather", {
	position = "right",
	order = 20,
	spacing = 8,
})

easybar.add("item", "weather_icon", {
	parent = "weather",
	icon = { string = "☀️" },
})

easybar.add("item", "weather_label", {
	parent = "weather",
	label = "20°",
})
```

---

## Popups

Use `popup = { ... }` on the anchor item.

Use `position = "popup.<anchor_id>"` for popup items.

```lua
easybar.add("item", "calendar", {
	position = "right",
	order = 30,
	icon = { string = "🗓" },
	label = "Today",
	popup = {
		drawing = false,
		background = {
			color = "#1e2030",
			border_color = "#494d64",
			border_width = 1,
			corner_radius = 10,
		},
		padding_left = 12,
		padding_right = 12,
		padding_top = 12,
		padding_bottom = 12,
		spacing = 8,
	},
})

easybar.add("item", "calendar_event_1", {
	position = "popup.calendar",
	label = "09:00 Standup",
})

easybar.subscribe("calendar", "mouse.entered", function()
	easybar.animate("calendar", {
		popup = { drawing = true },
	})
end)

easybar.subscribe("calendar", "mouse.exited", function()
	easybar.animate("calendar", {
		popup = { drawing = false },
	})
end)
```

---

## Routine updates

Use `update_freq`.

Subscribe to `"routine"`.

```lua
easybar.add("item", "clock", {
	position = "right",
	order = 10,
	update_freq = 30,
})

easybar.subscribe("clock", { "routine", "forced" }, function()
	easybar.set("clock", {
		label = os.date("%H:%M"),
	})
end)
```

---

## Clicks

Use `click_script` for simple shell actions.

```lua
easybar.add("item", "calendar", {
	position = "right",
	order = 30,
	click_script = "open -a Calendar",
})
```

You can also subscribe to mouse events:

- `mouse.entered`
- `mouse.exited`
- `mouse.clicked`
- `mouse.scrolled`

Example:

```lua
easybar.subscribe("calendar", "mouse.clicked", function(env)
	print(env.NAME, env.SENDER)
end)
```

For scroll events:

- `env.INFO.direction` is `"up"` or `"down"`

For slider events:

- `slider.preview`
- `slider.changed`

The value is in:

- `env.INFO.value`

---

## Recommended pattern

Use defaults first, then add items.

```lua
easybar.default({
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
	label = {
		color = "#cad3f5",
	},
})

easybar.add("item", "clock", {
	position = "right",
	order = 10,
	update_freq = 30,
	icon = {
		string = "🕒",
	},
	label = {
		string = "--:--",
	},
})

easybar.subscribe("clock", { "routine", "forced" }, function()
	easybar.set("clock", {
		label = {
			string = os.date("%H:%M"),
		},
	})
end)
```

---

## Example

```lua
easybar.default({
	background = {
		padding_left = 8,
		padding_right = 8,
		padding_top = 4,
		padding_bottom = 4,
	},
})

easybar.add("item", "clock", {
	position = "right",
	order = 10,
	update_freq = 30,
	icon = {
		string = "🕒",
	},
	label = {
		string = "--:--",
		color = "#ffffff",
	},
})

easybar.subscribe("clock", { "routine", "forced" }, function()
	easybar.animate("clock", {
		label = {
			string = os.date("%H:%M"),
		},
	})
end)
```

---

## Recommended style

For most widgets:

1. `easybar.default(...)` for shared styling
2. `easybar.add(...)`
3. `easybar.subscribe(...)`
4. update with `easybar.set(...)` or `easybar.animate(...)`

Keep widget ids stable.
Use `row` for grouped items.
Use `popup.<id>` for popup content.
Use `update_freq` + `routine` for polling.
