# Properties

The bundled LuaLS stub marks the public property tables as exact, so unknown keys in `icon`, `label`, `background`, `popup`, and the top-level node props should surface as editor diagnostics.

## Basic properties

- `position`
- `order`
- `drawing`
- `parent`
- `width`
- `height`
- `interval`
- `on_interval`

## Icon

```lua
icon = {
    string = "🕒",
    color = "#ffffff",
    font = { size = 14 },
}
```

Image icon:

```lua
icon = {
    image = "/path/to/icon.png",
    image_size = 16,
    image_corner_radius = 0,
}
```

## Label

```lua
label = {
    string = "Hello",
    color = "#ffffff",
    font = { size = 13 },
}
```

Shorthand:

```lua
label = "Hello"
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
}
```

## Parent

Use `parent` to place child nodes inside a group or row.

```lua
local group = easybar.add(easybar.kind.group, "system", {
    position = "right",
})

easybar.add(easybar.kind.item, "system_label", {
    parent = group.name,
    label = "Ready",
})
```

## Popup position

Use `popup.<id>` as the position for popup child content.

```lua
easybar.add(easybar.kind.item, "calendar_popup_label", {
    position = "popup." .. calendar.name,
    label = "Next event: 14:00",
})
```
