# Intervals

Use `interval` with `on_interval` when a widget needs to poll.

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

## Referencing the node itself

When an interval callback needs to reference its own handle, declare the variable before assigning it:

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    interval = 60,
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

Do not write this:

```lua
local clock = easybar.add(easybar.kind.item, "clock", {
    interval = 60,
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

The callback may close over `clock` before it has been assigned.

## When to use intervals

Use intervals for polling:

- package manager state
- shell command output
- API checks
- periodic time-based updates

Use event subscriptions for real events:

- `network_change`
- `wifi_change`
- `volume_change`
- `system_woke`
- mouse events
