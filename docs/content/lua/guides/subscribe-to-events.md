# Subscribe To Events

EasyBar widgets become interesting when they react to runtime events.

This guide shows how to subscribe to events and how to think about the payload you receive.

## Basic subscription

```lua
local battery = easybar.add(easybar.kind.item, "battery_status", {
    position = "right",
    order = 20,
    label = "Battery",
})

battery:subscribe(easybar.events.forced, function()
    battery:set({
        label = "Refreshed",
    })
end)
```

This attaches one handler to one event token.

## Mouse interaction

```lua
battery:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == "left" then
        battery:set({
            label = "Clicked",
        })
    end
end)
```

The event payload tells you what happened. For mouse events, common fields include:

- `event.button`
- `event.direction`
- `event.target_widget_id`

See [Events](../reference/events.md).

## Multiple events

You can subscribe to more than one event at once:

```lua
battery:subscribe({
    easybar.events.forced,
    easybar.events.power_source_change,
    easybar.events.charging_state_change,
}, function(event)
    battery:set({
        label = event.name,
    })
end)
```

This works well when several runtime events should trigger the same refresh logic.

## Pattern: separate render from event handling

For non-trivial widgets, it helps to separate state updates from rendering:

```lua
local state = {
    connected = false,
}

local vpn = easybar.add(easybar.kind.item, "vpn", {
    position = "right",
    order = 30,
})

local function render()
    vpn:set({
        label = state.connected and "VPN On" or "VPN Off",
    })
end

vpn:subscribe(easybar.events.forced, function()
    render()
end)

vpn:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == "left" then
        state.connected = not state.connected
        render()
    end
end)

render()
```

This keeps the event handlers small and makes the widget easier to grow later.

## Which events should you use?

- Use runtime events like `space_change`, `app_switch`, or `volume_change` for system-driven updates.
- Use mouse events for interaction on one node.
- Use interval callbacks when the data has no natural runtime event.

## Next steps

- Read [First Widget](first-widget.md) if you have not built a basic widget yet.
- Read [Events](../reference/events.md) for the full event list and payload types.
- Read [Commands](commands.md) if your event handler needs to call shell commands.
