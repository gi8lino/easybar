# Examples

This page shows complete Lua widget patterns.

If you are just starting out, read [First Widget](first-widget.md) before using these as templates.

## Toggle widget

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

## Bundled Homebrew widget

[`widgets/brew.lua`](https://github.com/gi8lino/easybar/blob/main/widgets/brew.lua) is a complete
example of a stateful popup widget. It:

- checks formulae and casks with `brew outdated`
- exposes Update and Upgrade actions as clickable popup children
- runs Homebrew commands asynchronously so other widgets remain responsive
- changes Update to Cancel while an operation is active
- returns directly to the idle actions after cancellation while preserving the last known package list
- writes command diagnostics to `brew-widget.log` under the configured EasyBar logging directory

The widget is intentionally more extensive than the snippets on this page. Use it as a reference
for command chaining, cancellation, structured state rendering, popup rows, error presentation,
and bounded file logging.

## Bundled GitLab work-items widget

[`widgets/gitlab.lua`](https://github.com/gi8lino/easybar/blob/main/widgets/gitlab.lua) shows the
open issues and merge requests assigned to the authenticated user. It works with GitLab.com and
private GitLab Self-Managed or Dedicated instances through the official `glab` CLI.

Install `glab`, authenticate the instance, and make the CLI and host available to GUI-launched
EasyBar sessions:

```sh
brew install glab
glab auth login --hostname gitlab.example.com
```

```toml
[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
GITLAB_HOST = "https://gitlab.example.com"
```

Then add `gitlab.lua` to the configured `widgets_dir` together with the bundled `lib` directory.
The widget refreshes every five minutes, orders assigned work by its most recent update, opens an
item when its popup row is clicked, and provides Refresh and Open GitLab actions in its native
right-click menu. `GITLAB_HOST` is optional for GitLab.com.

## Clock widget

```lua
local clock

clock = easybar.add(easybar.kind.item, "clock", {
    position = "right",
    order = 10,
    interval = 60,
    icon = "🕒",
    label = os.date("%H:%M"),
    on_interval = function()
        clock:set({
            label = os.date("%H:%M"),
        })
    end,
})
```

## Native context menu widget

[`widgets/context-menu.lua`](https://github.com/gi8lino/easybar/blob/main/widgets/context-menu.lua)
shows a native macOS right-click menu with actions, a separator, checked state, a submenu, and
dynamic menu replacement. See [Native Context Menus](context-menus.md) for the full
API and right-click precedence rules.

## Widget-relative image asset

```lua
local github = easybar.add(easybar.kind.item, "github", {
    icon = {
        color = easybar.theme.ref.text,
        image = {
            path = easybar.asset("github-mark.svg"),
            size = 16,
        },
    },
})
```

`easybar.asset()` resolves relative to the Lua file that calls it, so the example expects
`github-mark.svg` beside the widget file. Nested paths such as
`easybar.asset("assets/github-mark.svg")` work too. This approach is best for larger images or
assets reused by more than one part of a widget. Existing absolute paths remain valid when passed
directly as `image.path`.

## Inline SVG image

```lua
local github_svg = [[
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
    <path d="..." />
</svg>
]]

local github = easybar.add(easybar.kind.item, "github", {
    icon = {
        color = easybar.theme.ref.text,
        image = {
            svg = github_svg,
            size = 16,
        },
    },
})
```

Inline SVG is useful for small, self-contained widgets. Set either `path` or `svg`, never both.
Without an icon color, SVG images keep their original colors; setting `icon.color` applies the
same template tint used for file-backed images. Inline SVG does not sandbox a widget: widget files
remain trusted local code.

## Related pages

- [Subscribe To Events](subscribe-to-events.md)
- [Style Popups And Groups](style-popups-and-groups.md)
- [API Summary](../api-summary.md)
