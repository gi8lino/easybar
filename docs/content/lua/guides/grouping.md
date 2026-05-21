# Grouping

Use `group` when multiple child nodes should share one visual container.

For terminology such as node, handle, and popup owner, see [Conventions](../conventions.md).

A group is useful when you want:

- one background
- one border
- one padding box
- shared spacing
- shared popup ownership
- parent-level interaction around multiple child items

## Basic group

```lua
local vpn = easybar.add(easybar.kind.group, "vpn", {
    position = "right",
    order = 40,
    spacing = 6,
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

## Styled group

```lua
local vpn = easybar.add(easybar.kind.group, "vpn", {
    position = "right",
    order = 40,
    spacing = 6,
    background = {
        color = "#202020",
        border_color = "#4a4a4a",
        border_width = 1,
        corner_radius = 8,
    },
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

## Interaction

Subscribe on child handles when each child should behave independently:

```lua
vpn_main:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle main toggle
    end
end)

vpn_mode:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle secondary action
    end
end)
```

Subscribe on the group handle only when the whole grouped widget should behave like one click target.

## Related pages

- [Style Popups And Groups](style-popups-and-groups.md)
- [Popups](popups.md)
- [Properties](../reference/properties.md)
