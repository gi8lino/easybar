# Logging

EasyBar uses one shared log directory for the main app and helper agents.

When file logging is enabled, EasyBar writes:

- `easybar.out`
- `calendar-agent.out`
- `network-agent.out`

## Config

```toml
[logging]
enabled = true
level = "info"
directory = "~/.local/state/easybar"
```

## Logging control

| Setting | Config key | Environment override |
| ------- | ---------- | -------------------- |
| File logging | `logging.enabled` | none |
| Minimum log level | `logging.level` | `EASYBAR_LOG_LEVEL` |
| Log directory | `logging.directory` | none |

Only the minimum log level has an environment override. File logging and the log directory stay config-only so the app, agents, and docs all share one explicit logging contract.

## Supported levels

- `trace`
- `debug`
- `info`
- `warn`
- `error`

## Level meaning

- `trace`
  Info, debug, warnings, errors, and very verbose trace logs.
- `debug`
  Info plus debug logs.
- `info`
  Normal runtime logs.
- `warn`
  Warnings and errors only.
- `error`
  Error logs only.

## Notes

The main app and helper agents use the shared logging config from `config.toml`.

`logging.enabled` and `logging.directory` are config-only settings. They are not controlled by environment variables.

`EASYBAR_LOG_LEVEL` is the only logging environment override. It temporarily overrides `logging.level` for diagnostics, for example in local `make run-debug` or service troubleshooting sessions.

`EASYBAR_CONFIG_PATH` remains the public environment override for selecting the runtime config file.

The `easybar` CLI can enable its own debug output explicitly with `--debug`. This does not change the main app or agent log level.

## Temporary log-level override

Use `EASYBAR_LOG_LEVEL` when you want more or less verbose logs without editing `config.toml`:

```bash
EASYBAR_LOG_LEVEL=debug easybar --refresh
EASYBAR_LOG_LEVEL=trace open /Applications/EasyBar.app
```

This override affects only the minimum log level. File logging still depends on `logging.enabled` and `logging.directory` from `config.toml`.

## CLI debug output

Use `--debug` when you want CLI-side diagnostics:

```bash
easybar --debug --metrics
easybar --debug --validate-config --config /path/to/config.toml
```

This keeps validation explicit:

```bash
easybar --validate-config --config /path/to/config.toml
```

or:

```bash
EASYBAR_CONFIG_PATH=/path/to/config.toml easybar --validate-config
```
