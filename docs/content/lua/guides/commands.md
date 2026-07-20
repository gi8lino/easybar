# Commands

EasyBar exposes bounded process-execution and scheduling helpers for Lua widgets.

Use commands carefully. Long-running synchronous commands block the Lua runtime. EasyBar enforces
host-side limits for command timeout, captured output size, and concurrent asynchronous jobs through
`[app.lua_commands]`.

## Synchronous commands

`easybar.exec(command, options?)` runs `/bin/sh -lc <command>` synchronously and returns combined
stdout and stderr plus the final status. EasyBar removes trailing newline characters but otherwise
preserves the captured output.

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

Use this only for fast, local commands. The Lua runtime cannot dispatch widget events or callbacks
while a synchronous command is running.

## Asynchronous shell commands

`easybar.exec_async(command, options, callback)` runs `/bin/sh -lc <command>` in the background and
calls back exactly once with combined output and the final status.

Use it for commands that genuinely require shell behavior such as:

- pipes and redirection
- command substitution or wildcard expansion
- compound shell scripts
- background work that should not block other widgets

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

## Command options

All command APIs accept the same optional limits:

- `timeout_seconds`
- `max_output_bytes`

Both values must be greater than zero, and `max_output_bytes` must be an integer. Pass `nil` or `{}`
when you want the global defaults from `[app.lua_commands]`. Use
`easybar.DEFAULT_EXEC_OPTIONS` when you want to pass the current configured host defaults explicitly.

## Output and status codes

All command APIs combine stdout and stderr into one bounded output string. Trailing newline
characters are removed before Lua receives the result.

Normal executable exit codes are preserved. EasyBar reserves these statuses for host-side outcomes:

| Status | Meaning                                                                        |
| ------ | ------------------------------------------------------------------------------ |
| `65`   | Captured output exceeded `max_output_bytes`; the process group was terminated. |
| `124`  | The command exceeded `timeout_seconds`; the process group was terminated.      |
| `127`  | The requested executable could not be found.                                   |
| `130`  | Cancellation was requested and the process group was terminated.               |

Treat every non-zero status as failure unless the specific executable documents another meaning.

## Direct executable commands

Prefer `easybar.spawn_async(arguments, options, callback)` when you are invoking one executable and
do not need shell syntax. EasyBar passes each argument directly to the process, so spaces, dollar
signs, semicolons, and other shell characters are literal argument content.

```lua
easybar.spawn_async({
    "gh",
    "api",
    "--paginate",
    "notifications?all=false&per_page=100",
}, { timeout_seconds = 20 }, function(output, code)
    -- Handle the final process result.
end)
```

The argument table must be a dense array of strings. The first element is the executable name or
path. Empty executable names, sparse arrays, non-string arguments, and NUL bytes are rejected before
the host process starts.

The executable is resolved through the `PATH` from `[app.env]`. Use `/usr/bin/env` as the executable
when one command needs additional environment values without invoking a shell:

```lua
easybar.spawn_async({
    "/usr/bin/env",
    "GLAB_NO_PROMPT=1",
    "glab",
    "api",
    "issues?scope=assigned_to_me",
}, {}, callback)
```

Both asynchronous APIs return a token accepted by `easybar.cancel_async(...)` and use the same
command limits.

## Cancelling asynchronous commands

`easybar.exec_async(...)` and `easybar.spawn_async(...)` return a job token. Pass that token to
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

Restore the widget's idle state from the async callback because the cancellation request is
asynchronous. Whether to refresh data afterwards is up to the widget. If the last known data remains
useful, keep it and render the normal action again.

`easybar.cancel_async(token)` returns `true` when the token still identifies a pending command and
the cancellation request was sent. It returns `false` when the command already completed or the
token is unknown. The return value confirms the request, not that the process has already exited.

Cancellation first asks the command's complete process group to terminate, so child processes stop
with the requested executable or shell command. EasyBar forcibly stops processes that do not exit
during the grace period. The original callback then receives status `130` and any output captured
before cancellation.

Command tokens belong to the current Lua runtime session. Keep them only while the corresponding job
is active, and do not persist them across config reloads or application restarts. Synchronous
commands started with `easybar.exec(...)` cannot be cancelled this way.

## Delayed callbacks

`easybar.after(delay_seconds, callback)` schedules a host-owned one-shot timer. It does not launch
`sleep`, consume an asynchronous command slot, or block the Lua runtime.

```lua
local pending_refresh

pending_refresh = easybar.after(3, function()
    pending_refresh = nil
    refresh()
end)
```

The delay must be finite and non-negative. A delay of zero still schedules the callback
asynchronously; the callback does not run before `easybar.after(...)` returns.

Cancel a callback that is no longer useful:

```lua
if pending_refresh ~= nil then
    pending_refresh:cancel()
    pending_refresh = nil
end
```

`timer:cancel()` returns `true` only when the callback was still pending. It returns `false` after the
timer fired or was already cancelled. Timer handles belong to the current Lua runtime session and
should not be persisted across reloads.

## Environment

Commands run with the environment configured under `[app.env]`.

For GUI-launched EasyBar sessions, configure `PATH` explicitly:

```toml
[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
```

This avoids relying on `.zshrc` or other shell startup files.
