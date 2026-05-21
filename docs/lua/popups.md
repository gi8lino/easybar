# Popups

Popup content inherits native-like defaults when you do not override them:

- text color `#cdd6f4`
- background `#111111`
- border `#444444` with width `1`
- corner radius `8`
- padding `8 x 6`
- margin `0 x 8`

That means a simple popup widget already renders close to the built-in popup look without extra popup styling.

## Popup owner

The popup container style comes from the widget's `popup = { ... }` table.

Popup child items do not automatically inherit the bar-root shell styling, so if you want an inner pill or "double-shell" look, style that child explicitly.

## Hover popup

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 30,
    popup = {
        drawing = false,
    },
})

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

## Minimal popup content

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 30,
    popup = {
        drawing = false,
    },
})

easybar.add(easybar.kind.item, "calendar_popup_label", {
    position = "popup." .. calendar.name,
    label = "Next event: 14:00",
})
```

## Explicit double-shell popup

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

Use the default popup styling when you want the built-in Wi-Fi tooltip look.
Add explicit child background and padding when you want a more decorated inner surface.
