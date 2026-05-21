# Lua Runtime Events

Events are the main data path from Swift into Lua.

## 1. Swift emits events

From `EventHub.swift`.

Each event:

- notifies Swift listeners
- is sent to Lua as JSON over the dedicated socket

## 2. Lua declares subscriptions

After loading widgets:

- Lua sends required events
- Swift enables only those

The subscription list can change at runtime.

For example, `interval` plus `on_interval` causes Lua to request the shared interval driver cadence it needs.

## 3. Initial events

Once Lua has published both its subscriptions and `ready`, `WidgetEngine` emits the currently subscribed initial event batch and then triggers one normal refresh pass.

This prevents empty UI on startup.

## 4. Manual refresh

Refresh events go through the same pipeline.

There is no special path.

## 5. Lua dispatch

Lua runtime:

1. reads JSON line
2. decodes it
3. normalizes with `events.lua`
4. dispatches through subscriptions
5. renders dirty trees

## End-to-end data flow

Complete runtime path from system event to UI:

1. system event occurs, for example Wi-Fi change
2. Swift event source emits through `EventHub`
3. event is forwarded to Lua via socket JSON
4. Lua normalizes and dispatches it
5. widget handlers update registry state through node handles
6. renderer builds a new tree
7. Lua emits JSON tree via the same socket
8. Swift decodes and applies it to `WidgetStore`
9. Swift UI updates accordingly

Important properties:

- no shared memory between Swift and Lua
- all communication is JSON-based
- rendering is always derived, never incremental mutation
