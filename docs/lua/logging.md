# Lua Logging

Widgets log through `easybar.log(level, ...)`.

Use the exported level constants:

- `easybar.level.trace`
- `easybar.level.debug`
- `easybar.level.info`
- `easybar.level.warn`
- `easybar.level.error`

## Examples

```lua
easybar.log(easybar.level.info, "refreshing widget")
easybar.log(easybar.level.debug, "current value", 42)
easybar.log(easybar.level.trace, "raw payload", payload)
```

These are the public Lua logging levels.

The Swift host decides which logs are actually emitted based on the configured host logging level.

## Host level behavior

For example:

- host `logging.level = "info"` shows `info`, `warn`, and `error`
- host `logging.level = "debug"` also shows `debug`
- host `logging.level = "trace"` also shows `trace`

## `easybar.level`

`easybar.level` exposes the supported log level constants for `easybar.log(...)`.

Example:

```lua
easybar.log(easybar.level.warn, "vpn toggle skipped")
```

See [Configuration Logging](../configuration/logging.md) for host-side logging configuration.
