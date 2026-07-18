# Built-ins

EasyBar supports native built-in widgets in `config.toml`.

Built-ins are configured under `[builtins.*]`.

If you are deciding whether to use a built-in or write a Lua widget, start with [Built-ins Vs Lua](../getting-started/builtins-vs-lua.md).

Example:

```toml
[builtins.spaces]
enabled = true

[builtins.battery]
enabled = true

[builtins.wifi]
enabled = true

[builtins.calendar]
enabled = true
```

## Theme defaults

Built-ins receive visual defaults from the selected theme.

For example, a theme can provide default colors for:

- text
- surfaces
- borders
- status colors
- popup backgrounds
- active and inactive states

Explicit built-in config still wins.

Example:

```toml
[theme]
name = "default"

[builtins.time.style]
text_color = "#ffffff"
background_color = "#090909"
```

Here the time widget uses the explicit colors instead of the theme defaults.

See [Themes](themes.md).

## Groups

Built-ins can be attached to native groups:

```toml
[builtins.groups.system]
position = "right"
order = 40

[builtins.groups.system.style]

[builtins.battery]
enabled = true
group = "system"

[builtins.wifi]
enabled = true
group = "system"
```

See [Native Groups](native-groups.md).

## Box model

Built-in widgets and native groups share common layout keys:

- `margin_x`
- `margin_y`
- `padding_x`
- `padding_y`
- `spacing`

See [Box Model](box-model.md).

## Inbox

The native inbox collects structured messages published by Lua widgets into one bar item. It shows
the total unread count, renders plain text or limited inline Markdown, and can group messages by
source, date, category, severity, or not at all.

```toml
[builtins.inbox]
enabled = true
position = "right"
order = 5

[builtins.inbox.content]
group_by = "source"
show_unread_count = true
use_inactive_style_when_read = true
show_when_empty = true
inactive_icon = "󰂜"
inactive_color = "theme.muted"
```

The popup itself can be recolored under `[builtins.inbox.colors]`, including its background,
border, title, body, muted labels, item background, actions, and all four severity indicators.

See [Native Inbox](../lua/guides/inbox.md) for the publishing API, Markdown limits, actions, and
all grouping and display options.

## Spaces

For the native `spaces` widget:

- `[builtins.spaces]` controls the outer container placement and shared box model.
- `[builtins.spaces.layout]` controls the internal workspace-pill layout.

### Content and collapsed inactive spaces

The `show_label`, `show_icons`, and `collapse_inactive` settings work together:

| `show_label` | `show_icons` | `collapse_inactive` | Result                                                                                   |
| ------------ | ------------ | ------------------- | ---------------------------------------------------------------------------------------- |
| `true`       | `true`       | `false`             | Shows every visible space with its label and app icons.                                  |
| `true`       | `true`       | `true`              | Shows the focused space with its label and icons; inactive spaces become compact labels. |
| `true`       | `false`      | `false`             | Shows every visible space as a label.                                                    |
| `true`       | `false`      | `true`              | Shows only the focused space label.                                                      |
| `false`      | `true`       | `false`             | Shows every visible space with app icons.                                                |
| `false`      | `true`       | `true`              | Shows only the focused space with its app icons.                                         |
| `false`      | `false`      | either              | Renders no spaces widget and shows a config warning.                                     |

The table assumes `show_only_focused_label = false`. When that option is `true`, inactive labels are removed as well; inactive spaces are omitted whenever they would have no visible content.

To disable the spaces widget intentionally, prefer:

```toml
[builtins.spaces]
enabled = false
```

## Wi-Fi

The native Wi-Fi widget is configured under `[builtins.wifi]`.

It always renders signal bars as the anchor. Content modes decide whether additional network values are shown inline or in a popup.

```toml
[builtins.wifi]
enabled = true
position = "right"
order = 30
```

### Wi-Fi style

The root style uses the shared built-in widget style keys:

```toml
[builtins.wifi.style]
background_color = "theme.transparent"
border_color = "theme.transparent"
border_width = 0
corner_radius = 8
padding_x = 8
padding_y = 0
spacing = 6
```

`spacing` controls the gap between the signal bars and inline content.

### Wi-Fi content mode

The Wi-Fi widget supports three content modes:

```toml
[builtins.wifi.content]
mode = "inline" # icon | inline | details
```

| Mode      | Behavior                                                                        |
| --------- | ------------------------------------------------------------------------------- |
| `icon`    | Shows only the Wi-Fi signal bars.                                               |
| `inline`  | Shows enabled field values as one joined inline string next to the signal bars. |
| `details` | Shows enabled fields as label/value rows in a popup.                            |

The same `[builtins.wifi.fields]` toggles drive both `inline` and `details` mode.

### Wi-Fi surface behavior

The `surface` setting controls when the selected content mode is visible:

```toml
[builtins.wifi.content]
surface = "hover" # always | hover
```

| Surface  | Behavior                                                                        |
| -------- | ------------------------------------------------------------------------------- |
| `always` | The selected content mode is visible immediately.                               |
| `hover`  | The selected content mode is visible only while the pointer is over the widget. |

`inline` mode always renders inside the bar.

`details` mode always renders in the popup.

`surface` only controls whether the selected mode is shown immediately or on hover. There is no separate `hover_surface` setting.

### Wi-Fi inline mode

Inline mode joins enabled field values with `inline_separator`:

```toml
[builtins.wifi.content]
mode = "inline"
surface = "hover"
inline_separator = " | "

[builtins.wifi.fields]
ssid = true
ipv4_address = true
ipv6_address = true
```

Example inline output:

```text
Sunrise_Wi-Fi_831720 | 10.0.0.91 | fd88:84dd:4eb:43ba:189a:8f88:cdb5:3a4
```

The separator is used only by `mode = "inline"`.

### Wi-Fi details mode

Details mode uses the same enabled fields, but renders them as label/value rows in the popup:

```toml
[builtins.wifi.content]
mode = "details"
surface = "hover"

[builtins.wifi.fields]
ssid = true
ipv4_address = true
ipv6_address = true
rssi = true
link_quality = true
tx_rate = true
```

Details mode does not render rows inside the bar. It always uses the popup layout.

Example details output:

```text
SSID:         Sunrise_Wi-Fi_831720
IPv4 Address: 10.0.0.91
IPv6 Address: fd88:84dd:4eb:43ba:189a:8f88:cdb5:3a4
Signal:       -57 dBm
Link Quality: 100%
Rate:         864 Mbps
```

### Wi-Fi fields

Available field toggles:

| Config key             | Displayed value                            |
| ---------------------- | ------------------------------------------ |
| `ssid`                 | Current Wi-Fi SSID.                        |
| `ipv4_address`         | Primary IPv4 address.                      |
| `ipv6_address`         | Primary IPv6 address.                      |
| `bssid`                | Current access point BSSID.                |
| `interface`            | Wi-Fi interface name, such as `en0`.       |
| `hardware_address`     | Wi-Fi hardware MAC address.                |
| `power`                | Wi-Fi power state.                         |
| `service_active`       | CoreWLAN service state.                    |
| `rssi`                 | Signal strength in dBm.                    |
| `noise`                | Noise floor in dBm.                        |
| `snr`                  | Signal-to-noise ratio in dB.               |
| `link_quality`         | Derived link quality percentage.           |
| `tx_rate`              | Current transmit rate.                     |
| `channel`              | Current Wi-Fi channel.                     |
| `channel_band`         | Current Wi-Fi band.                        |
| `channel_width`        | Current Wi-Fi channel width.               |
| `security`             | Current Wi-Fi security mode.               |
| `phy_mode`             | Current Wi-Fi PHY mode.                    |
| `interface_mode`       | Current Wi-Fi interface mode.              |
| `country_code`         | Current Wi-Fi country code.                |
| `roaming`              | Whether access-point roaming was detected. |
| `ssid_changed_at`      | Last SSID change timestamp.                |
| `interface_changed_at` | Last interface change timestamp.           |

The `ipv4_address` and `ipv6_address` values are primary network addresses from the network agent. They are rendered by the Wi-Fi widget, but their wire fields are `network.ipv4_address` and `network.ipv6_address`.

### Wi-Fi popup style

The Wi-Fi popup is configured under `[builtins.wifi.popup]`:

```toml
[builtins.wifi.popup]
text_color = "theme.text"
background_color = "theme.background"
border_color = "theme.border_strong"
border_width = 1
corner_radius = 8
padding_x = 8
padding_y = 6
margin_x = 0
margin_y = 8
```

### Wi-Fi permissions

The network agent owns Wi-Fi observation.

Wi-Fi-specific fields require Location Services permission on macOS. If permission is missing, the widget shows the configured denied text for SSID:

```toml
[builtins.wifi.content]
denied_text = "denied"
```

After changing Location Services permission, restart the network agent and EasyBar:

```bash
easybar --restart-network-agent
```

## Calendar anchor fields

The calendar anchor uses one ordered list of `time` and `date` fields. `layout = "row"` places
them beside each other; `layout = "column"` stacks them. Reversing `fields` reverses their order,
and a one-element list creates a single-field anchor.

```toml
[builtins.calendar.anchor]
layout = "row"
fields = ["time", "date"]
spacing = 0
separator = ", "

[builtins.calendar.anchor.time]
format = "HH:mm"
text_color = "theme.text"
font_size = 13
font_weight = "semibold"

[builtins.calendar.anchor.date]
format = "EEE, MMM d"
text_color = "theme.text_secondary"
font_size = 12
font_weight = "regular"
```

Each field has its own `format`, `text_color`, optional `font_family`, optional `font_size`, and
`font_weight`. Supported weights are `ultralight`, `thin`, `light`, `regular`, `medium`,
`semibold`, `bold`, `heavy`, and `black`. The `separator` is rendered only for row layouts.

The standalone `[builtins.time]` and `[builtins.date]` widgets remain available when the values
should appear elsewhere in the bar. They use the same formatting and refresh implementation as
the calendar fields.

The previous `item`, `stack`, and `inline` layouts and their `item_format`, `top_format`, and
`bottom_format` keys have been replaced by this model. Use a one-element `fields` list instead of
`item`, `layout = "column"` instead of `stack`, and `layout = "row"` instead of `inline`.

## Calendar appointments

Appointment row details are configured under `[builtins.calendar.appointments]`.

```toml
[builtins.calendar.appointments]
show_location = true
location_icon = ""
location_icon_color = "theme.accent"
show_travel_time = true
travel_icon = ""
travel_icon_color = "theme.muted_secondary"
```

`location_icon` is shown before event locations in both month and upcoming popups. Set it to an empty string if you want location text without an icon. `location_icon_color` accepts the same theme references or hex colors as other calendar colors; when omitted, EasyBar uses `secondary_text_color`.

## Calendar quick actions

Appointment rows in the calendar popups include an action menu.

Available actions are:

- `Edit`: opens the native appointment editor.
- `Copy Details`: copies title, time range, calendar, location, and URL when available.
- `Join Meeting` / `Open URL`: opens the event URL when Calendar.app provides one or when EasyBar can extract one from the location or notes.
- `Open in Calendar`: opens Calendar.app.

These actions are built in and do not need extra config.

## Calendar filters

Calendar filters are configured under `[builtins.calendar.filters]`.

Use `included_calendar_names` and `excluded_calendar_names` for the visible calendar titles you see in Calendar.app.

For advanced exact matching, you can also use:

- `included_calendar_ids`
- `excluded_calendar_ids`
- `included_calendar_source_ids`
- `excluded_calendar_source_ids`

Excludes always win over includes, and blank filter entries are ignored.

## When to switch to Lua

Stay with built-ins when the widget already exists and you mainly need native placement, grouping, theming, or styling.

Switch to Lua when you need:

- custom formatting or composed content
- custom mouse behavior
- popup content driven by your own data
- shell-command integration or app-specific logic

See [Lua Widgets](../lua/overview.md).
