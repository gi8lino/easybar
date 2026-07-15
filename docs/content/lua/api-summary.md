# API Summary

This page is a compact map of the EasyBar Lua API for day-to-day widget work.

Use the full reference when you need exact property tables or event payload types.

## Most-used functions

- `easybar.add(kind, id, props?)`
  Create one node and get its handle back.
- `easybar.set(id, props)`
  Update an existing node by id.
- `easybar.get(id)`
  Read the current property table for an existing node.
- `easybar.remove(id)`
  Remove one node and its descendants.
- `easybar.subscribe(id, events, handler)`
  Subscribe one node by id to runtime or interaction events.
- `easybar.default(props)`
  Set widget-local default properties for future `add(...)` calls.
- `easybar.exec(...)` and `easybar.exec_async(...)`
  Run shell commands from a widget, with optional per-call command limits.
- `easybar.cancel_async(token)`
  Request cancellation of a pending asynchronous command and its child processes.
- `easybar.log(level, ...)`
  Write widget-scoped log output.
- `easybar.log.with_prefix(prefix)`
  Create a widget logger that prepends a stable prefix to host logs.
- `easybar.log.with_file(file, options?)`
  Create a file-backed widget logger for command/output logs.

See [Functions](reference/functions.md).

## Handle methods

Most widget code uses the handle API after creation:

- `node:set(props)`
- `node:get()`
- `node:remove()`
- `node:subscribe(events, handler)`

That style keeps the code local and usually reads better than updating nodes by string id everywhere.

## Most-used node kinds

- `easybar.kind.item`
  Basic display node for text, icons, and small interactions.
- `easybar.kind.group`
  Shared container for multiple child nodes.
- `easybar.kind.row`
  Horizontal layout wrapper.
- `easybar.kind.column`
  Vertical layout wrapper.
- `easybar.kind.slider`
  Interactive scalar control.

See [Node Kinds](reference/node-kinds.md).

## Most-used event tokens

- `easybar.events.forced`
  Manual refresh trigger.
- `easybar.events.app_switch`
  Frontmost app changed.
- `easybar.events.space_change`
  Active macOS space changed.
- `easybar.events.volume_change`
  Output volume changed.
- `easybar.events.mouse.clicked`
  Node clicked.
- `easybar.events.mouse.entered`
  Pointer entered node frame.
- `easybar.events.mouse.exited`
  Pointer left node frame.

See [Events](reference/events.md).

## Most-used property areas

- placement: `position`, `order`, `parent`
- visibility and timing: `drawing`, `interval`, `on_interval`
- content: `icon`, `label`, `image`
- layout and surface: `spacing`, `background`, `margin`, `popup`
- value-driven widgets: `value`, `min`, `max`, `step`, `values`

See [Properties](reference/properties.md).

## Suggested reading path

1. [First Widget](guides/first-widget.md)
2. [Subscribe To Events](guides/subscribe-to-events.md)
3. [Style Popups And Groups](guides/style-popups-and-groups.md)
