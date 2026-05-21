# Event Flow

EasyBar reacts to several kinds of events:

- macOS state changes
- AeroSpace-related changes
- agent socket updates
- Lua runtime subscriptions
- direct control-socket commands
- user interaction such as clicks, hover, scroll, and sliders

## Simplified flow

```text
system event / app trigger / AeroSpace callback
                    │
                    ▼
               EasyBar event layer
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
   native widget   Lua runtime   agent fetch/subscription
     updates         updates          handling
```

The important design choice is that EasyBar acts as the coordinator.

It does not let every subsystem talk to every other subsystem directly.

## Lua runtime flow

The Lua runtime flow is:

1. EasyBar starts the Lua process.
2. Lua loads widget files from the widget directory.
3. Lua declares which events it needs.
4. Swift starts only the necessary event sources.
5. Swift sends normalized events to Lua.
6. Lua updates widget state and emits rendered trees.
7. Swift decodes those trees and applies them to the widget store.

This design intentionally avoids embedding arbitrary Lua execution into the UI process.
