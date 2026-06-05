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

## Spaces widget misses an app launch or quit

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
