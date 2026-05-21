# Examples

This page shows complete Lua widget patterns.

If you are just starting out, read [First Widget](first-widget.md) before using these as templates.

## Toggle widget

```lua
local enabled = false
local toggle

local function render()
    toggle:set({
        icon = {
            string = enabled and "󰄬" or "󰄱",
            color = enabled and "#30d158" or "#ff453a",
        },
        label = {
            string = enabled and "ON" or "OFF",
            color = enabled and "#30d158" or "#ff453a",
        },
    })
end

toggle = easybar.add(easybar.kind.item, "toggle_test", {
    position = "right",
    order = 1,
})

toggle:subscribe(easybar.events.forced, function()
    render()
end)

toggle:subscribe(easybar.events.mouse.clicked, function()
    enabled = not enabled
    render()
end)

render()
```

## Clock widget

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    icon = "🕒",
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

## Image-only widget

```lua
local tailscale = easybar.add(easybar.kind.item, "tailscale", {
    position = "right",
    order = 2,
    icon = {
        image = "/path/to/tailscale.png",
        image_size = 16,
    },
    popup = {
        drawing = true,
    },
})
```

## Related pages

- [Subscribe To Events](subscribe-to-events.md)
- [Style Popups And Groups](style-popups-and-groups.md)
- [API Summary](../api-summary.md)
