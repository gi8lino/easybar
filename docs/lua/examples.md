# Lua Examples

This page contains small widget examples.

## Minimal icon-only widget

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

Bar-root Lua items already inherit the native shell by default, so you usually only need `easybar.default(...)` for shared child styling or widget-specific overrides.

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

## Clickable toggle

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

## Composite group

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
