# Commands

EasyBar exposes shell command helpers for Lua widgets.

Use commands carefully. Long-running synchronous commands block the Lua runtime.
EasyBar also enforces configurable host-side limits for command timeout, captured output size,
and concurrent async jobs through `[app.lua_commands]`.

## Synchronous commands

`easybar.exec(command, options?)` runs a command synchronously and returns output plus exit code.

```lua
local output, code = easybar.exec("date +%H:%M", easybar.DEFAULT_EXEC_OPTIONS)

if code == 0 then
    clock:set({
        label = {
            string = output,
        },
    })
end
```

Use this only for fast commands.

## Asynchronous commands

`easybar.exec_async(command, options, callback)` runs a command in the background and calls back later with output and exit code.

This is preferred for:

- package managers
- network requests
- slow scripts
- commands used by popup buttons
- anything that should not block other widgets

```lua
easybar.exec_async("brew outdated --json=v2", {
    timeout_seconds = 15,
}, function(output, code)
    if code ~= 0 then
        easybar.log(easybar.level.warn, "brew failed", code, output)
        return
    end

    brew_status:set({
        label = {
            string = output,
        },
    })
end)
```

`options` accepts:

- `timeout_seconds`
- `max_output_bytes`

Leave `options` as `{}` when you want the global defaults from `[app.lua_commands]`.
Use `easybar.DEFAULT_EXEC_OPTIONS` when you want to reference the current configured host defaults directly.

## Environment

Commands run with the environment configured under `[app.env]`.

For GUI-launched EasyBar sessions, configure `PATH` explicitly:

```toml
[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

This avoids relying on `.zshrc` or other shell startup files.
