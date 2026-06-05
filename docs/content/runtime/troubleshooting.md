# Troubleshooting

When something is wrong, first check whether EasyBar and its helper agents are running, whether duplicate processes exist, and whether the logs show a startup warning.

For agent-specific socket checks, permission issues, raw Wi-Fi or calendar data checks, and Homebrew agent logs, use [Debugging Agents](../internals/agents/debugging.md).

## Quick checks

Check Homebrew services:

```bash
brew services list | grep easybar
```

Check running processes:

```bash
pgrep -fl EasyBar
pgrep -fl easybar-calendar-agent
pgrep -fl easybar-network-agent
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

For Homebrew service log locations and agent-specific log commands, see [Debugging Agents](../internals/agents/debugging.md).

For very verbose app and agent troubleshooting, temporarily raise the level to `trace`:

```toml
[logging]
enabled = true
level = "trace"
```

## EasyBar does not appear

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

## Another instance is already running

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

## Related pages

- [Recovery](recovery.md)
- [Debugging Agents](../internals/agents/debugging.md)
- [macOS Quarantine](../getting-started/macos-quarantine.md)
- [Configuration Logging](../configuration/logging.md)
