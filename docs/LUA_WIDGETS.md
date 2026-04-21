# EasyBar Lua widgets

EasyBar Lua widgets are item-based.

You do not return widget trees.
You create items, style them, and update them by id.

Interaction is node-based.

- subscribe on a node id: that node owns hover, click, scroll, and popup behavior
- the subscribed node frame is the interactive surface
- use smaller child nodes when only part of a widget should be interactive
- use `group` when multiple child nodes should share one styled container
- if children inside a group must be clicked independently, subscribe on the child ids
- subscribe on the group id only when the whole group should behave as one interactive surface

## Editor support

EasyBar installs a bundled LuaLS stub into:

- `~/.local/share/easybar/easybar_api.lua`

If your editor uses LuaLS, add a `.luarc.json` in the workspace where you edit widgets.

That gives you:

- no `unknown global 'easybar'` warning
- hover documentation
- autocomplete for the `easybar` API
- diagnostics and autocomplete for supported node properties such as `background.border_width`, `popup.drawing`, `interval`, and `on_interval`

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

If your editor still only knows about the `easybar` global but not nested property tables, restart EasyBar once so it reinstalls the latest `easybar_api.lua` stub.

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

Use the exported level constants:

- `easybar.level.trace`
- `easybar.level.debug`
- `easybar.level.info`
- `easybar.level.warn`
- `easybar.level.error`

Example:

```lua
easybar.log(easybar.level.info, "refreshing widget")
easybar.log(easybar.level.debug, "current value", 42)
easybar.log(easybar.level.trace, "raw payload", payload)
```

These are the public Lua logging levels.
The Swift host decides which ones are actually emitted based on the configured host logging level.

For example:

- host `logging.level = "info"` shows `info`, `warn`, and `error`
- host `logging.level = "debug"` also shows `debug`
- host `logging.level = "trace"` also shows `trace`

### `easybar.level`

Exposes the supported log level constants for `easybar.log(...)`.

Example:

```lua
easybar.log(easybar.level.warn, "vpn toggle skipped")
```

## Properties

The bundled LuaLS stub marks the public property tables as exact, so unknown keys in
`icon`, `label`, `background`, `popup`, and the top-level node props should surface as editor diagnostics.

### Basic

- `position`
- `order`
- `drawing`
- `parent`
- `width`
- `height`
- `interval`
- `on_interval`

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

Use `group` when multiple child nodes should share:

- one background
- one border
- one padding box
- one popup owner

Example:

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

easybar.add("item", "vpn_main", {
    parent = "vpn",
    icon = {
        string = "󰖂",
    },
})

easybar.add("item", "vpn_mode", {
    parent = "vpn",
    icon = {
        string = "󰌾",
    },
})
```

Important:

- the group is the shared styled container
- each child item can still be its own interactive surface
- if each child should react independently to clicks, subscribe on the child ids, not only on the group id

Example:

```lua
easybar.subscribe("vpn_main", easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle main toggle
    end
end)

easybar.subscribe("vpn_mode", easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle secondary toggle
    end
end)
```

Use a group-level mouse subscription only when the whole grouped widget should behave like one single click target.

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

## Interval updates

```lua
easybar.add("item", "clock", {
    interval = 30,
    on_interval = function()
        easybar.set("clock", {
            label = os.date("%H:%M"),
        })
    end,
})
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
    interval = 60,
    on_interval = function()
        easybar.set("clock", {
            label = os.date("%H:%M"),
        })
    end,
})
```

Use `interval` and `on_interval` when a widget must poll.
Use `easybar.subscribe(...)` for real events such as `network_change`, `system_woke`, and `mouse.clicked`.

## Style guidelines

- keep ids stable
- prefer `group` for composite widgets
- use `set(...)` for all updates
- avoid side effects outside event handlers
- keep logic simple and state-driven
