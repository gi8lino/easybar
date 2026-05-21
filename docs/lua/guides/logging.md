# Logging

Lua widgets can write structured logs through `easybar.log(...)`.

Use the exported log level constants:

- `easybar.level.trace`
- `easybar.level.debug`
- `easybar.level.info`
- `easybar.level.warn`
- `easybar.level.error`

## Example

```lua
easybar.log(easybar.level.info, "refreshing widget")
easybar.log(easybar.level.debug, "current value", 42)
easybar.log(easybar.level.trace, "raw payload", payload)
```

## Host filtering

The Swift host decides which logs are emitted based on the configured host log level.

For example:

- `logging.level = "info"` shows info, warnings, and errors
- `logging.level = "debug"` also shows debug logs
- `logging.level = "trace"` also shows trace logs

## Recommended usage

Use:

- `trace` for very verbose raw payloads
- `debug` for state transitions and values
- `info` for important widget lifecycle events
- `warn` for recoverable command or parsing failures
- `error` for failures that prevent the widget from working
