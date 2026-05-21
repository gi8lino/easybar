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

- AeroSpace callbacks can trigger EasyBar updates cleanly
- shell scripts can refresh or reload the app safely
- external integrations do not need direct access to internal app objects

The control socket is a command interface, not a general event stream.

## Native macOS observation

For AeroSpace-backed widgets, the app also uses a small amount of native macOS observation to keep UI state current when AeroSpace callbacks are not enough by themselves:

- app activation updates focused-app UI immediately
- app termination triggers one refresh so closed apps disappear from spaces promptly
- app launch schedules one short delayed refresh so newly launched apps have time to create windows before EasyBar re-reads AeroSpace state

Those native notifications complement the control socket. They do not replace the explicit AeroSpace callbacks for workspace and focus changes.
