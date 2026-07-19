# CLI Reference

The `easybar` command controls the running app, validates configuration, restarts helper agents, and exposes diagnostics. Most commands contact a Unix-domain socket, so the relevant process must be running.

## Runtime commands

| Command                         | Purpose                                                                       |
| ------------------------------- | ----------------------------------------------------------------------------- |
| `easybar --refresh`             | Refresh the bar, widgets, and agent-backed data without reloading config.     |
| `easybar --reload-config`       | Read `config.toml` again and rebuild the current bar.                         |
| `easybar --restart-lua-runtime` | Restart only the Lua widget runtime using the currently loaded configuration. |
| `easybar --metrics`             | Print one runtime metrics snapshot.                                           |
| `easybar --metrics --watch`     | Continuously display runtime metrics and rolling graphs.                      |

See [Runtime Control](control.md) for the difference between refresh, reload, and restart operations. See [Metrics](metrics.md) for the fields included in a snapshot.

## Helper-agent commands

| Command                            | Purpose                                            |
| ---------------------------------- | -------------------------------------------------- |
| `easybar --restart-calendar-agent` | Restart the calendar agent through its socket.     |
| `easybar --restart-network-agent`  | Restart the network agent through its socket.      |
| `easybar --restart-agents`         | Attempt both restarts and report partial failures. |

The agent acknowledges its restart request before exiting. Its Homebrew keep-alive service then launches it again. `--socket` can override one per-agent socket, but cannot be combined with `--restart-agents` because the agents use different sockets.

## Configuration validation

Validate the active configuration through the running app:

```bash
easybar --validate-config
```

Validate another file:

```bash
easybar --validate-config --config /path/to/config.toml
```

`EASYBAR_CONFIG_PATH` can select the file instead. A rejected live reload leaves the last valid configuration active.

## Scripting events

```bash
easybar --event workspace_change
easybar --event focus_change
easybar --event space_mode_change
```

Hyphens and underscores are accepted in event names. These commands emit driver events for Lua widgets and refresh the corresponding current state.

## General options

| Option                | Purpose                                                        |
| --------------------- | -------------------------------------------------------------- |
| `--socket PATH`, `-s` | Override the socket contacted by the selected operation.       |
| `--config PATH`       | Select a configuration file for `--validate-config`.           |
| `--debug`, `-d`       | Print CLI-side diagnostics; it does not change app log levels. |
| `--watch`, `-w`       | Keep streaming metrics; use with `--metrics`.                  |
| `--version`, `-v`     | Print the installed CLI version.                               |
| `--help`, `-h`        | Print command usage.                                           |

The CLI and running app versions should normally match after a Homebrew upgrade:

```bash
easybar --version
/Applications/EasyBar.app/Contents/MacOS/EasyBar --version
```

## Related pages

- [Runtime Control](control.md)
- [Metrics](metrics.md)
- [Logging](../configuration/logging.md)
- [Environment](../configuration/environment.md)
- [Control Socket Internals](../internals/architecture/control-socket.md)
