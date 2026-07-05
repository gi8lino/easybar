# Control Socket

EasyBar exposes a local Unix control socket for commands sent by the CLI or other local clients.

## Purpose

The control socket is used for commands such as:

- `manual_refresh`
- `workspace_change`
- `focus_change`
- `space_mode_change`
- `restart_lua_runtime`
- `reload_config`
- `metrics`

Requests and responses are typed JSON.

## Why it exists

The boundary exists so that:

- shell scripts can refresh or reload the app safely
- local scripts can emit EasyBar driver events
- external integrations do not need direct access to internal app objects

The control socket is a command interface, not a general event stream.

## Scripting events

EasyBar scripting events are commands that ask the running app to refresh state and emit one of the public Lua driver events:

- `workspace_change`
- `focus_change`
- `space_mode_change`

They are intended for local automation that already knows something changed and wants widgets to react through the normal EasyBar event system.

## AeroSpace updates

For AeroSpace-backed widgets, the app keeps a long-lived `aerospace subscribe --all` process open and reacts to JSON-line events for focus, focused workspace, focused monitor, binding mode, new-window detection, and triggered bindings.

If the `aerospace subscribe` process exits while the executable is still available, EasyBar schedules reconnect attempts with bounded backoff.

The app also uses a small amount of native macOS observation to keep UI state current when AeroSpace events are not enough by themselves:

- app activation updates focused-app UI immediately
- app termination triggers one refresh so closed apps disappear from spaces promptly
- app launch schedules one short delayed refresh so newly launched apps have time to create windows before EasyBar re-reads AeroSpace state

Those native notifications complement the AeroSpace subscription. They do not replace snapshot reloads from AeroSpace itself.

## AeroSpace Snapshot Refreshes

AeroSpace subscription events are update triggers, not a complete state API. EasyBar still fetches the actual state through AeroSpace snapshot commands.

Some changes do not have dedicated AeroSpace subscription events, especially layout changes and window closures. `binding-triggered` is used as a debounced hint for layout-related keybindings, but it is not the same as a real `layout-changed` event.
