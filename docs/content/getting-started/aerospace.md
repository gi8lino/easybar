# AeroSpace Integration

EasyBar v0.4.0 and newer keeps AeroSpace-backed widgets current by opening a long-lived `aerospace subscribe` stream from the main app.

That means the built-in spaces, front-app, and AeroSpace mode widgets no longer require the old workspace/focus AeroSpace callback wiring for normal updates. EasyBar subscribes to all AeroSpace event types and refreshes its AeroSpace snapshot when those events arrive.

## Requirements

EasyBar v0.4.0 and newer require AeroSpace 0.21.0 or newer. The AeroSpace integration uses formatted JSON output from `aerospace list-workspaces` and `aerospace list-windows`, plus the JSON-lines event stream from `aerospace subscribe`.

EasyBar v0.3.0 was the last release that supported text-based AeroSpace output. Use v0.3.0 only if you must keep an older AeroSpace version.

Check your AeroSpace versions with:

```bash
aerospace --version
```

Both the CLI client and the running AeroSpace.app server should be at least 0.21.0. If they differ after updating, restart AeroSpace.app.

## Automatic subscription

When EasyBar starts, it runs a subscription equivalent to:

```bash
aerospace subscribe --all
```

AeroSpace sends the current state immediately when the stream connects, and EasyBar uses that initial event as an immediate sync signal. Event bursts are debounced before EasyBar re-reads AeroSpace state; `binding-triggered` gets a slightly longer debounce because AeroSpace emits it before running the binding's commands.

If the subscription process exits while AeroSpace is still installed, EasyBar schedules a reconnect with bounded backoff. This covers common cases such as restarting or updating AeroSpace while EasyBar is already running.

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

## AeroSpace config cleanup

EasyBar updates AeroSpace-backed widgets from its automatic subscription stream. Remove old EasyBar callback commands from your AeroSpace config if they are still present.

EasyBar listens to `binding-triggered` and re-reads AeroSpace state after a short delay, so separate layout callback commands are not needed either.

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
- `aerospace subscription exited`
- `aerospace subscription reconnect scheduled`

If the subscription cannot start, EasyBar still accepts the CLI callback commands shown above.

## Related pages

- [Runtime Control](../runtime/control.md)
- [Troubleshooting](../runtime/troubleshooting.md)
