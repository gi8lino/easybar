# Runtime Control

EasyBar exposes three runtime control actions because they solve different problems.

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

These commands send an acknowledged restart request directly to the selected agent socket. The agent exits after replying, and the packaged EasyBar supervisor starts it again. The combined command attempts both agents and returns a nonzero status with partial-failure details if either request fails.

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
