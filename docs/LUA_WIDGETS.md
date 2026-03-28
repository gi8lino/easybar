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

---

### `easybar.set(id, props)`

Updates one item.

```lua
easybar.set("clock", {
    label = {
        string = os.date("%H:%M"),
    },
})
```

---

### `easybar.animate(id, props[, options])`

Small UX helper.

Use it when a change should feel intentional.
EasyBar already animates visible UI state changes in SwiftUI, so this updates through the same path as `set(...)`.

```lua
easybar.animate("calendar", {
    popup = {
        drawing = true,
    },
})
```

You can still pass an options table for readability:

```lua
easybar.animate("volume", {
    label = {
        string = "75%",
    },
}, {
    duration = 0.20,
})
```

---

### `easybar.remove(id)`

Removes one item and its children.

```lua
easybar.remove("clock")
```

---

### `easybar.get(id)`

Returns the current property table.

```lua
local props = easybar.get("clock")
```

---

### `easybar.default(props)`

Sets defaults for future `easybar.add(...)` calls.

Useful for shared padding, colors, or background.

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

Then later:

```lua
easybar.add("item", "clock", {
    position = "right",
    order = 10,
    label = {
        string = "--:--",
    },
})
```

The item inherits the defaults and then applies its own values on top.

---

### `easybar.clear_defaults()`

Clears all `easybar.default(...)` values.

```lua
easybar.clear_defaults()
```

---

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

The handler receives one normalized event table.

Useful fields include:

- `event.name`
- `event.widget_id`
- `event.target_widget_id`
- `event.app_name`
- `event.interface_name`
- `event.button`
- `event.direction`
- `event.charging`
- `event.muted`
- `event.value`
- `event.delta_x`
- `event.delta_y`
- `event.raw`

Example:

```lua
easybar.subscribe("calendar", easybar.events.mouse.clicked, function(event)
    print(event.name, event.button)
end)
```

Common driver events include:

- `easybar.events.forced`
- `easybar.events.system_woke`
- `easybar.events.sleep`
- `easybar.events.space_change`
- `easybar.events.app_switch`
- `easybar.events.display_change`
- `easybar.events.power_source_change`
- `easybar.events.charging_state_change`
- `easybar.events.wifi_change`
- `easybar.events.network_change`
- `easybar.events.volume_change`
- `easybar.events.mute_change`
- `easybar.events.minute_tick`
- `easybar.events.second_tick`
- `easybar.events.calendar_change`
- `easybar.events.focus_change`
- `easybar.events.workspace_change`
- `easybar.events.mouse.entered`
- `easybar.events.mouse.exited`
- `easybar.events.mouse.clicked`
- `easybar.events.mouse.scrolled`
- `easybar.events.slider.preview`
- `easybar.events.slider.changed`

Event ownership rule:

- subscribe on the parent item or `group`: the whole parent frame reacts
- subscribe on a child item: only that child frame reacts
- for icon-only behavior, make the icon its own child item

---

### `easybar.exec(command, callback)`

Runs one shell command.

```lua
local value = easybar.exec("date +%H:%M")

easybar.exec("date +%H:%M", function(output)
    easybar.set("clock", {
        label = {
            string = output,
        },
    })
end)
```

---

### `easybar.log(level, ...)`

Writes one widget-scoped log line.

```lua
easybar.log("info", "refreshing widget")
easybar.log("warn", "vpn name missing")
```

---

## Properties

## Basic

- `position = "left" | "center" | "right"`
- `order = number`
- `drawing = true | false`
- `parent = "other_id"`
- `width = number`
- `height = number`
- `y_offset = number`
- `margin_x = number`
- `margin_y = number`
- `margin_left = number`
- `margin_right = number`
- `margin_top = number`
- `margin_bottom = number`
- `update_freq = seconds`

## Text

### `icon`

- `icon.string`
- `icon.image`
- `icon.image_size`
- `icon.image_corner_radius`
- `icon.color`
- `icon.font.size`
- `icon.padding_right`

Example:

```lua
icon = {
    image = os.getenv("WIREGUARD_LOGO_PATH"),
    image_size = 16,
    image_corner_radius = 0,
}
```

## Grouping

Use `group` when multiple child nodes should live inside one styled container.

```lua
easybar.add("group", "vpn_group", {
    position = "right",
    order = 40,
    background = {
        color = "#202020",
        border_color = "#4a4a4a",
        border_width = 1,
        corner_radius = 8,
        padding_left = 8,
        padding_right = 8,
        padding_top = 4,
        padding_bottom = 4,
    },
    spacing = 6,
})

easybar.add("item", "vpn_group_icon", {
    parent = "vpn_group",
    icon = {
        image = os.getenv("HOME") .. "/.config/easybar/assets/wireguard.png",
        image_size = 16,
    },
})

easybar.add("item", "vpn_group_label", {
    parent = "vpn_group",
    label = {
        string = "VPN",
    },
})
```

This gives you:

- click/hover on `vpn_group` for the whole pill
- click/hover on `vpn_group_icon` only for the icon
- click/hover on `vpn_group_label` only for the label

Native built-ins can also be attached under a native group in `config.toml`:

```toml
[builtins.groups.system]
position = "right"
order = 40

[builtins.groups.system.style]
background_color = "#1a1a1a"
border_color = "#333333"
border_width = 1
corner_radius = 8
margin_x = 0
margin_y = 0
padding_x = 8
padding_y = 4
spacing = 6

[builtins.wifi]
enabled = true
group = "system"
```

The referenced native group must exist under `[builtins.groups.<id>]`.

Built-in widget `style` blocks use the same box-model keys:

- `margin_x`
- `margin_y`
- `padding_x`
- `padding_y`
- `spacing`

### `label`

You can use a string:

```lua
label = "Hello"
```

Or a table:

```lua
label = {
    string = "Hello",
    color = "#ffffff",
    font = {
        size = 13,
    },
}
```

## Background

```lua
background = {
    color = "#1a1a1a",
    border_color = "#333333",
    border_width = 1,
    corner_radius = 8,
    padding_left = 8,
    padding_right = 8,
    padding_top = 4,
    padding_bottom = 4,
}
```

Margins live on the node itself:

```lua
margin_x = 4
margin_y = 2
```

## Value widgets

For `slider`, `progress`, `progress_slider`, and `sparkline`:

- `value`
- `min`
- `max`
- `step`
- `values`
- `line_width`

---

## Children

Use `parent` for normal children.

```lua
easybar.add("row", "weather", {
    position = "right",
    order = 20,
    spacing = 8,
})

easybar.add("item", "weather_icon", {
    parent = "weather",
    icon = { string = "☀️" },
})

easybar.add("item", "weather_label", {
    parent = "weather",
    label = "20°",
})
```

---

## Popups

Use `popup = { ... }` on the anchor item.

Use `position = "popup.<anchor_id>"` for popup items.

```lua
easybar.add("item", "calendar", {
    position = "right",
    order = 30,
    icon = { string = "🗓" },
    label = "Today",
    popup = {
        drawing = false,
        background = {
            color = "#1e2030",
            border_color = "#494d64",
            border_width = 1,
            corner_radius = 10,
        },
        padding_left = 12,
        padding_right = 12,
        padding_top = 12,
        padding_bottom = 12,
        spacing = 8,
    },
})

easybar.add("item", "calendar_event_1", {
    position = "popup.calendar",
    label = "09:00 Standup",
})

easybar.subscribe("calendar", easybar.events.mouse.entered, function()
    easybar.animate("calendar", {
        popup = { drawing = true },
    })
end)

easybar.subscribe("calendar", easybar.events.mouse.exited, function()
    easybar.animate("calendar", {
        popup = { drawing = false },
    })
end)
```

---

## Routine updates

Use `update_freq`.

Subscribe to `easybar.events.routine`.

```lua
easybar.add("item", "clock", {
    position = "right",
    order = 10,
    update_freq = 30,
})

easybar.subscribe("clock", { easybar.events.routine, easybar.events.forced }, function()
    easybar.set("clock", {
        label = os.date("%H:%M"),
    })
end)
```

---

## Clicks

Subscribe to mouse events:

- `easybar.events.mouse.entered`
- `easybar.events.mouse.exited`
- `easybar.events.mouse.clicked`
- `easybar.events.mouse.scrolled`

Example:

```lua
easybar.subscribe("calendar", easybar.events.mouse.clicked, function(event)
    print(event.name, event.button)
end)
```

For scroll events:

- `event.direction` is `"up"` or `"down"`
- `event.delta_x`
- `event.delta_y`

For slider events:

- `easybar.events.slider.preview`
- `easybar.events.slider.changed`

The value is in:

- `event.value`

---

## Secrets and per-user config

For widget-specific personal values, the recommended pattern is to store them in a local Lua module instead of relying on process environment variables.

EasyBar loads widget files from the widgets directory, but Lua `require(...)` uses its own module search path.
That means a widget can load a module from outside the widgets directory as long as it updates `package.path` first.

A good setup is:

```text
~/.config/easybar/
└── widgets/
    └── wifi.lua

~/personal/private/easybar/
└── secrets.lua
```

Example `secrets.lua`:

```lua
return {
    vpn_name = "WireGuard",
    api_token = "example-token",
}
```

Then at the top of your widget:

```lua
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/easybar/?.lua"

local secrets = require("secrets")
```

This is a good fit for:

- VPN names
- tokens
- labels
- hostnames
- user-specific widget config

It keeps widget code clean and avoids depending on shell environment propagation through `brew services`.

If you want to keep private modules outside the widgets directory, update `package.path` inside the widget before calling `require(...)`.

Example:

```lua
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/easybar/?.lua"

local secrets = require("secrets")

easybar.add("item", "vpn_status", {
    position = "right",
    order = 20,
    label = {
        string = secrets.vpn_name or "vpn",
    },
})
```

If the module is optional, you can load it defensively:

```lua
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/personal/private/easybar/?.lua"

local ok, secrets = pcall(require, "secrets")
if not ok then
    secrets = {}
end
```

If you prefer, you can still keep `secrets.lua` next to your widgets, but it is not required.

---

## Recommended pattern

Use defaults first, then add items.

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

easybar.add("item", "clock", {
    position = "right",
    order = 10,
    update_freq = 30,
    icon = {
        string = "🕒",
    },
    label = {
        string = "--:--",
    },
})

easybar.subscribe("clock", { easybar.events.routine, easybar.events.forced }, function()
    easybar.set("clock", {
        label = {
            string = os.date("%H:%M"),
        },
    })
end)
```

---

## Example

```lua
easybar.default({
    background = {
        padding_left = 8,
        padding_right = 8,
        padding_top = 4,
        padding_bottom = 4,
    },
})

easybar.add("item", "clock", {
    position = "right",
    order = 10,
    update_freq = 30,
    icon = {
        string = "🕒",
    },
    label = {
        string = "--:--",
        color = "#ffffff",
    },
})

easybar.subscribe("clock", { easybar.events.routine, easybar.events.forced }, function()
    easybar.animate("clock", {
        label = {
            string = os.date("%H:%M"),
        },
    })
end)
```

---

## Recommended style

For most widgets:

1. `easybar.default(...)` for shared styling
2. `easybar.add(...)`
3. `easybar.subscribe(...)`
4. update with `easybar.set(...)` or `easybar.animate(...)`

Keep widget ids stable.
Use `row` for grouped items.
Use `popup.<id>` for popup content.
Use `update_freq` and `easybar.events.routine` for polling.
Use a separate Lua module for personal widget config, and update `package.path` before `require(...)` when that module lives outside the widgets directory.
