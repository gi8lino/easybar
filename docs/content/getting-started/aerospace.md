# AeroSpace Integration

EasyBar v0.4.0 and newer keeps AeroSpace-backed widgets current through a long-lived subscription to AeroSpace's native Unix socket.

That means the built-in spaces, front-app, and AeroSpace mode widgets update without extra workspace or focus commands in your AeroSpace config. EasyBar subscribes to all AeroSpace event types and refreshes its AeroSpace snapshot when those events arrive.

## Requirements

EasyBar v0.4.0 and newer require AeroSpace 0.21.0 or newer. The AeroSpace integration uses formatted JSON output from the `aerospace list-workspaces` and `aerospace list-windows` CLI commands, plus framed subscription events received directly from AeroSpace's Unix socket.

EasyBar v0.3.0 was the last release that supported text-based AeroSpace output. Use v0.3.0 only if you must keep an older AeroSpace version.

Check your AeroSpace versions with:

```bash
aerospace --version
```

Both the CLI client and the running AeroSpace.app server should be at least 0.21.0. If they differ after updating, restart AeroSpace.app.

## Automatic subscription

When an AeroSpace-backed widget starts, EasyBar connects directly to AeroSpace's Unix socket and sends a subscription request equivalent to:

```bash
aerospace subscribe --all
```

AeroSpace sends the current state immediately when the stream connects, and EasyBar uses that initial event as an immediate sync signal. Event bursts are debounced before EasyBar re-reads AeroSpace state; `binding-triggered` gets a slightly longer debounce because AeroSpace emits it before running the binding's commands.

EasyBar does not spawn the `aerospace subscribe` CLI process. If the socket connection closes while AeroSpace's socket remains available, EasyBar schedules a reconnect with bounded backoff. This covers common cases such as restarting or updating AeroSpace while EasyBar is already running.

EasyBar uses the subscription events only as update triggers. The source of truth remains the snapshot loaded from `aerospace list-workspaces --json` and `aerospace list-windows --json`.

The currently supported AeroSpace subscription events are:

- `focus-changed`
- `focused-monitor-changed`
- `focused-workspace-changed`
- `mode-changed`
- `window-detected`
- `binding-triggered`

`mode-changed` is AeroSpace binding-mode state, for example `main` or `service`. It is not the focused window's layout mode. EasyBar therefore uses it as a refresh trigger but does not forward it as EasyBar's layout-mode event.

Focus and workspace events are forwarded into the EasyBar event system for Lua widgets that subscribe to those driver events.

EasyBar still observes a few native macOS notifications as a complement:

- app activation updates the focused-app UI optimistically
- app termination refreshes spaces so closed apps disappear promptly
- app launch schedules one short delayed refresh for apps that create windows slightly later

## AeroSpace config

EasyBar updates AeroSpace-backed widgets from its automatic socket subscription, so no EasyBar commands are required in your AeroSpace config for normal updates. Refreshed state is delivered directly to the registered native widgets through typed in-process callbacks.

EasyBar listens to `binding-triggered` and re-reads AeroSpace state after a short delay, so separate layout commands are not needed either.

## Manual refresh

You can always trigger one refresh manually:

```bash
easybar --refresh
```

## Troubleshooting

Raise EasyBar logging to debug and look for subscription logs:

```toml
[logging]
enabled = true
level = "debug"
```

Useful log messages include:

- `aerospace subscription started`
- `aerospace subscription event received`
- `aerospace subscription disconnected`
- `aerospace subscription ended`
- `aerospace subscription reconnect scheduled`

If a local script needs to notify widgets about a known state change, use EasyBar scripting events from [Runtime Control](../runtime/control.md).

## Related pages

- [Runtime Control](../runtime/control.md)
- [Troubleshooting](../runtime/troubleshooting.md)
