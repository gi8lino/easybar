# Intervals

Use `interval` together with `on_interval` when a widget must poll.

## Example

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 30,
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

When an interval callback needs to reference its own handle, declare the variable before assigning it, as shown above.

## Recommended pattern

```lua
easybar.default({
    label = {
        color = "#cdd6f4",
    },
})

local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

## When to use intervals

Use `interval` and `on_interval` when a widget must poll.

Good examples:

- package manager status
- periodic command output
- clock updates
- external status scripts

Use `node:subscribe(...)` for real events such as:

- `network_change`
- `system_woke`
- `mouse.clicked`
