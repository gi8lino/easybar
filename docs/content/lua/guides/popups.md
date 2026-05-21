# Popups

Popups attach extra content to a bar node.

The parent widget controls whether the popup is visible. Popup child nodes use a `position` value of `popup.<parent-id>`.

## Minimal popup

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 30,
    label = "Today",
    popup = {
        drawing = false,
    },
})

easybar.add(easybar.kind.item, "calendar_popup_label", {
    position = "popup." .. calendar.name,
    label = "Next event: 14:00",
})
```

## Show on hover

```lua
calendar:subscribe(easybar.events.mouse.entered, function()
    calendar:set({
        popup = { drawing = true },
    })
end)

calendar:subscribe(easybar.events.mouse.exited, function()
    calendar:set({
        popup = { drawing = false },
    })
end)
```

## Popup styling

Popup content inherits native-like defaults when you do not override them:

- text color `#cdd6f4`
- background `#111111`
- border `#444444`
- corner radius `8`
- padding `8 x 6`
- margin `0 x 8`

Use the default popup styling when you want the built-in tooltip look.

Add explicit child background and padding when you want a more decorated inner surface.

```lua
local vpn = easybar.add(easybar.kind.item, "vpn", {
    position = "right",
    order = 40,
    popup = {
        drawing = true,
        padding_x = 10,
        padding_y = 8,
        background = {
            color = "#111111",
            border_color = "#444444",
            border_width = 1,
            corner_radius = 8,
        },
    },
})

easybar.add(easybar.kind.item, "vpn_popup_label", {
    position = "popup." .. vpn.name,
    padding_left = 12,
    padding_right = 12,
    padding_top = 8,
    padding_bottom = 8,
    background = {
        color = "#181818",
        border_color = "#555555",
        border_width = 1,
        corner_radius = 8,
    },
    label = "WireGuard active",
})
```
