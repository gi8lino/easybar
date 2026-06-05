# Lua Runtime Logging

Lua logs go to stderr.

Only the structured runtime protocol moved to the dedicated Lua socket.

## Structured format

```text
EASYBAR_LUA_LOG\t<level>\t<context>\tmessage
```

## Public Lua log levels

Valid public Lua log levels are:

- `easybar.level.trace`
- `easybar.level.debug`
- `easybar.level.info`
- `easybar.level.warn`
- `easybar.level.error`

These resolve to the lowercase scripting values used by `easybar.log(...)`.

## Examples

```lua
easybar.log(easybar.level.info, "refreshing widget")
easybar.log(easybar.level.debug, "current value", 42)
easybar.log(easybar.level.trace, "raw payload", payload)
```

`LuaLogBridge.swift` is the translation boundary that maps Lua log levels into the Swift host logger.

That means:

- Lua widgets should log using the public Lua API values.
- Swift remains the canonical implementation of filtering and output behavior.
