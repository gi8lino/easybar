# Lua Widgets

EasyBar Lua widgets are node-based.

You do not return widget trees. You create nodes, keep their handles, and update them with methods such as `node:set(...)` and `node:subscribe(...)`.

Lua widgets are the right tool when you want:

- custom text, icons, or layout that the built-ins do not provide
- shell-command integration or lightweight local scripting
- event-driven behavior tied to app changes, mouse input, timers, or helper-agent updates
- small personal workflows without touching the native Swift codebase

A minimal widget looks like this:

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    label = os.date("%H:%M"),
    interval = 60,
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

## Mental model

Lua widgets follow this model:

1. create nodes with `easybar.add(...)`
2. store returned handles
3. update nodes with `node:set(...)`
4. subscribe to events with `node:subscribe(...)`
5. let EasyBar render the current node state

The Lua runtime is for custom widgets and user-specific behavior. Built-in platform-integrated widgets should usually stay native when possible.

## What to read next

- [Functions](reference/functions.md) for the creation and update API
- [Events](reference/events.md) for subscriptions and payload shapes
- [Properties](reference/properties.md) for node styling and layout fields
- [Examples](guides/examples.md) for realistic widget patterns

## Generated reference

The API reference is generated from the LuaLS stub:

- [Functions](reference/functions.md)
- [Node kinds](reference/node-kinds.md)
- [Events](reference/events.md)
- [Properties](reference/properties.md)

Use the guides for concepts and patterns. Use the reference pages for exact API details.
