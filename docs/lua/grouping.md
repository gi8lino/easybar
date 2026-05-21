# Grouping

Use `group` when multiple child nodes should share:

- one background
- one border
- one padding box
- one popup owner

## Group example

```lua
local vpn = easybar.add(easybar.kind.group, "vpn", {
    position = "right",
    order = 40,
    background = {
        color = "#202020",
        border_color = "#4a4a4a",
        border_width = 1,
        corner_radius = 8,
    },
    spacing = 6,
})

local vpn_main = easybar.add(easybar.kind.item, "vpn_main", {
    parent = vpn.name,
    icon = {
        string = "󰖂",
    },
})

local vpn_mode = easybar.add(easybar.kind.item, "vpn_mode", {
    parent = vpn.name,
    icon = {
        string = "󰌾",
    },
})
```

## Important rules

- The group is the shared styled container.
- Each child item can still be its own interactive surface.
- If each child should react independently to clicks, subscribe on the child handles, not only on the group handle.
- Use a group-level mouse subscription only when the whole grouped widget should behave like one single click target.

## Independent child clicks

```lua
vpn_main:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle main toggle
    end
end)

vpn_mode:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle secondary toggle
    end
end)
```

## Minimal group

```lua
local vpn = easybar.add(easybar.kind.group, "vpn", {
    position = "right",
    order = 40,
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
