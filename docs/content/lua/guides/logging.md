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

## Prefixed widget logs

For widgets that repeatedly use the same grep-friendly prefix, create a prefixed logger once:

```lua
local log = easybar.log.with_prefix("[brew_outdated]")

log(easybar.level.debug, "checking outdated packages")
log(easybar.level.warn, "brew update failed", "code=" .. tostring(code))
```

This is equivalent to calling `easybar.log(...)` with the prefix as the first message part, but avoids repeating it at every call site.

## File-backed widget logs

For widgets that need a separate operation log, create a file-backed logger once:

```lua
local log = easybar.log.with_file("brew-widget.log", {
    prefix = "[brew_outdated]",
})
```

The returned logger is callable, so it keeps the same style as `easybar.log(...)`:

```lua
log(easybar.level.debug, "checking outdated packages")
```

It writes to the normal EasyBar host log and appends a line to the widget log file. The file is always created inside `easybar.log_dir`; pass only a plain file name, not a path.

Use `append`, `tail`, and `trim` for command output logs:

```lua
log.append("$ brew update")
log.append(output)
local recent = log.tail(80)
log.trim(4000)
```

`append` is useful for raw command output. `tail` is useful for showing recent failure context in a popup. `trim` keeps long-running widget logs bounded.

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
