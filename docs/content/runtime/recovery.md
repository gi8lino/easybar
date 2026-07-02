# Recovery

Use this page when EasyBar is stuck, stale, or behaving unexpectedly.

For detailed helper-agent process checks, socket probes, permission debugging, and raw agent output inspection, see [Debugging Agents](../internals/agents/debugging.md).

## Calendar widget is empty

Make sure the calendar agent is enabled and running, then grant Calendar access in macOS settings.

EasyBar exposes menu actions to open the relevant settings pages, and the calendar agent permission state is shown in the bar context menu.

If you changed permissions and nothing updates, restart the calendar agent and EasyBar:

```bash
brew services restart gi8lino/tap/easybar-calendar-agent
brew services restart gi8lino/tap/easybar
```

For deeper checks, including socket pings and logs, use [Debugging Agents](../internals/agents/debugging.md).

## Wi-Fi or network widget is empty

Make sure the network agent is enabled and running.

The network agent depends on Location Services permission. If permission is denied or unresolved, Wi-Fi-specific fields may be unavailable by design.

Restart the network agent and EasyBar after changing permission settings:

```bash
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

For deeper checks, including raw Wi-Fi and network field inspection, use [Debugging Agents](../internals/agents/debugging.md).

## AeroSpace widgets do not update

First check that AeroSpace is supported by your EasyBar version. EasyBar v0.4.0 and newer require AeroSpace 0.21.0 or newer and no longer fall back to text-output parsing. EasyBar v0.3.0 was the last release with legacy text-output support.

```bash
aerospace --version
```

Both the CLI client and the running AeroSpace.app server should be at least 0.21.0. If the versions differ after updating, restart AeroSpace.app.

EasyBar normally updates AeroSpace widgets from a long-lived `aerospace subscribe --all` stream. Workspace and focus callbacks are no longer required for normal updates.

The old `easybar --workspace-changed` and `easybar --focus-changed` commands still work as legacy fallback hooks, but you should not need to wire them into AeroSpace for ordinary use.

Raise EasyBar logging to debug and look for subscription lifecycle messages:

```toml
[logging]
enabled = true
level = "debug"
```

Useful messages include `aerospace subscription started`, `aerospace subscription event received`, `aerospace subscription exited`, and `aerospace subscription reconnect scheduled`.

If AeroSpace is restarted or updated while EasyBar is running, EasyBar reconnects to the subscription stream with bounded backoff as long as the `aerospace` executable is still available.

If your AeroSpace mode widget does not change after switching layouts, call EasyBar after every relevant `layout ...` command:

```toml
alt-e = [
  'layout tiles horizontal',
  'exec-and-forget /opt/homebrew/bin/easybar --space-mode-changed'
]
```

That layout callback is optional. It is useful because AeroSpace does not expose a dedicated layout-changed subscription event.

You can trigger one manually with:

```bash
easybar --refresh
```

## Spaces widget misses an app launch or quit

The built-in spaces widget refreshes AeroSpace-derived state from a mix of `aerospace subscribe --all` events and macOS app lifecycle notifications.

App quits are also refreshed from macOS termination notifications.

App launches use a short delayed refresh so background apps such as Docker have a chance to create their first window before EasyBar asks AeroSpace for `list-windows`.

If icons still look stale after a launch, trigger a manual refresh once:

```bash
easybar --refresh
```

## Config changes do not apply

If `watch_config = false`, EasyBar will not automatically reload config changes.

Either enable config watching or reload manually:

```bash
easybar --reload-config
```

If a reload is rejected, EasyBar keeps the last valid config and logs the parse or validation error. Check the logs instead of assuming the new file was accepted.

## Lua widgets stop updating

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

## Full reset

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
