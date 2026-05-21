# Debugging the Lua Runtime

Use this page when Lua widgets fail to load, stop updating, or behave unexpectedly.

## Check Lua logs

Inspect the normal EasyBar logs and look for messages such as:

```text
lua[widget.lua] ...
lua[runtime] ...
```

For deeper runtime debugging, temporarily raise the host logging level to:

```toml
[logging]
enabled = true
level = "trace"
```

## Run Lua manually

```bash
lua Sources/EasyBar/Lua/runtime.lua <widget_dir>
```

That direct invocation is still useful for Lua-only debugging, but it bypasses the dedicated socket transport used by the app.

The full app path is:

- Swift listens on `app.lua_socket_path`
- `EasyBarLuaRuntime` connects that socket
- Lua reads and writes through the attached standard streams

## Verify subscriptions

Look for the `subscriptions` message after startup.

## Inspect JSON traffic

- Lua socket carries events and trees.
- stderr carries logs.

## Common issues

### Widgets not updating

- missing `node:subscribe(...)`
- event not emitted
- node handle not stored before calling `render()`

### No UI output

- no `ready` message
- render failure
- widget file failed to load

### Duplicate updates

- repeated subscriptions
- duplicate widget files
- deduplication issue

### High CPU usage

- aggressive `interval`
- frequent `second_tick` usage
- expensive shell commands in sync `easybar.exec(...)`
