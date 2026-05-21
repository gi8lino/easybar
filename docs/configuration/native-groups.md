# Native Groups

Native groups let multiple built-in widgets share one visual container.

Groups can share:

- one background
- one border
- one padding box
- one spacing rule
- one placement and ordering rule

## Example

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

## Notes

- Groups are not created by default.
- Built-ins are not attached to a group by default.
- If you use `group = "system"`, the referenced group must exist under `[builtins.groups.system]`.

## When to use groups

Use native groups when several built-ins should look like one combined widget.

Common examples:

- battery + Wi-Fi
- volume + battery
- system status widgets
- compact right-side status clusters
