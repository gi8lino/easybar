# Lua API

The public Lua API is centered around node handles.

## `easybar.add(kind, id, props)`

Creates one node and returns a node handle.

Kinds:

- `item`
- `row`
- `column`
- `group`
- `popup`
- `slider`
- `progress`
- `progress_slider`
- `sparkline`
- `spaces`

The returned handle has:

- `node.id`
- `node.name`
- `node:set(props)`
- `node:get()`
- `node:remove()`
- `node:subscribe(events, handler)`

`node.name` is an alias for the node id and is useful when assigning parents or popup positions.

Example:

```lua
local clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    icon = {
        string = "🕒",
    },
    label = {
        string = "00:00",
    },
})
```

Minimal icon-only widget:

```lua
local vpn = easybar.add(easybar.kind.item, "vpn", {
    position = "right",
    order = 20,
    icon = {
        image = "/path/to/vpn.png",
        image_size = 16,
    },
})
```

## `node:set(props)`

Updates one node.

```lua
clock:set({
    label = {
        string = os.date("%H:%M"),
    },
})
```

## `node:remove()`

Removes one node and its children.

```lua
clock:remove()
```

## `node:get()`

Returns the current property table.

```lua
local props = clock:get()
```

## `easybar.default(props)`

Sets defaults for future `easybar.add(...)` calls.

Defaults are scoped to the current widget file only. This is useful for shared child styling or per-widget tweaks.

```lua
easybar.default({
    label = {
        color = "#cad3f5",
    },
})
```

## `easybar.clear_defaults()`

Clears all defaults.

```lua
easybar.clear_defaults()
```

## `easybar.json`

Encodes Lua values to JSON strings and decodes JSON strings back into Lua values.

Use this instead of reaching into bundled runtime modules directly.

```lua
local payload = easybar.json.decode('{"name":"brew","count":2}')

easybar.log(easybar.level.debug, payload.name, payload.count)
```

Available helpers:

- `easybar.json.encode(value)`
- `easybar.json.decode(text)`
