# Control Socket

EasyBar exposes a local Unix control socket for commands sent by the CLI or other local clients.

## Purpose

The control socket is used for commands such as:

- `workspace_changed`
- `focus_changed`
- `space_mode_changed`
- `manual_refresh`
- `restart_lua_runtime`
- `reload_config`
- `metrics`

Requests and responses are typed JSON.

## Why it exists

The boundary exists so that:

- optional AeroSpace callbacks can trigger EasyBar updates cleanly
- shell scripts can refresh or reload the app safely
- external integrations do not need direct access to internal app objects

The control socket is a command interface, not a general event stream.

## AeroSpace updates

For AeroSpace-backed widgets, the app keeps a long-lived `aerospace subscribe --all` process open and reacts to JSON-line events for focus, focused workspace, focused monitor, binding mode, new-window detection, and triggered bindings.

The subscription is the primary update trigger. The older control-socket commands remain supported as explicit callback and scripting entry points, but workspace and focus callbacks are no longer required for normal AeroSpace updates.

The app also uses a small amount of native macOS observation to keep UI state current when AeroSpace events are not enough by themselves:

- app activation updates focused-app UI immediately
- app termination triggers one refresh so closed apps disappear from spaces promptly
- app launch schedules one short delayed refresh so newly launched apps have time to create windows before EasyBar re-reads AeroSpace state

Those native notifications complement the AeroSpace subscription and the control socket. They do not replace snapshot reloads from AeroSpace itself.

## What remains callback-only or fallback-only

AeroSpace subscription events are update triggers, not a complete state API. EasyBar still fetches the actual state through AeroSpace snapshot commands.

Some changes do not have dedicated AeroSpace subscription events, especially layout changes and window closures. `binding-triggered` is used as a debounced hint for layout-related keybindings, but it is not the same as a real `layout-changed` event.

For the most explicit layout-mode refresh path, users can keep `easybar --space-mode-changed` only on AeroSpace bindings that actually run `layout ...` commands. Workspace and focus callbacks can usually be removed.
