# Events

Widgets subscribe to events through node handles.

## `node:subscribe(events, handler)`

Subscribe one node to one or more events.

```lua
clock:subscribe({ easybar.events.minute_tick, easybar.events.forced }, function(event)
    clock:set({
        label = {
            string = os.date("%H:%M"),
        },
    })
end)
```

## Event fields

Event fields include:

- `event.name`
- `event.widget_id`
- `event.target_widget_id`
- `event.app_name`
- `event.button`
- `event.direction`
- `event.value`
- `event.delta_x`
- `event.delta_y`
- `event.network`
- `event.power`
- `event.audio`

For interaction handlers on parent nodes, `event.target_widget_id` tells you which concrete child node actually received the click or hover.

Use that when a root widget should ignore button clicks coming from popup children.

## Common events

- `easybar.events.forced`
- `easybar.events.system_woke`
- `easybar.events.wifi_change`
- `easybar.events.network_change`
- `easybar.events.volume_change`
- `easybar.events.minute_tick`
- `easybar.events.second_tick`
- `easybar.events.mouse.entered`
- `easybar.events.mouse.exited`
- `easybar.events.mouse.clicked`
- `easybar.events.mouse.scrolled`
- `easybar.events.slider.preview`
- `easybar.events.slider.changed`

## App events

App events such as `minute_tick`, `second_tick`, `network_change`, and `volume_change` are only forwarded into the Lua runtime when at least one Lua widget subscribes to them.

## Targeted interaction events

Targeted interaction events are delivered to the relevant Lua widget callbacks when those interactions occur.

Examples:

- `mouse.clicked`
- `mouse.entered`
- `mouse.exited`
- `mouse.scrolled`
- `slider.preview`
- `slider.changed`
