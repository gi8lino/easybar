# Themes

EasyBar supports file-based themes.

A theme is a TOML file that defines shared color tokens. Those tokens are used as visual defaults for the bar, native built-ins, popups, and other themed surfaces.

Themes control appearance only. Layout, ordering, grouping, enabled state, formats, filters, and behavior stay in `config.toml`.

## Configure a theme

Select a theme in `config.toml`:

```toml
[theme]
name = "mocha"
themes_dir = "~/.config/easybar/themes"
```

`name` is the theme file name without `.toml`.

Examples:

```text
default -> default.toml
mocha -> mocha.toml
tokyo-night -> tokyo-night.toml
```

`themes_dir` is the custom theme directory.

## Lookup order

EasyBar resolves themes in this order:

```text
1. user theme: themes_dir/<name>.toml
2. bundled theme: app bundle EasyBar.app/Contents/Resources/Themes/<name>.toml
3. error if the theme does not exist
```

A user theme overrides a bundled theme with the same name.

Example:

```text
~/.config/easybar/themes/mocha.toml
```

wins over the bundled `mocha.toml`.

## Bundled themes

Bundled themes ship inside the app bundle.

In the source tree, bundled themes should live in the app target:

```text
EasyBar.app/Contents/Resources/Themes/
├── default.toml
├── dracula.toml
├── everforest-dark.toml
├── frappe.toml
├── gruvbox-dark.toml
├── latte.toml
├── macchiato.toml
├── mocha.toml
├── nord.toml
├── rose-pine.toml
├── solarized-dark.toml
└── tokyo-night.toml
```

`Package.swift` should copy them as app resources:

```swift
.copy("Themes")
```

Bundled themes should not be copied automatically into `~/.config/easybar/themes`, because copied files can become stale when bundled themes change.

## Custom themes

Create a custom theme in your configured `themes_dir`:

```bash
mkdir -p ~/.config/easybar/themes
$EDITOR ~/.config/easybar/themes/my-theme.toml
```

Then select it:

```toml
[theme]
name = "my-theme"
themes_dir = "~/.config/easybar/themes"
```

Reload EasyBar:

```bash
easybar --reload-config
```

## Theme file format

```toml
[colors]
background = "#111111"
surface = "#1a1a1a"
surface_elevated = "#2b2b2b"
surface_hover = "#202020"
text = "#ffffff"
text_secondary = "#d0d0d0"
text_tertiary = "#c0c0c0"
muted = "#6c7086"
muted_secondary = "#8a8a8a"
outside_month = "#6e738d"
accent = "#91d7e3"
accent_secondary = "#89B4FA"
accent_soft = "#8bd5ca"
success = "#a6e3a1"
success_secondary = "#a6da95"
warning = "#f9e2af"
orange = "#fab387"
error = "#f38ba8"
danger = "#FF0000"
border = "#333333"
border_strong = "#444444"
border_subtle = "#00000000"
selection_text = "#0B1020"
selection_background = "#89B4FA"
transparent = "#00000000"
overlay_outline = "#000000F0"
overlay_text = "#FFFFFFFF"
today_button_border = "#3F2F6B"
```

## Required color tokens

Every complete theme should define the full semantic palette:

| Token                  | Purpose                                             |
| ---------------------- | --------------------------------------------------- |
| `background`           | Main bar and popup background.                      |
| `surface`              | Normal widget or inactive surface background.       |
| `surface_elevated`     | Focused, active, or raised surface background.      |
| `surface_hover`        | Hover or highlighted surface background.            |
| `text`                 | Primary text color.                                 |
| `text_secondary`       | Secondary body or label text color.                 |
| `text_tertiary`        | Tertiary text color for quieter labels.             |
| `muted`                | Secondary, inactive, or unavailable text color.     |
| `muted_secondary`      | Secondary muted tone for softer supporting content. |
| `outside_month`        | Calendar text color for days outside the month.     |
| `accent`               | Accent color for highlights and secondary details.  |
| `accent_secondary`     | Secondary accent for supporting highlights.         |
| `accent_soft`          | Softer accent for subtle emphasis.                  |
| `success`              | Positive or healthy status color.                   |
| `success_secondary`    | Secondary positive color for supporting signals.    |
| `warning`              | Warning status color.                               |
| `orange`               | Orange status color for low or degraded states.     |
| `error`                | Error or critical status color.                     |
| `danger`               | Strong danger color for urgent attention.           |
| `border`               | Normal border color.                                |
| `border_strong`        | Emphasized border color.                            |
| `border_subtle`        | Subtle or transparent border color.                 |
| `selection_text`       | Text color drawn on selected surfaces.              |
| `selection_background` | Background color used for selected surfaces.        |
| `transparent`          | Fully transparent color, usually `#00000000`.       |
| `overlay_outline`      | Overlay outline color with alpha.                   |
| `overlay_text`         | High-contrast overlay glyph or text color.          |
| `today_button_border`  | Border color for the calendar today button.         |

## Color references

Config color fields can reference theme tokens:

```toml
[bar.colors]
background = "theme.background"
border = "theme.transparent"

[builtins.time.style]
text_color = "theme.text"
background_color = "theme.surface"
border_color = "theme.border"
```

Theme references use this form:

```text
theme.<token>
```

Examples:

```text
theme.background
theme.surface
theme.surface_elevated
theme.surface_hover
theme.text
theme.text_secondary
theme.text_tertiary
theme.muted
theme.muted_secondary
theme.outside_month
theme.accent
theme.accent_secondary
theme.accent_soft
theme.success
theme.success_secondary
theme.warning
theme.orange
theme.error
theme.danger
theme.border
theme.border_strong
theme.border_subtle
theme.selection_text
theme.selection_background
theme.transparent
theme.overlay_outline
theme.overlay_text
theme.today_button_border
```

Plain hex colors still work everywhere.

## Lua widgets

Lua widgets receive the active theme through `easybar.theme`.

Use resolved colors when the widget should render a concrete hex value:

```lua
easybar.add(easybar.kind.item, "clock", {
    label = {
        string = os.date("%H:%M"),
        color = easybar.theme.colors.text,
    },
})
```

Use theme references when a node color field should stay tied to the current theme:

```lua
easybar.add(easybar.kind.item, "clock", {
    color = easybar.theme.ref.text,
    background = {
        color = easybar.theme.ref.surface,
    },
})
```

`easybar.theme.ref.<token>` always mirrors the supported theme token names.

## Override theme colors

You can override individual theme tokens in `config.toml`:

```toml
[theme]
name = "mocha"

[theme.colors]
accent = "#8aadf4"
error = "#ff6b6b"
```

This keeps the selected theme and changes only the listed tokens.

## Override widget colors

Explicit widget config always wins over theme defaults.

```toml
[theme]
name = "mocha"

[builtins.battery.colors]
critical = "#ff0000"
```

Here the battery critical color uses `#ff0000`, even if the theme has a different `error` color.

## What belongs in a theme

Good theme content:

- shared color tokens
- surface colors
- text colors
- status colors
- border colors

Do not put behavior or layout in theme files:

- `enabled`
- `position`
- `order`
- `group`
- date or time formats
- polling intervals
- calendar filters
- widget-specific behavior

## Troubleshooting

### Theme not found

If you see:

```text
theme 'tokyo-night' was not found in ~/.config/easybar/themes or bundled themes
```

check that one of these files exists:

```text
~/.config/easybar/themes/tokyo-night.toml
EasyBar.app/Contents/Resources/Themes/tokyo-night.toml
```

For bundled themes, make sure the repository root contains the selected theme file:

```text
themes/tokyo-night.toml
```

Then rebuild or run through the Makefile so the root `themes/` directory is copied into the app bundle:

```bash
make bundle
```

For local development, use:

```bash
make run
```

Both targets package bundled themes into:

```text
EasyBar.app/Contents/Resources/Themes/
```

### Theme changes do not apply

Reload config:

```bash
easybar --reload-config
```

If `watch_config = false`, EasyBar will not reload automatically.

### A widget ignores the theme

Check whether that widget has an explicit color in `config.toml`.

Explicit widget colors override theme defaults.
