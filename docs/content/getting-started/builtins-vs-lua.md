# Built-ins Vs Lua

EasyBar supports two main ways to build your bar:

- native built-ins configured in `config.toml`
- custom Lua widgets loaded from your widgets directory

Both are first-class, but they solve different problems.

## Choose built-ins when

Built-ins are usually the best default for:

- common system data such as battery, Wi-Fi, calendar, spaces, and focused app state
- widgets that already exist in EasyBar and do not need custom behavior
- setups where you want native rendering and minimal scripting
- features that depend on helper agents or platform-specific integrations

Built-ins keep more logic in Swift and usually need less maintenance.

See [Built-ins](../configuration/builtins.md) and [Native Groups](../configuration/native-groups.md).

## Choose Lua when

Lua widgets are the better fit when you need:

- custom text or icon formatting
- shell-command integration
- interactions such as click, hover, scroll, or slider handling
- small personal workflows or app-specific status
- custom grouping, popup content, or event-driven updates

Lua is the extension layer. It gives you fast iteration and flexibility without editing the native codebase.

See [Lua Widgets](../lua/overview.md).

## Common split

A strong EasyBar setup often uses both:

- built-ins for platform-aware widgets and stable system integrations
- Lua for custom display logic, local scripts, and project-specific widgets

Examples:

- Use the native `spaces` built-in for workspace state, then add Lua widgets for VPN state or repo status.
- Use the native `calendar` built-in for event data, then add a Lua popup renderer if you want a custom visual layout.
- Use built-in groups for a standard system cluster, then use Lua groups for interactive custom widgets.

## Rule of thumb

Start with the simplest native option that already exists. Reach for Lua when you need custom behavior, custom rendering, or custom interaction.

## Next steps

- Read [Configuration Overview](../configuration/overview.md) if you want a config-first setup.
- Read [First Widget](../lua/guides/first-widget.md) if you want to build a custom Lua widget.
- Keep [API Summary](../lua/api-summary.md) nearby when you start wiring up nodes and events.
