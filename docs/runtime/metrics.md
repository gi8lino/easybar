# Metrics

EasyBar can stream lightweight internal metrics over the main socket.

## Snapshot

Use:

```bash
easybar --metrics
```

for one point-in-time snapshot.

## Watch mode

Use:

```bash
easybar --metrics --watch
```

for a rolling terminal view with simple graphs.

## Included metrics

The metrics stream includes:

- EasyBar process CPU, memory, and thread count
- Lua runtime CPU, memory, and thread count
- runtime event and tree-update rates
- agent connection state plus message, reconnect, and refresh counters
- busiest widget tree roots
- top emitted event names

The periodic sampler stays off until a metrics client asks for it, so normal idle runtime does not keep collecting process samples when nobody is watching.
