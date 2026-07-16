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

## Cancelling asynchronous commands

`easybar.exec_async(...)` returns a job token. Pass that token to
`easybar.cancel_async(token)` when the command should stop:

```lua
local active_job

active_job = easybar.exec_async("long-running-command", {}, function(output, code)
    active_job = nil

    if code == 130 then
        easybar.log(easybar.level.info, "command cancelled")
        return
    end

    if code ~= 0 then
        easybar.log(easybar.level.warn, "command failed", code, output)
    end
end)

local cancellation_requested = easybar.cancel_async(active_job)
```

Restore the widget's idle state from the async callback, because the cancellation request is
asynchronous. Whether to refresh data afterwards is up to the widget. If the last known data is
still useful, keep it and render the normal action again:

```lua
local running = false
local active_job

local function render()
    action:set({ label = running and "Cancel" or "Update" })
end

local function start_update()
    running = true
    render()

    active_job = easybar.exec_async("long-running-update", {}, function(output, code)
        active_job = nil
        running = false

        if code ~= 0 and code ~= 130 then
            easybar.log(easybar.level.warn, "update failed", code, output)
        end

        render()
    end)
end
```

Do not start a follow-up check merely to finish cancellation unless the cancelled command may
have changed the data you display. A separate refresh produces an additional busy state after the
user has already asked the operation to stop.

`easybar.cancel_async(token)` returns `true` when the token still identifies a pending command and
the cancellation request was sent. It returns `false` when the command already completed or the
token is unknown. The return value confirms the request, not that the process has already exited.

Cancellation first asks the command's complete process group to terminate, so child processes are
stopped along with the shell command. EasyBar forcibly stops processes that do not exit during the
grace period. The original callback runs after termination and receives exit code `130`; `output`
contains anything captured before cancellation.

Command tokens belong to the current Lua runtime session. Keep them only while the corresponding
job is active, and do not persist them across config reloads or application restarts. Synchronous
commands started with `easybar.exec(...)` cannot be cancelled this way.

## Environment

Commands run with the environment configured under `[app.env]`.

For GUI-launched EasyBar sessions, configure `PATH` explicitly:

```toml
[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

This avoids relying on `.zshrc` or other shell startup files.
