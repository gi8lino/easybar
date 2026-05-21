# Lua Widgets Overview

EasyBar Lua widgets are node-based.

You do not return widget trees. You create nodes, keep their handles, and update them with methods such as `node:set(...)` and `node:subscribe(...)`.

## Basic idea

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

## Interaction model

Interaction is node-based.

- Subscribe on a node handle.
- The subscribed node frame is the interactive surface.
- Use smaller child nodes when only part of a widget should be interactive.
- Use `group` when multiple child nodes should share one styled container.
- If children inside a group must be clicked independently, subscribe on the child handles.
- Subscribe on the group handle only when the whole group should behave as one interactive surface.

## Default styling

Lua widgets inherit native-like styling in the most common cases, so you usually do not need to restate the full shell or popup style.

| Node shape | Default styling |
| --- | --- |
| bar-root `item`, `row`, `group` | background `#1a1a1a`, border `#333333` width `1`, corner radius `8`, padding `8/8/4/4` |
| popup content | text color `#cdd6f4`, background `#111111`, border `#444444` width `1`, corner radius `8`, padding `8 x 6`, margin `0 x 8` |
| child items inside a parent/group | no root shell by default |

## Pages

- [Editor Support](editor-support.md)
- [API](api.md)
- [Events](events.md)
- [Properties](properties.md)
- [Grouping](grouping.md)
- [Popups](popups.md)
- [Intervals](intervals.md)
- [Commands](commands.md)
- [Logging](logging.md)
- [Examples](examples.md)
- [Style Guidelines](style-guidelines.md)
