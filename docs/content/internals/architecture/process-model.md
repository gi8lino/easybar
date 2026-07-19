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

Releases package the app and CLI separately from each standalone agent application bundle. Homebrew installs each agent archive through its own formula and runs it as a keep-alive service. Keeping the cask and formula downloads distinct also prevents them from sharing quarantine state in Homebrew's download cache. The main app only communicates with agents over Unix sockets; it does not own their processes.

When an agent acknowledges a socket restart request and exits, Homebrew Services relaunches it. Keeping the agents outside `EasyBar.app` also gives macOS stable, independent identities for Calendar and Location permissions.

## Lua runtime process

Lua widgets do not run in-process inside the main app.

EasyBar starts a separate Lua process and communicates with it over a dedicated Unix socket.

Benefits:

- crash isolation
- easier reloads
- full runtime reset on restart
- simpler mental model for widget execution
- clearer logging and transport behavior
