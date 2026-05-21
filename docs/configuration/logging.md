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

The main app and helper agents use this config-driven level instead of legacy `EASYBAR_DEBUG` or `EASYBAR_TRACE` environment toggles.

`EASYBAR_CONFIG_PATH` remains the main environment override for the runtime config file.

The `easybar` CLI may still support its own debug flag or CLI-only debug env handling, but that is separate from app and agent runtime logging.

## CLI debug output

The `easybar` CLI can enable debug output independently through:

```bash
easybar --debug
EASYBAR_DEBUG=1 easybar ...
```

This CLI-only behavior does not change the main app or agent log level.
