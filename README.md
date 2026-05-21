# EasyBar

![bar](./assets/bar.png)

EasyBar is a lightweight, scriptable macOS status bar built with SwiftUI and Lua.

It combines fast native widgets with flexible Lua widgets. Use built-ins for common system data, then add custom Lua widgets when you need something specific. EasyBar is designed for a clean macOS workflow and integrates especially well with AeroSpace.

## Inspiration and scope

EasyBar is heavily inspired by [SketchyBar](https://github.com/FelixKratz/SketchyBar).

I used SketchyBar for years, and it is a great product. EasyBar is not meant to be a drop-in replacement. It is a more opinionated project that reflects my own setup and trade-offs.

Some choices are intentional:

- EasyBar is built specifically around AeroSpace
- there are no plans to support yabai
- native Swift code is preferred wherever possible
- Lua is supported for custom widgets, but the core direction is Swift-first

EasyBar shares some ideas with SketchyBar, but aims to be a different kind of tool: a personal, strongly opinionated macOS bar focused on native Swift UI, helper agents, and an AeroSpace-based workflow.

## Features

- Native macOS bar window built with SwiftUI
- Native built-in widgets plus Lua widgets
- Object-style Lua widget API with node handles
- AeroSpace integration for spaces, focused app state, and layout mode state
- Event-driven updates and interactive popups
- Calendar and network helper agents for permission-sensitive data
- Homebrew install and service workflow
- Logging and startup diagnostics for troubleshooting
- Lightweight runtime metrics

## Screenshots

**Calendar**

![month_calendar](./assets/month.png)

**Upcoming**

![upcoming_calendar](./assets/upcoming.png)

**CPU**

![cpu](./assets/cpu.png)

**Front App**

![front_app](./assets/front_app.png)

**Context**

![context](./assets/context.png)

## Install

EasyBar is distributed through Homebrew in the `gi8lino/tap` tap.

Add the tap:

```bash
brew tap gi8lino/tap
```

Install EasyBar:

```bash
brew install gi8lino/tap/easybar
```

This also installs the calendar and network helper agents.

Start all services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

> [!NOTE]
> EasyBar is not notarized.
>
> Notarization is one of Apple's distribution checks. In practice, it means sending binaries to Apple and dealing with their packaging and approval flow.
>
> I do not mind the general idea of signing or notarization. I specifically do not want to spend time dealing with Apple's developer account, notarization pipeline, and release bureaucracy for this project.
>
> The Homebrew install is meant to work out of the box in the common case. If macOS blocks EasyBar or one of its helper agents with a Gatekeeper or malware verification warning, remove the quarantine attribute and start the services again.

If macOS blocks the app, helper agents, or CLI, remove quarantine:

```bash
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-calendar-agent/libexec/EasyBarCalendarAgent.app"
xattr -dr com.apple.quarantine "$(brew --prefix)/opt/easybar-network-agent/libexec/EasyBarNetworkAgent.app"
xattr -d com.apple.quarantine "$(command -v easybar)"
```

Then restart the services:

```bash
brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

## Configuration

EasyBar reads its runtime config from:

```text
~/.config/easybar/config.toml
```

You can override that path with:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml
```

A small example:

```toml
[app]
lua_socket_path = "/tmp/EasyBar/lua-runtime.sock"

[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

[builtins.spaces]
enabled = true

[builtins.calendar]
enabled = true
```

`[app.env]` is passed into the Lua runtime and widget shell commands. `app.lua_socket_path` controls the dedicated Unix socket used between the main app and the Lua widget runtime. This is the right place to make GUI-launched widgets see tools like `tailscale`, `kubectl`, or custom scripts without depending on shell startup files.

The repository includes two config examples:

- [config.defaults.toml](./config.defaults.toml)
  Full reference file with the current defaults and supported sections.

- [config.minimal.toml](./config.minimal.toml)
  Small starter example with a native `system` group.

Config details, native groups, and example layouts are documented in [docs/CONFIG.md](./docs/CONFIG.md).

## Lua widgets

Lua widgets create nodes with `easybar.add(...)`. The call returns a node handle, and widget code updates or subscribes through that handle.

Example:

```lua
local clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    icon = "🕒",
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})

clock:subscribe(easybar.events.mouse.clicked, function()
    easybar.log(easybar.level.info, "clock clicked")
end)
```

Composite widgets should use `group` or `row` as containers and assign children with `parent = group.name`.

More details live in [docs/LUA_WIDGETS.md](./docs/LUA_WIDGETS.md).

## AeroSpace integration

EasyBar relies on AeroSpace callbacks to refresh workspace, focus, and layout-mode state immediately.

Add these hooks to your AeroSpace config:

```toml
exec-on-workspace-change = [
  'exec-and-forget /opt/homebrew/bin/easybar --workspace-changed'
]

on-focus-changed = [
  'exec-and-forget /opt/homebrew/bin/easybar --focus-changed'
]
```

These callbacks keep built-in AeroSpace widgets in sync when the focused workspace or focused window changes.

If you use the built-in AeroSpace mode widget, also trigger EasyBar whenever you change the current layout mode.

Example:

```toml
alt-e = [
  'layout tiles horizontal',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-v = [
  'layout tiles vertical',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-s = [
  'layout v_accordion',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
alt-shift-space = [
  'layout floating tiling',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
```

Without these callbacks, EasyBar can still refresh manually, but AeroSpace-derived widgets may look stale until the next refresh.

## Logging

EasyBar, the calendar agent, and the network agent share one logging config block.

Example:

```toml
[logging]
enabled = true
level = "debug"
directory = "~/.local/state/easybar"
```

Supported levels:

- `trace`
- `debug`
- `info`
- `warn`
- `error`

Behavior:

- `trace` includes everything, including very verbose trace logs
- `debug` includes debug output, info, warnings, and errors
- `info` writes normal operational logs
- `warn` keeps only warnings and errors
- `error` keeps only error logs

When file logging is enabled, EasyBar writes these files into the configured logging directory:

- `easybar.out`
- `calendar-agent.out`
- `network-agent.out`

The app and helper agents no longer use the legacy `EASYBAR_DEBUG` or `EASYBAR_TRACE` environment toggles. For normal app and agent logging, use `logging.level` in `config.toml`.

The `easybar` CLI still supports debug output independently through:

```bash
easybar --debug
EASYBAR_DEBUG=1 easybar ...
```

This CLI-only environment behavior is only for the control client. It does not change the main app or agent log level.

## Agents

EasyBar uses two small helper agents:

- `easybar-calendar-agent`
  Owns `EventKit`, requests Calendar permission, watches calendar changes, and pushes cached snapshots to EasyBar over a local Unix socket.

- `easybar-network-agent`
  Owns Wi-Fi and network state that depends on Location Services permission, watches network changes, and pushes field updates to EasyBar over a local Unix socket.

This keeps permission-sensitive APIs out of the main UI process and makes those widgets more reliable.

Both agents are enabled by default. They can be turned off independently in `config.toml`:

```toml
[agents.calendar]
enabled = true

[agents.network]
enabled = true
```

For the network agent, you can also decide what happens when Location Services permission is denied:

```toml
[agents.network]
allow_unauthorized_non_sensitive_fields = false
```

The default is privacy-first: requests for Wi-Fi fields fail until location access is granted.

More details live in [docs/AGENTS.md](./docs/AGENTS.md).

## Control socket

EasyBar exposes one local Unix control socket for `easybar` and other clients.

Commands are sent as typed JSON requests, not raw strings.

Example request shape:

```json
{
  "command": "<typed command name>"
}
```

Responses are typed too:

```json
{
  "kind": "accepted",
  "message": null
}
```

Supported commands:

- `workspace_changed`
- `focus_changed`
- `space_mode_changed`
- `manual_refresh`
- `restart_lua_runtime`
- `reload_config`
- `metrics`

The `easybar` CLI already speaks this protocol, so most users should use the CLI instead of talking to the socket directly.

## Runtime control

EasyBar exposes three runtime control actions because they solve different problems.

### Refresh

Use:

```bash
easybar --refresh
```

This:

- refreshes the bar and widgets using the currently loaded config
- pulls fresh data from agents
- re-emits refresh-style state so widgets can update immediately
- does not reread `config.toml` from disk
- does not restart the Lua runtime

Use this when the config is already correct and you want fresh UI state or fresh agent-backed data.

### Restart Lua runtime

Use:

```bash
easybar --restart-lua-runtime
```

This:

- stops the current Lua runtime
- starts a fresh Lua runtime process
- reloads Lua widget files
- resets Lua-side widget state
- does not reread `config.toml` from disk

Use this when the Lua side is stuck, stale, or needs a full runtime reset.

### Reload config

Use:

```bash
easybar --reload-config
```

This:

- reloads `config.toml` from disk
- rebuilds EasyBar using the new config
- reapplies native widgets and Lua runtime state against the updated configuration

Use this when you changed the config file itself.

## Metrics

EasyBar can stream lightweight internal metrics over the main socket.

Use:

```bash
easybar --metrics
```

for one point-in-time snapshot, or:

```bash
easybar --metrics --watch
```

for a rolling terminal view with simple graphs.

The metrics stream includes:

- EasyBar process CPU, memory, and thread count
- Lua runtime CPU, memory, and thread count
- runtime event and tree-update rates
- agent connection state plus message, reconnect, and refresh counters
- the busiest widget tree roots and top emitted event names

The periodic sampler stays off until a metrics client asks for it, so normal idle runtime does not keep collecting process samples when nobody is watching.

## Troubleshooting

When something is wrong, first check whether EasyBar and its helper agents are running, whether duplicate processes exist, and whether the logs show a startup warning.

### Quick checks

Check the Homebrew services:

```bash
brew services list | grep easybar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
```

Check that only one main EasyBar process is running. EasyBar refuses to start when another instance already holds its lock, but duplicate service or manual launches are still the first thing to rule out.

Check the control socket with the CLI:

```bash
easybar --refresh
```

If that fails, EasyBar may not be running, may have been blocked by macOS, or may have failed during startup.

### Logs

If logging is enabled in your config, EasyBar writes useful startup information such as:

- bundle path and executable path
- config path and widget path
- enabled agents and socket paths
- screen geometry
- environment overrides
- whether required fonts are available
- whether another EasyBar instance is already running

Enable logging in `config.toml`:

```toml
[logging]
enabled = true
level = "debug"
```

Then inspect the log output in your configured logging directory.

If you installed with Homebrew and are using services, also check Homebrew service logs:

```bash
tail -n 200 ~/Library/Logs/Homebrew/easybar/*.log
tail -n 200 ~/Library/Logs/Homebrew/easybar-calendar-agent/*.log
tail -n 200 ~/Library/Logs/Homebrew/easybar-network-agent/*.log
```

If your Homebrew setup writes logs somewhere else, use these commands to find the actual paths:

```bash
brew services info easybar
brew services info easybar-calendar-agent
brew services info easybar-network-agent
```

For very verbose app and agent troubleshooting, temporarily raise the level to `trace`:

```toml
[logging]
enabled = true
level = "trace"
```

### EasyBar does not appear

Check whether the service is running:

```bash
brew services list | grep easybar
```

Try launching the app directly:

```bash
open "$(brew --prefix)/opt/easybar/libexec/EasyBar.app"
```

If that works but the service does not, restart the services:

```bash
brew services restart gi8lino/tap/easybar-calendar-agent
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

If nothing appears, check logs for startup warnings, macOS permission issues, or quarantine problems.

### Another instance is already running

EasyBar uses a single-instance guard. If a second instance starts, it logs a warning and exits.

Detect duplicates with:

```bash
pgrep -fl EasyBar
```

If you accidentally launched both a Homebrew service and a manual app instance, stop the extra one:

```bash
pkill -x EasyBar
brew services restart gi8lino/tap/easybar
```

If you are testing local builds from `dist/`, stop all services first so you do not mix service and manual runs.

### Nerd Font icons look wrong or are clipped

EasyBar expects `Symbols Nerd Font Mono` for several icons. On startup, it checks whether the font is installed and logs a warning if it is missing.

You can inspect installed fonts in Font Book, or from the terminal:

```bash
system_profiler SPFontsDataType | grep -B2 -A4 "Symbols Nerd Font Mono"
```

If the font is missing, install Nerd Fonts and restart EasyBar.

If the font was installed after EasyBar already started, restart the app and agents so the font check and layout run again.

### Calendar widget is empty

Make sure the calendar agent is running:

```bash
brew services list | grep easybar-calendar-agent
pgrep -fl easybar-calendar-agent
```

Then grant Calendar access in macOS settings.

EasyBar exposes menu actions to open the relevant settings pages, and the calendar agent permission state is shown in the bar context menu.

If you changed permissions and nothing updates, restart the calendar agent and EasyBar:

```bash
brew services restart gi8lino/tap/easybar-calendar-agent
brew services restart gi8lino/tap/easybar
```

### Wi-Fi or network widget is empty

Make sure the network agent is running:

```bash
brew services list | grep easybar-network-agent
pgrep -fl easybar-network-agent
```

The network agent depends on Location Services permission. If permission is denied or unresolved, Wi-Fi-specific fields may be unavailable by design.

Restart the network agent after changing permission settings:

```bash
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

### AeroSpace widgets do not update

Make sure your AeroSpace config calls EasyBar after relevant state changes.

Workspace changes should call:

```toml
exec-on-workspace-change = [
  'exec-and-forget /opt/homebrew/bin/easybar --workspace-changed'
]
```

Focus changes should call:

```toml
on-focus-changed = [
  'exec-and-forget /opt/homebrew/bin/easybar --focus-changed'
]
```

If your AeroSpace mode widget does not change after switching layouts, call EasyBar after every relevant `layout ...` command:

```toml
alt-e = [
  'layout tiles horizontal',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
```

Without these callbacks, AeroSpace-derived widgets may look stale until a manual refresh.

You can trigger one manually with:

```bash
easybar --refresh
```

### Spaces widget misses an app launch or quit

The built-in spaces widget refreshes AeroSpace-derived state from a mix of AeroSpace callbacks and macOS app lifecycle notifications.

Workspace and focus changes should be wired from AeroSpace with:

```bash
easybar --workspace-changed
easybar --focus-changed
```

App quits are also refreshed from macOS termination notifications.

App launches use a short delayed refresh so background apps such as Docker have a chance to create their first window before EasyBar asks AeroSpace for `list-windows`.

If icons still look stale after a launch, trigger a manual refresh once:

```bash
easybar --refresh
```

### Config changes do not apply

If `watch_config = false`, EasyBar will not automatically reload config changes.

Either enable config watching or reload manually:

```bash
easybar --reload-config
```

If a reload is rejected, EasyBar keeps the last valid config and logs the parse or validation error. Check the logs instead of assuming the new file was accepted.

### Lua widgets stop updating

First try a normal refresh:

```bash
easybar --refresh
```

That refreshes the bar and widgets using the currently loaded config and pulls fresh data from agents, but it does not reload config from disk and does not restart the Lua runtime.

If the Lua side itself seems stuck, restart it explicitly:

```bash
easybar --restart-lua-runtime
```

The bar context menu item does the same thing:

```text
Restart Lua Runtime
```

If that is still not enough, restart the whole app:

```bash
brew services restart gi8lino/tap/easybar
```

If a widget still fails, check your configured `widgets_dir`, Lua path, `[app.env]`, and any widget-specific logs or output.

### Reset and recover

A good recovery sequence is:

```bash
brew services stop gi8lino/tap/easybar
brew services stop gi8lino/tap/easybar-calendar-agent
brew services stop gi8lino/tap/easybar-network-agent

pkill -x EasyBar || true
pkill -x easybar-calendar-agent || true
pkill -x easybar-network-agent || true

brew services start gi8lino/tap/easybar-calendar-agent
brew services start gi8lino/tap/easybar-network-agent
brew services start gi8lino/tap/easybar
```

This clears the usual problems caused by duplicate instances, stale agent state, or mixed manual and service launches.

## Packages and targets

EasyBar is split into a few Swift packages and targets:

- `EasyBarShared`
  Shared models, config loading, IPC types, and common utilities.

- `EasyBar`
  The main macOS status bar app.

- `EasyBarCtl`
  The `easybar` command-line client for talking to the control socket.

- `EasyBarCalendarAgent`
  Helper app that owns EventKit and calendar snapshots.

- `EasyBarCalendarCore`
  Shared calendar-agent implementation used by `EasyBarCalendarAgent` and ready to be reused by future standalone calendar apps.

- `EasyBarCalendarPresentation`
  Shared calendar request-building and presentation helpers used by `EasyBar` and ready to be reused by future standalone calendar apps.

- `EasyBarCalendarUI`
  Shared calendar SwiftUI components and composer state used by `EasyBar` and ready to be reused by future standalone calendar apps.

- `EasyBarNetworkAgent`
  Helper app that owns Wi-Fi and network observation.

- `EasyBarNetworkAgentCore`
  Shared network-agent implementation used by EasyBarNetworkAgent and also reused by the standalone wifi-snitch project.

For implementation details, see the docs in [`docs/`](./docs/).

## Docs

- [docs/CONFIG.md](./docs/CONFIG.md)
  Config structure, native groups, and box-model rules.

- [docs/AGENTS.md](./docs/AGENTS.md)
  Calendar and network agents, permissions, and how EasyBar uses them.

- [docs/LUA_WIDGETS.md](./docs/LUA_WIDGETS.md)
  Lua widget authoring and interaction model.

## Developer menu

EasyBar includes a hidden developer section in the bar context menu.

By default, it only appears when you hold `Shift` and right-click the bar.

You can also make it always visible in `config.toml`:

```toml
develop = true
```

The developer section currently includes:

- runtime log level selection
- open log folder

## License

This project is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for details.
