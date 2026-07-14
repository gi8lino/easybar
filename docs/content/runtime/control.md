# Runtime Control

EasyBar exposes three runtime control actions because they solve different problems.

## Menu bar controller

EasyBar shows a persistent controller icon in the macOS menu bar by default. It remains available when the EasyBar bar itself is stopped, so you can restore the bar without opening a terminal.

The controller menu provides:

- start, stop, and restart EasyBar's bar runtime
- refresh and config reload
- Lua runtime restart
- calendar and network agent status and restart actions
- shortcuts to the config, widgets, and log directories
- complete application shutdown

The version shown at the top of the menu is the version embedded in the running EasyBar binary.

Disable the controller icon when you do not want an additional macOS menu bar item:

```toml
[app]
show_menu_bar_icon = false
```

The setting defaults to `true`. After disabling it, restart the application through Finder, Spotlight, or the command line when necessary:

```bash
pkill -x EasyBar
open -a EasyBar
```

## Refresh

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

## Restart Lua runtime

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

## Reload config

Use:

```bash
easybar --reload-config
```

This:

- reloads `config.toml` from disk
- rebuilds EasyBar using the new config
- reapplies native widgets and Lua runtime state against the updated configuration

Use this when you changed the config file itself.

## Restart helper agents

```bash
easybar --restart-calendar-agent
easybar --restart-network-agent
easybar --restart-agents
```

These commands send an acknowledged restart request directly to the selected agent socket. The agent exits after replying, and its Homebrew keep-alive service starts it again. The combined command attempts both agents and returns a nonzero status with partial-failure details if either request fails.

`--socket <path>` can override one per-agent socket. It is not accepted with `--restart-agents`, because the agents use different sockets.

## Scripting events

Use:

```bash
easybar --event workspace_change
easybar --event focus_change
easybar --event space_mode_change
```

This emits an EasyBar driver event for Lua widgets and refreshes the current bar state.

Use this from local scripts when an external action should notify widgets that workspace, focus, or layout-related state may have changed.

## Related pages

- [Metrics](metrics.md)
- [Troubleshooting](troubleshooting.md)
- [Control Socket](../internals/architecture/control-socket.md)
