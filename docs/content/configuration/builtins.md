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
name = "mocha"

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

## Spaces

For the native `spaces` widget:

- `[builtins.spaces]` controls the outer container placement and shared box model.
- `[builtins.spaces.layout]` controls the internal workspace-pill layout.

## Wi-Fi

The native Wi-Fi widget is configured under `[builtins.wifi]`.

It renders signal bars as the anchor. Optional text or detailed network information can be shown inline, always, or in a hover popup.

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

`spacing` controls the gap between the signal bars and any inline content.

### Wi-Fi content mode

The Wi-Fi widget supports three content modes:

```toml
[builtins.wifi.content]
mode = "field" # icon | field | details
```

| Mode      | Behavior                               |
| --------- | -------------------------------------- |
| `icon`    | Shows only the Wi-Fi signal bars.      |
| `field`   | Shows one selected field such as SSID. |
| `details` | Shows all enabled detail fields.       |

When `mode = "field"`, choose the rendered field with:

```toml
[builtins.wifi.content]
field = "wifi.ssid"
```

Common field values include:

- `wifi.ssid`
- `network.ipv4_address`
- `network.ipv6_address`
- `wifi.rssi`
- `wifi.link_quality`
- `wifi.tx_rate`

### Wi-Fi surface behavior

The `surface` setting controls when content is visible:

```toml
[builtins.wifi.content]
surface = "hover" # always | hover
```

| Surface  | Behavior                                                    |
| -------- | ----------------------------------------------------------- |
| `always` | Content is always visible.                                  |
| `hover`  | Content is shown only while the pointer is over the widget. |

When `surface = "hover"`, `hover_surface` controls where the content appears:

```toml
[builtins.wifi.content]
hover_surface = "popup" # popup | inline
```

| Hover surface | Behavior                                                 |
| ------------- | -------------------------------------------------------- |
| `popup`       | Shows field or details content in a tooltip-style popup. |
| `inline`      | Expands the bar widget inline while hovered.             |

### Wi-Fi details

Details mode uses `[builtins.wifi.fields]`.

Each enabled field becomes one detail row:

```toml
[builtins.wifi.content]
mode = "details"
surface = "hover"
hover_surface = "popup"

[builtins.wifi.fields]
ssid = true
ipv4 = true
ipv6 = true
rssi = true
link_quality = true
tx_rate = true
```

In details mode, labels and values are rendered as two aligned columns.

Available fields:

| Config key             | Displayed value                            |
| ---------------------- | ------------------------------------------ |
| `ssid`                 | Current Wi-Fi SSID.                        |
| `ipv4`                 | Primary IPv4 address.                      |
| `ipv6`                 | Primary IPv6 address.                      |
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

The `ipv4` and `ipv6` values are primary network addresses from the network agent. They are rendered by the Wi-Fi widget, but their wire fields are `network.ipv4_address` and `network.ipv6_address`.

### Wi-Fi popup style

The Wi-Fi popup is configured under `[builtins.wifi.tooltip]`:

```toml
[builtins.wifi.tooltip]
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

Wi-Fi-specific fields require Location Services permission on macOS. If permission is missing, the widget shows the configured denied text:

```toml
[builtins.wifi.content]
denied_text = "denied"
```

After changing Location Services permission, restart the network agent and EasyBar:

```bash
brew services restart gi8lino/tap/easybar-network-agent
brew services restart gi8lino/tap/easybar
```

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
