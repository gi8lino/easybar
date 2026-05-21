# Style Popups And Groups

Groups and popups are the two main tools for making Lua widgets feel like composed UI instead of isolated text labels.

## When to use a group

Use a group when multiple child nodes should feel like one visual unit.

Good reasons:

- shared background
- shared border
- shared padding
- shared spacing
- one outer click target or popup owner

Example:

```lua
local vpn = easybar.add(easybar.kind.group, "vpn_group", {
    position = "right",
    order = 40,
    spacing = 6,
    background = {
        color = "#202020",
        border_color = "#4a4a4a",
        border_width = 1,
        corner_radius = 8,
    },
    padding_x = 10,
    padding_y = 6,
})

easybar.add(easybar.kind.item, "vpn_icon", {
    parent = vpn.name,
    icon = "󰖂",
})

easybar.add(easybar.kind.item, "vpn_label", {
    parent = vpn.name,
    label = "Active",
})
```

## When to use a popup

Use a popup when the widget should reveal extra content on hover or click without permanently occupying bar space.

Example:

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 50,
    label = "Today",
    popup = {
        drawing = false,
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

easybar.add(easybar.kind.item, "calendar_popup_label", {
    position = "popup." .. calendar.name,
    label = "Next event: 14:00",
})
```

## Show and hide the popup

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

## Practical styling rules

- Put shared background and padding on the group when the whole block should feel unified.
- Put inner decoration on child items when individual rows inside the popup need their own emphasis.
- Keep `spacing` on the parent container so layout intent is obvious.
- Use explicit `padding_x` and `padding_y` before dropping down to edge-by-edge padding.

## Good combinations

- group + popup: one compact bar widget that opens a richer surface
- item + popup: one simple trigger with detail on hover
- group only: a permanent multi-part widget such as icon + label + badge

## Related pages

- [Grouping](grouping.md)
- [Popups](popups.md)
- [Properties](../reference/properties.md)
