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
- `inbox_send`
- `inbox_read`
- `inbox_mark_read`
- `inbox_mark_unread`
- `inbox_dismiss`
- `inbox_remove`
- `inbox_clear`

Requests and responses are typed JSON.

## Why it exists

The boundary exists so that:

- shell scripts can refresh or reload the app safely
- local scripts can emit EasyBar driver events
- external integrations do not need direct access to internal app objects

The control socket is a command interface, not a general event stream. Inbox requests carry typed
item, source, and ID payloads; they do not execute commands supplied in notification content.

## Scripting events

EasyBar scripting events are commands that ask the running app to refresh state and emit one of the public Lua driver events:

- `workspace_change`
- `focus_change`
- `space_mode_change`

They are intended for local automation that already knows something changed and wants widgets to react through the normal EasyBar event system.

## AeroSpace updates

For AeroSpace-backed widgets, the app connects directly to AeroSpace's native Unix socket and sends the equivalent of an `aerospace subscribe --all` request. It reacts to framed events for focus, focused workspace, focused monitor, binding mode, new-window detection, and triggered bindings. No `aerospace subscribe` CLI process is spawned.

While AeroSpace-backed state is active, EasyBar schedules reconnect attempts with bounded backoff even if AeroSpace's socket is temporarily absent. Socket connect, handshake, and subscription setup share a finite startup deadline.

Focus events take a low-latency path: app focus runs only the focused-window query before a trailing full snapshot, while a focused-workspace event updates the existing Spaces model from its `workspace` field before starting a full snapshot. Focused-monitor changes start a full snapshot immediately. Other event bursts share a 120 ms trailing debounce. Full snapshots cannot overwrite a newer fast focus result.

After state changes, the service invokes typed callbacks registered by the active native widgets instead of broadcasting an in-process notification.

## AeroSpace Snapshot Refreshes

AeroSpace subscription events are not a complete state API. EasyBar uses focused-workspace metadata for immediate presentation, then fetches canonical state through the `aerospace list-workspaces` and `aerospace list-windows` CLI commands.

Some changes do not have dedicated AeroSpace subscription events, especially layout changes and window closures. `binding-triggered` is used as a debounced hint for layout-related keybindings, but it is not the same as a real `layout-changed` event.
