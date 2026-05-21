# Lua Style Guidelines

Follow these rules when writing EasyBar Lua widgets.

## General rules

- Keep ids stable.
- Store handles returned from `easybar.add(...)`.
- Prefer `group` for composite widgets.
- Use `node:set(...)` for updates.
- Use `node:subscribe(...)` for events.
- Use `node.name` for `parent` and `popup.<id>` references.
- Avoid side effects outside event handlers.
- Keep logic simple and state-driven.

## Styling

Bar-root Lua items already inherit the native shell by default.

Only add explicit styling when the widget needs something custom.

Use `easybar.default(...)` for shared child styling or small local tweaks.

```lua
easybar.default({
    label = {
        color = "#cdd6f4",
    },
})
```

## Interactions

Subscribe on the smallest node that should be interactive.

For grouped widgets:

- subscribe on child handles when each child has its own action
- subscribe on the group handle when the whole group behaves as one click target

## Polling

Use `interval` and `on_interval` only when the widget must poll.

Prefer event subscriptions when EasyBar already emits an event for the state you need.

## Commands

Use `easybar.exec_async(...)` for commands that may take noticeable time.

Avoid long-running synchronous `easybar.exec(...)` calls because they block the Lua runtime.
