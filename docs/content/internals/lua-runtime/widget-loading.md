# Widget Loading

Bootstrap begins in `runtime.lua`.

## Flow

1. resolve widget directory
2. load runtime modules
3. call `loader.load_widgets(...)`

Inside `loader.lua`:

1. list `*.lua` files
2. sort deterministically
3. create isolated environment per file
4. inject scoped `easybar` API
5. execute file

## Important details

- each widget has isolated defaults
- all widgets share one runtime registry
- every `*.lua` file in the widget directory is loaded
- reload is a full reset
- widget environments fall back to `_G`, so isolation is about local state, not security

## Trust model

EasyBar widget files are trusted local scripts.

`loader.lua` gives each file its own table so widget-local variables and defaults do not leak into
other widget files, but that table uses `_G` as a fallback. In practice that means widgets still
have broad access to standard Lua globals and whatever the host process exposes through the normal
Lua environment.

This is not a sandbox. Do not treat third-party widget files as untrusted code.

## Public widget API shape

Lua widget authors use node handles.

`easybar.add(...)` creates one node and returns its handle:

```lua
local clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    label = os.date("%H:%M"),
})
```

The returned handle owns node operations:

- `node.id`
- `node.name`
- `node:set(props)`
- `node:get()`
- `node:remove()`
- `node:subscribe(events, handler)`

Example:

```lua
clock:subscribe(easybar.events.minute_tick, function()
    clock:set({
        label = os.date("%H:%M"),
    })
end)
```

Internally, `api.lua` still delegates to the registry and subscription modules by id.

The id-based functions are internal implementation details, not the public widget-author API.
