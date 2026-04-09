# EasyBar Lua widgets

EasyBar Lua widgets are item-based.

You do not return widget trees.
You create items, style them, and update them by id.

Interaction is node-based.

- subscribe on a node id: that node owns hover, click, scroll, and popup behavior
- the subscribed node frame is the interactive surface
- use smaller child nodes when only part of a widget should be interactive
- use `group` when multiple child nodes should share one styled container

## Editor support

EasyBar installs a bundled LuaLS stub into:

- `~/.local/share/easybar/easybar_api.lua`

If your editor uses LuaLS, add a `.luarc.json` in the workspace where you edit widgets.

That gives you:

- no `unknown global 'easybar'` warning
- hover documentation
- basic autocomplete for the `easybar` API

Suggested setup:

1. start EasyBar once so it installs `~/.local/share/easybar/easybar_api.lua`
2. add `~/.config/easybar/widgets/.luarc.json`
3. open `~/.config/easybar/widgets` or `~/.config` as your editor workspace

Example `.luarc.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
  "runtime": {
    "version": "Lua 5.4"
  },
  "workspace": {
    "library": ["~/.local/share/easybar/easybar_api.lua"]
  },
  "diagnostics": {
    "globals": ["easybar"]
  }
}
```

## API

### `easybar.add(kind, id, props)`

Creates one item.

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

`group` is the right container when you want:

- a shared background
- shared padding
- shared popup ownership
- parent-level interaction around multiple child items

Example:

```lua
easybar.add("item", "clock", {
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

### `easybar.set(id, props)`

Updates one item.

```lua
easybar.set("clock", {
    label = {
        string = os.date("%H:%M"),
    },
})
```

### `easybar.remove(id)`

Removes one item and its children.

```lua
easybar.remove("clock")
```

### `easybar.get(id)`

Returns the current property table.

```lua
local props = easybar.get("clock")
```

### `easybar.default(props)`

Sets defaults for future `easybar.add(...)` calls.

Useful for shared styling.

```lua
easybar.default({
    background = {
        padding_left = 8,
        padding_right = 8,
        padding_top = 4,
        padding_bottom = 4,
    },
    label = {
        color = "#cad3f5",
    },
})
```

### `easybar.clear_defaults()`

Clears all defaults.

```lua
easybar.clear_defaults()
```

### `easybar.subscribe(id, events, handler)`

Subscribes one item to one or more events.

```lua
easybar.subscribe("clock", { easybar.events.minute_tick, easybar.events.forced }, function(event)
    easybar.set("clock", {
        label = {
            string = os.date("%H:%M"),
        },
    })
end)
```

Event fields include:

- `event.name`
- `event.widget_id`
- `event.target_widget_id`
- `event.app_name`
- `event.button`
- `event.direction`
- `event.value`
- `event.delta_x`
- `event.delta_y`

Common events:

- `easybar.events.forced`
- `easybar.events.system_woke`
- `easybar.events.wifi_change`
- `easybar.events.network_change`
- `easybar.events.volume_change`
- `easybar.events.minute_tick`
- `easybar.events.second_tick`
- `easybar.events.mouse.entered`
- `easybar.events.mouse.exited`
- `easybar.events.mouse.clicked`
- `easybar.events.mouse.scrolled`
- `easybar.events.slider.preview`
- `easybar.events.slider.changed`

### `easybar.exec(command, callback)`

Runs a shell command.

```lua
easybar.exec("date +%H:%M", function(output)
    easybar.set("clock", {
        label = {
            string = output,
        },
    })
end)
```

### `easybar.log(level, ...)`

Logs from a widget.

Supported levels:

- `"trace"`
- `"debug"`
- `"info"`
- `"warn"`
- `"error"`

Example:

```lua
easybar.log("info", "refreshing widget")
easybar.log("debug", "current value", 42)
easybar.log("trace", "raw payload", payload)
```

These are the public Lua logging levels.
The Swift host decides which ones are actually emitted based on the configured host logging level.

For example:

- host `logging.level = "info"` shows `info`, `warn`, and `error`
- host `logging.level = "debug"` also shows `debug`
- host `logging.level = "trace"` also shows `trace`

## Properties

### Basic

- `position`
- `order`
- `drawing`
- `parent`
- `width`
- `height`
- `update_freq`

### Icon

```lua
icon = {
    string = "🕒",
    color = "#ffffff",
    font = { size = 14 },
}
```

### Label

```lua
label = {
    string = "Hello",
    color = "#ffffff",
    font = { size = 13 },
}
```

### Background

```lua
background = {
    color = "#1a1a1a",
    border_color = "#333333",
    border_width = 1,
    corner_radius = 8,
    padding_left = 8,
    padding_right = 8,
}
```

## Grouping

```lua
easybar.add("group", "vpn", {
    position = "right",
    order = 40,
    background = {
        color = "#202020",
        border_color = "#4a4a4a",
        border_width = 1,
        corner_radius = 8,
    },
    spacing = 6,
})
```

## Popups

```lua
easybar.add("item", "calendar", {
    position = "right",
    order = 30,
    popup = {
        drawing = false,
    },
})

easybar.subscribe("calendar", easybar.events.mouse.entered, function()
    easybar.set("calendar", {
        popup = { drawing = true },
    })
end)

easybar.subscribe("calendar", easybar.events.mouse.exited, function()
    easybar.set("calendar", {
        popup = { drawing = false },
    })
end)
```

## Routine updates

```lua
easybar.add("item", "clock", {
    update_freq = 30,
})

easybar.subscribe("clock", easybar.events.routine, function()
    easybar.set("clock", {
        label = os.date("%H:%M"),
    })
end)
```

## Recommended pattern

```lua
easybar.default({
    background = {
        padding_left = 8,
        padding_right = 8,
    },
})

easybar.add("item", "clock", {
    position = "right",
    order = 10,
})

easybar.subscribe("clock", easybar.events.routine, function()
    easybar.set("clock", {
        label = os.date("%H:%M"),
    })
end)
```

## Style guidelines

- keep ids stable
- prefer `group` for composite widgets
- use `set(...)` for all updates
- avoid side effects outside event handlers
- keep logic simple and state-driven
