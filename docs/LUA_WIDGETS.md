# EasyBar Lua widgets

EasyBar Lua widgets are node-based.

You do not return widget trees.
You create nodes, keep their handles, and update them with methods such as `node:set(...)` and `node:subscribe(...)`.

Interaction is node-based.

- subscribe on a node handle: that node owns hover, click, scroll, and popup behavior
- the subscribed node frame is the interactive surface
- use smaller child nodes when only part of a widget should be interactive
- use `group` when multiple child nodes should share one styled container
- if children inside a group must be clicked independently, subscribe on the child handles
- subscribe on the group handle only when the whole group should behave as one interactive surface

## Default styling

Lua widgets inherit native-like styling in the most common cases, so you usually do not need to restate the full shell or popup style.

### Built-in defaults

| Node shape                        | Default styling                                                                                                            |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| bar-root `item`, `row`, `group`   | background `#1a1a1a`, border `#333333` width `1`, corner radius `8`, padding `8/8/4/4`                                     |
| popup content                     | text color `#cdd6f4`, background `#111111`, border `#444444` width `1`, corner radius `8`, padding `8 x 6`, margin `0 x 8` |
| child items inside a parent/group | no root shell by default                                                                                                   |

Notes:

- use `easybar.default(...)` when one widget file wants shared child styling or small local tweaks
- override padding only when you intentionally want a taller or denser pill than the native default
- popup-attached items inherit popup text color when they do not set one explicitly

## Editor support

EasyBar installs a bundled LuaLS stub into:

```text
~/.local/share/easybar/easybar_api.lua
```

That installed file is the combined public stub.
If you are working on EasyBar itself, the split source files are:

- `Sources/EasyBar/Lua/easybar_api.base.lua`
- `Sources/EasyBar/Lua/easybar_api.events.lua`

Those source files are merged into the installed `easybar_api.lua` stub during generation.

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

`group` is the right container when you want:

- a shared background
- shared padding
- shared popup ownership
- parent-level interaction around multiple child items

### `node:set(props)`

Updates one node.

```lua
clock:set({
    label = {
        string = os.date("%H:%M"),
    },
})
```

### `node:remove()`

Removes one node and its children.

```lua
clock:remove()
```

### `node:get()`

Returns the current property table.

```lua
local props = clock:get()
```

### `easybar.default(props)`

Sets defaults for future `easybar.add(...)` calls.

Defaults are scoped to the current widget file only.
Useful for shared child styling or per-widget tweaks.

```lua
easybar.default({
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

### `node:subscribe(events, handler)`

Subscribes one node to one or more events.

```lua
clock:subscribe({ easybar.events.minute_tick, easybar.events.forced }, function(event)
    clock:set({
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
- `event.network`
- `event.power`
- `event.audio`

For interaction handlers on parent nodes, `event.target_widget_id` tells you which concrete child node actually received the click or hover.
Use that when a root widget should ignore button clicks coming from popup children.

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

App events such as `minute_tick`, `second_tick`, `network_change`, and `volume_change` are only forwarded into the Lua runtime when at least one Lua widget subscribes to them.

Targeted interaction events such as `mouse.clicked`, `mouse.entered`, `mouse.exited`, `mouse.scrolled`, `slider.preview`, and `slider.changed` are delivered to the relevant Lua widget callbacks when those interactions occur.

### `easybar.exec(command, callback)`

Runs a shell command synchronously inside the Lua runtime.

Use this for quick commands only.
Long-running commands block the widget runtime until the command exits.

```lua
easybar.exec("date +%H:%M", function(output)
    clock:set({
        label = {
            string = output,
        },
    })
end)
```

### `easybar.exec_async(command, callback)`

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

The bundled LuaLS stub marks the public property tables as exact, so unknown keys in `icon`, `label`, `background`, `popup`, and the top-level node props should surface as editor diagnostics.

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

Image icon:

```lua
icon = {
    image = "/path/to/icon.png",
    image_size = 16,
    image_corner_radius = 0,
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

Shorthand:

```lua
label = "Hello"
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
local vpn = easybar.add(easybar.kind.group, "vpn", {
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

local vpn_main = easybar.add(easybar.kind.item, "vpn_main", {
    parent = vpn.name,
    icon = {
        string = "󰖂",
    },
})

local vpn_mode = easybar.add(easybar.kind.item, "vpn_mode", {
    parent = vpn.name,
    icon = {
        string = "󰌾",
    },
})
```

Important:

- the group is the shared styled container
- each child item can still be its own interactive surface
- if each child should react independently to clicks, subscribe on the child handles, not only on the group handle

Example:

```lua
vpn_main:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle main toggle
    end
end)

vpn_mode:subscribe(easybar.events.mouse.clicked, function(event)
    if event.button == nil or event.button == "left" then
        -- handle secondary toggle
    end
end)
```

Use a group-level mouse subscription only when the whole grouped widget should behave like one single click target.

Minimal group example:

```lua
local vpn = easybar.add(easybar.kind.group, "vpn", {
    position = "right",
    order = 40,
})

easybar.add(easybar.kind.item, "vpn_icon", {
    parent = vpn.name,
    icon = "󰖂",
})

easybar.add(easybar.kind.item, "vpn_label", {
    parent = vpn.name,
    label = "Active",
})
```

## Popups

Popup content inherits native-like defaults when you do not override them:

- text color `#cdd6f4`
- background `#111111`
- border `#444444` with width `1`
- corner radius `8`
- padding `8 x 6`
- margin `0 x 8`

That means a simple popup widget already renders close to the built-in popup look without extra popup styling.

The popup container style comes from the widget's `popup = { ... }` table.
Popup child items do not automatically inherit the bar-root shell styling, so if you want an inner pill or "double-shell" look you should style that child explicitly.

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 30,
    popup = {
        drawing = false,
    },
})

calendar:subscribe(easybar.events.mouse.entered, function()
    calendar:set({
        popup = { drawing = true },
    })
end)

calendar:subscribe(easybar.events.mouse.exited, function()
    calendar:set({
        popup = { drawing = false },
    })
end)
```

Minimal popup content example:

```lua
local calendar = easybar.add(easybar.kind.item, "calendar", {
    position = "right",
    order = 30,
    popup = {
        drawing = false,
    },
})

easybar.add(easybar.kind.item, "calendar_popup_label", {
    position = "popup." .. calendar.name,
    label = "Next event: 14:00",
})
```

Explicit double-shell popup example:

```lua
local vpn = easybar.add(easybar.kind.item, "vpn", {
    position = "right",
    order = 40,
    popup = {
        drawing = true,
        padding_x = 10,
        padding_y = 8,
        background = {
            color = "#111111",
            border_color = "#444444",
            border_width = 1,
            corner_radius = 8,
        },
    },
})

easybar.add(easybar.kind.item, "vpn_popup_label", {
    position = "popup." .. vpn.name,
    padding_left = 12,
    padding_right = 12,
    padding_top = 8,
    padding_bottom = 8,
    background = {
        color = "#181818",
        border_color = "#555555",
        border_width = 1,
        corner_radius = 8,
    },
    label = "WireGuard active",
})
```

Use the default popup styling when you want the built-in Wi-Fi tooltip look.
Add explicit child background and padding like the example above when you want a more decorated inner surface.

## Interval updates

Use `interval` together with `on_interval`.

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 30,
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

When an interval callback needs to reference its own handle, declare the variable before assigning it, as shown above.

## Recommended pattern

```lua
easybar.default({
    label = {
        color = "#cdd6f4",
    },
})

local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

Bar-root Lua items already inherit the native shell by default, so you usually only need `easybar.default(...)` for shared child styling or widget-specific overrides.

For example, this is often enough for a small image-based widget:

```lua
local tailscale = easybar.add(easybar.kind.item, "tailscale", {
    position = "right",
    order = 2,
    icon = {
        image = "/path/to/tailscale.png",
        image_size = 16,
    },
    popup = {
        drawing = true,
    },
})
```

Use `interval` and `on_interval` when a widget must poll.
Use `node:subscribe(...)` for real events such as `network_change`, `system_woke`, and `mouse.clicked`.

## Full example

```lua
local enabled = false
local toggle

local function render()
    toggle:set({
        icon = {
            string = enabled and "󰄬" or "󰄱",
            color = enabled and "#30d158" or "#ff453a",
        },
        label = {
            string = enabled and "ON" or "OFF",
            color = enabled and "#30d158" or "#ff453a",
        },
    })
end

toggle = easybar.add(easybar.kind.item, "toggle_test", {
    position = "right",
    order = 1,
})

toggle:subscribe(easybar.events.forced, function()
    render()
end)

toggle:subscribe(easybar.events.mouse.clicked, function()
    enabled = not enabled
    render()
end)

render()
```

## Style guidelines

- keep ids stable
- store handles returned from `easybar.add(...)`
- prefer `group` for composite widgets
- use `node:set(...)` for updates
- use `node:subscribe(...)` for events
- use `node.name` for `parent` and `popup.<id>` references
- avoid side effects outside event handlers
- keep logic simple and state-driven
