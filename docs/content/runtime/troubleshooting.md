# Troubleshooting

When something is wrong, first check whether EasyBar and its helper agents are running, whether duplicate processes exist, and whether the logs show a startup warning.

For agent-specific socket checks, permission issues, raw Wi-Fi or calendar data checks, and agent logs, use [Debugging Agents](../internals/agents/debugging.md).

## Quick checks

Check that EasyBar is running:

```bash
pgrep -fl EasyBar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl EasyBarCalendarAgent
pgrep -fl EasyBarNetworkAgent
```

Check that only one main EasyBar process is running.

EasyBar refuses to start when another instance already holds its lock, but duplicate service or manual launches are still the first thing to rule out.

Check the control socket with the CLI:

```bash
easybar --refresh
```

If that fails, EasyBar may not be running, may have been blocked by macOS, or may have failed during startup.

## Logs

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

For agent-specific log commands, see [Debugging Agents](../internals/agents/debugging.md).

For very verbose app and agent troubleshooting, temporarily raise the level to `trace`:

```toml
[logging]
enabled = true
level = "trace"
```

## EasyBar does not appear

Check whether the app is running:

```bash
pgrep -fl EasyBar
```

Try launching the app directly:

```bash
open -a EasyBar
```

If EasyBar appears but a helper is unavailable, restart the helpers:

```bash
easybar --restart-agents
```

If nothing appears, check logs for startup warnings, macOS permission issues, or quarantine problems.

## Another instance is already running

EasyBar uses a single-instance guard. If a second instance starts, it logs a warning and exits.

Detect duplicates with:

```bash
pgrep -fl EasyBar
```

If you accidentally launched more than one app instance, stop and reopen EasyBar:

```bash
pkill -x EasyBar
open -a EasyBar
```

If you are testing local builds from `dist/`, quit the installed app first so you do not mix installed and development runs.

## Related pages

- [Recovery](recovery.md)
- [Debugging Agents](../internals/agents/debugging.md)
- [macOS Quarantine](../getting-started/macos-quarantine.md)
- [Configuration Logging](../configuration/logging.md)
