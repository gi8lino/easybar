# Process Model

At a high level, EasyBar runs several processes.

## Runtime processes

- one `EasyBar` app process
- zero or one `EasyBarCalendarAgent` process
- zero or one `EasyBarNetworkAgent` process
- one `easybar` CLI process per command invocation
- one Lua runtime child process owned by the main app when Lua widgets are enabled

## Single instance guard

The project uses a single-instance guard for the main app to avoid duplicate bars.

Duplicate processes are one of the most common causes of confusing behavior in status bar apps.

If a second instance starts, it logs a warning and exits.

## Helper agents

Helper agents are separate processes because they own permission-sensitive APIs:

- EventKit for calendar access
- Wi-Fi and network APIs that depend on Location Services permission

The agents collect and normalize data.
EasyBar consumes that data and renders UI from it.

The packaged agents are nested inside `EasyBar.app/Contents/Library/LoginItems`. The main app launches enabled agents, monitors them, and relaunches them after crashes or acknowledged restart requests.

## Lua runtime process

Lua widgets do not run in-process inside the main app.

EasyBar starts a separate Lua process and communicates with it over a dedicated Unix socket.

Benefits:

- crash isolation
- easier reloads
- full runtime reset on restart
- simpler mental model for widget execution
- clearer logging and transport behavior
