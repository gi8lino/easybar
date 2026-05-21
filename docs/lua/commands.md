# Commands

Lua widgets can run shell commands.

Use async commands for anything that could block.

## `easybar.exec(command, callback)`

Runs a shell command synchronously inside the Lua runtime.

Use this for quick commands only. Long-running commands block the widget runtime until the command exits.

```lua
easybar.exec("date +%H:%M", function(output)
    clock:set({
        label = {
            string = output,
        },
    })
end)
```

## `easybar.exec_async(command, callback)`

Runs a shell command in the background and calls back later with the trimmed output and numeric exit code.

This is the preferred API for package managers, network requests, and other work that should not block popup interaction or other widget updates.

```lua
easybar.exec_async("brew outdated --json=v2", function(output, code)
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

## Environment

Commands inherit the environment configured under `[app.env]`.

See [Environment](../configuration/environment.md).
