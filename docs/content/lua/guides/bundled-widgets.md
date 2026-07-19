# Bundled Widgets

The repository's `widgets/` directory contains examples ranging from minimal API demonstrations to complete integrations. Copy only the widgets you want into your configured `widgets_dir`, together with the `lib/` directory when the widget imports shared modules.

## Catalog

| Widget                   | Purpose                            | Requirements                                      | Inbox publisher |
| ------------------------ | ---------------------------------- | ------------------------------------------------- | --------------- |
| `simple.lua`             | Minimal stateful toggle            | None                                              | No              |
| `group_demo.lua`         | Groups, shared styling, and popups | None                                              | No              |
| `context-menu.lua`       | Native right-click menu API        | `gh` for its example action                       | No              |
| `popup-context-menu.lua` | Popup and context menu on one item | None                                              | No              |
| `inbox-demo.lua`         | Representative inbox test messages | Native inbox enabled                              | Yes             |
| `brew.lua`               | Homebrew updates in its own popup  | `brew` in `[app.env].PATH`                        | No              |
| `brew-inbox.lua`         | Homebrew updates and actions       | `brew` in `[app.env].PATH`                        | Yes             |
| `github.lua`             | GitHub notifications popup         | Authenticated `gh`; bundled GitHub SVG asset      | No              |
| `github-inbox.lua`       | GitHub notifications               | Authenticated `gh`                                | Yes             |
| `gitlab.lua`             | Assigned GitLab work items         | Authenticated `glab`; optional `GITLAB_HOST`      | No              |
| `gitlab-inbox.lua`       | Assigned GitLab work items         | Authenticated `glab`; optional `GITLAB_HOST`      | Yes             |
| `network.lua`            | Native network snapshot            | Network agent                                     | No              |
| `wifi+vpn.lua`           | Read-only tunnel indicator         | Network agent                                     | No              |
| `tailscale.lua`          | Tailscale state and controls       | `tailscale`; optional `TAILSCALE` command setting | No              |
| `wireguard.lua`          | Network Extension VPN control      | Service name in `lib/secrets.lua`                 | No              |

## Choose one presentation

Do not load both presentation variants for the same service:

- choose `brew.lua` or `brew-inbox.lua`
- choose `github.lua` or `github-inbox.lua`
- choose `gitlab.lua` or `gitlab-inbox.lua`

The regular variants own a bar icon and popup. The inbox variants publish snapshots into the shared native inbox and register their operations as source actions.

GitHub and GitLab inbox items expose a dedicated **Mark as read** action. GitHub also acknowledges the notification through the GitHub API. GitLab publishes assigned work items rather than notification records, so its action updates EasyBar's persistent local read state.

## GUI environment

Apps opened from Finder or Spotlight do not inherit `.zshrc`. Make required CLIs and instance settings explicit:

```toml
[app.env]
PATH = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
GITLAB_HOST = "https://gitlab.example.com"
TAILSCALE = "/opt/homebrew/bin/tailscale"
```

Authenticate tools in a terminal before starting the corresponding widget:

```bash
gh auth login
glab auth login --hostname gitlab.example.com
```

See [Environment](../../configuration/environment.md) for precedence and GUI-launch behavior.

## Shared modules and assets

Several examples import `shell`, `text`, or `secrets` from `widgets/lib`. Preserve that directory structure when copying them. File-backed assets are resolved relative to the widget with `easybar.asset(...)`; copy those assets as well.

## Diagnostics

Lua loader and command failures appear in EasyBar's logs. The Homebrew examples also maintain a bounded `brew-widget.log` in the configured logging directory. Use [Lua Logging](logging.md), [Commands](commands.md), and [Troubleshooting](../../runtime/troubleshooting.md) when an example does not update.
