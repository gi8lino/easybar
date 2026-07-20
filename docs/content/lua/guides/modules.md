# Reusable Modules

Put shared Lua helpers below the `lib` directory inside your configured widgets directory.
EasyBar adds that directory to Lua's module search path before loading widget files, so widgets can
use standard `require(...)` calls without changing `package.path` themselves.

## Recommended layout

```text
~/.config/easybar/widgets/
├── clock.lua
├── github.lua
├── lib/
│   ├── retry.lua
│   ├── shell.lua
│   ├── text.lua
│   └── status/
│       └── init.lua
└── assets/
    └── github-mark.svg
```

Only regular `*.lua` files directly inside the widgets directory are started as widgets. Lua files
below `lib/` are modules and run only when a widget requires them.

## Create a module

A module normally returns one table containing its public functions:

```lua
-- ~/.config/easybar/widgets/lib/text.lua
local M = {}

function M.trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

return M
```

Use it from any top-level widget:

```lua
local text = require("text")

local value = text.trim("  ready  ")
```

EasyBar resolves that call from:

```text
<widgets_dir>/lib/text.lua
```

## Package directories

For a larger module, use an `init.lua` file:

```text
lib/
└── status/
    └── init.lua
```

Then load it with:

```lua
local status = require("status")
```

Dots in module names map to subdirectories. For example:

```lua
local format = require("network.format")
```

resolves to:

```text
<widgets_dir>/lib/network/format.lua
```

## Shared text and shell helpers

The repository's example widgets include two small user modules:

```lua
local shell = require("shell")
local text = require("text")

local clean = text.trim(command_output)
local short = text.truncate(clean, 80)
local command = "open " .. shell.quote(url)
```

`text.lua` provides:

- `text.trim(value)`
- `text.truncate(value, maximum_length, omission?)`

`shell.lua` provides:

- `shell.quote(value)` for one POSIX shell argument

These files are examples in the user widget directory, not built-in functions of the public
`easybar` API. You own them and can extend or replace them.

The bundled `retry.lua` module coordinates asynchronous attempts through `easybar.after(...)`. Pass
the widget-scoped API explicitly because modules do not receive `easybar` automatically:

```lua
local retry = require("retry")

retry.run(easybar, {
    delays = { 2, 5 },
    attempt = function(done, attempt_number)
        return easybar.spawn_async({ "gh", "api", "notifications" }, {}, done)
    end,
    should_retry = retry.is_transient_network_error,
    on_complete = function(output, code, attempts)
        -- Runs once with the final result.
    end,
})
```

The first attempt starts immediately. `delays[1]` is the wait before attempt 2, `delays[2]` is the
wait before attempt 3, and so on. When no delay remains, the last result is final.

`retry.run(...)` returns a `RetryOperation` with:

- `operation:is_active()`
- `operation:cancel()`

Store that handle only when the widget has an actual cancellation or replacement policy. The retry
callbacks and host timers keep the operation alive until completion, so assigning an unused
`active_refresh` variable adds dead state without changing behavior.

When you do store the handle, clear it in `on_complete` and before cancellation:

```lua
local active_refresh

local function cancel_refresh()
    local operation = active_refresh
    active_refresh = nil

    if operation ~= nil then
        operation:cancel()
    end
end
```

Cancellation stops either the active asynchronous command or the pending backoff timer and does not
call `on_complete`.

`retry.is_transient_network_error(output, code)` is a conservative heuristic for DNS, connection,
timeout, TLS, and common gateway failures. It never retries status `0` and never treats cancellation
status `130` as retryable. The retry helper is intended for idempotent reads. Do not automatically
retry updates, upgrades, acknowledgements, or other mutations because the remote operation may have
succeeded even when the local response was lost.

The module includes LuaLS annotations for `RetryOptions`, `RetryOperation`, attempt callbacks, retry
predicates, and completion callbacks. Keeping these annotations beside the implementation means
editors can validate custom retry policies without adding retry types to the global `easybar` stub.

## Module lifetime and state

Lua caches successful `require(...)` calls in `package.loaded`. Requiring the same module again in
the same runtime returns the same value without executing the module a second time.

That means mutable module state is shared by every widget that requires the module. Prefer stateless
helper modules unless shared state is intentional.

Restarting the Lua runtime or reloading EasyBar clears the process and therefore clears the module
cache.

## EasyBar API access

User modules are loaded by Lua's standard module system, not as widget entrypoints. They do not get
a widget-scoped `easybar` value injected automatically.

Keep general modules independent from EasyBar when possible. When a helper needs host-specific data,
pass the value explicitly:

```lua
-- lib/widget_style.lua
local M = {}

function M.label(color, value)
    return {
        string = value,
        color = color,
    }
end

return M
```

```lua
-- clock.lua
local widget_style = require("widget_style")

local label = widget_style.label(easybar.theme.ref.text, os.date("%H:%M"))
```

Resolve widget-relative files such as images in the widget itself with `easybar.asset(...)`, then
pass the resolved path to a helper only when needed.

## Naming and precedence

EasyBar prepends the widget `lib` paths to the existing Lua module search path. A user module can
therefore override an installed module with the same name.

Use specific module names or subdirectories for larger collections, and avoid names that are likely
to collide with third-party Lua packages.

## Errors

A missing or failing required module makes that widget fail during startup and writes the normal Lua
loader error to the EasyBar log. Other widget files continue loading.

A broken module that is never required is not executed.
