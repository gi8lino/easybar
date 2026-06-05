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

The main app and helper agents use this config-driven level. Logging is configured in `config.toml`; there are no separate logging environment toggles.

`EASYBAR_CONFIG_PATH` remains the only public environment override for selecting the runtime config file.

The `easybar` CLI can enable its own debug output explicitly with `--debug`. This does not change the main app or agent log level.

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


