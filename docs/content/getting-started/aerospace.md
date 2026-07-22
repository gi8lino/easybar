# AeroSpace Integration

EasyBar v0.4.0 and newer keeps AeroSpace-backed widgets current through a long-lived subscription to AeroSpace's native Unix socket.

That means the built-in spaces, front-app, and AeroSpace mode widgets update without extra workspace or focus commands in your AeroSpace config. EasyBar subscribes to all AeroSpace event types, applies latency-sensitive focus state immediately, and reconciles it with AeroSpace snapshots.

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

AeroSpace sends the current state immediately when the stream connects, and EasyBar uses that initial event as a sync signal. Focus changes run one focused-window query immediately, then schedule a complete snapshot with a 120 ms trailing debounce. Focused-workspace events apply their `workspace` value to the existing Spaces model immediately and start a complete snapshot for reconciliation. Focused-monitor changes also start a complete snapshot immediately. Other event bursts share the 120 ms trailing snapshot debounce.

EasyBar does not spawn the `aerospace subscribe` CLI process. While an AeroSpace-backed widget is active, EasyBar keeps scheduling reconnect attempts with bounded backoff even when the socket is temporarily absent. Each connect, handshake, and subscription request has a finite startup deadline, so launching EasyBar before AeroSpace or restarting AeroSpace later recovers without blocking the UI or restarting EasyBar.

EasyBar uses focused-workspace event metadata for an immediate visual update, but the source of truth remains the snapshot loaded from `aerospace list-workspaces --json` and `aerospace list-windows --json`. A failed fast focused-window query keeps the previous focus until the complete snapshot reconciles it.

The currently supported AeroSpace subscription events are:

- `focus-changed`
- `focused-monitor-changed`
- `focused-workspace-changed`
- `mode-changed`
- `window-detected`
- `binding-triggered`

`mode-changed` is AeroSpace binding-mode state, for example `main` or `service`. It is not the focused window's layout mode. EasyBar therefore uses it as a refresh trigger but does not forward it as EasyBar's layout-mode event.

Focus and workspace events are forwarded into the EasyBar event system for Lua widgets that subscribe to those driver events.

## AeroSpace config

EasyBar updates AeroSpace-backed widgets from its automatic socket subscription, so no EasyBar commands are required in your AeroSpace config for normal updates. Refreshed state is delivered directly to the registered native widgets through typed in-process callbacks.

EasyBar listens to `binding-triggered` and includes it in the trailing snapshot debounce, so separate layout commands are not needed either.

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
