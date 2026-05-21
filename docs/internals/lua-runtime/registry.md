# Registry

The widget registry is defined in `registry.lua`.

## Main state

The registry stores:

- `items`
- `item_order`
- `subscriptions`
- `interval_handlers`
- `interval_next_due`
- `pending_async_commands`
- `pending_command_responses`

## Responsibilities

Internal registry helpers mutate this state:

- add node
- set node props
- get node props
- remove node
- run commands
- store command callbacks

## Notes

- event tokens are used instead of raw strings
- logging levels are exposed to widgets through `easybar.level`
- node handles are the public API wrapper around registry operations

## Design rule

Widgets mutate registry state.

The renderer derives output trees from the registry state.

This keeps widget updates simple and avoids incremental UI mutation in Lua.
