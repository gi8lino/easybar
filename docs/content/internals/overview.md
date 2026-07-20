# Internals

This section is for contributors and maintainers.

If you are installing or configuring EasyBar, use [Quick Start](../getting-started/quick-start.md), [Configuration](../configuration/overview.md), and [Lua Widgets](../lua/overview.md) first. You should not need internals pages for a normal user setup.

## What belongs here

Internals pages explain implementation details and project boundaries:

- target layout and source ownership
- process model and helper agents
- control socket and agent protocols
- runtime event flow
- Lua runtime lifecycle, loading, registry, rendering, and debugging
- generated artifacts and contributor workflows

## Contributor path

Use this reading order when changing EasyBar itself:

1. [Development](development.md)
2. [Architecture Overview](architecture/overview.md)
3. [Targets](architecture/targets.md)
4. [Process Model](architecture/process-model.md)
5. [Architectural Boundaries](architecture/boundaries.md)
6. [Agent Protocol](agents/protocol.md)
7. [Lua Runtime Overview](lua-runtime/overview.md)
8. [Contributor Notes](lua-runtime/contributor-notes.md)

## User docs vs internals

Keep user-facing docs focused on outcomes:

- install EasyBar
- configure built-ins
- choose a theme
- write a Lua widget
- troubleshoot runtime issues

Keep implementation-focused content here:

- Swift target responsibilities
- agent ownership and socket protocol details
- EventKit, CoreWLAN, and process boundaries
- Lua runtime transport and registry internals
- generated files and maintainer commands

This split keeps the first-run documentation short while still preserving the deeper architecture notes for contributors.

## Architecture

- [Architecture Overview](architecture/overview.md)
- [Targets](architecture/targets.md)
- [Process Model](architecture/process-model.md)
- [Shared Layer](architecture/shared-layer.md)
- [CLI](architecture/cli.md)
- [Control Socket](architecture/control-socket.md)
- [Event Flow](architecture/event-flow.md)
- [Boundaries](architecture/boundaries.md)

## Agents

- [Agents Overview](agents/overview.md)
- [Agent Protocol](agents/protocol.md)
- [Calendar Agent](agents/calendar-agent.md)
- [Network Agent](agents/network-agent.md)
- [Debugging Agents](agents/debugging.md)

## Lua runtime

- [Lua Runtime Overview](lua-runtime/overview.md)
- [Lifecycle](lua-runtime/lifecycle.md)
- [Widget Loading](lua-runtime/widget-loading.md)
- [Registry](lua-runtime/registry.md)
- [Events](lua-runtime/events.md)
- [Rendering](lua-runtime/rendering.md)
- [Logging](lua-runtime/logging.md)
- [Debugging](lua-runtime/debugging.md)
- [Contributor Notes](lua-runtime/contributor-notes.md)
