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

## Bundled Homebrew widget

[`widgets/brew.lua`](https://github.com/gi8lino/easybar/blob/main/widgets/brew.lua) is a complete
example of a stateful popup widget. It:

- checks formulae and casks with `brew outdated`
- exposes Update and Upgrade actions as clickable popup children
- runs Homebrew commands asynchronously so other widgets remain responsive
- changes Update to Cancel while an operation is active
- returns directly to the idle actions after cancellation while preserving the last known package list
- writes command diagnostics to `brew-widget.log` under the configured EasyBar logging directory

The widget is intentionally more extensive than the snippets on this page. Use it as a reference
for command chaining, cancellation, structured state rendering, popup rows, error presentation,
and bounded file logging.

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
