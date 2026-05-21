# Network Agent

`easybar-network-agent` owns Wi-Fi and network observation.

It is responsible for:

- location permission handling
- Wi-Fi observation
- primary interface tracking
- RSSI smoothing
- field-based responses

## Key design

Unlike the calendar agent, the network agent is field-based, not snapshot-based.

Clients request only what they need.

## Request

```json
{
  "command": "fetch",
  "fields": ["wifi.ssid", "network.primary_interface_is_tunnel"]
}
```

## Response

```json
{
  "kind": "fields",
  "fields": {
    "wifi.ssid": "Office WiFi",
    "network.primary_interface_is_tunnel": false
  }
}
```

## Field model

The network agent returns a flat map of typed values:

```json
{
  "wifi.ssid": "Office WiFi",
  "wifi.rssi": -64,
  "network.primary_interface_is_tunnel": true
}
```

Keys are dot-separated.
Values are typed, not stringified UI values.

This is different from Lua events, where values are structured into objects.

## Field categories

### Wi-Fi

- `wifi.ssid`
- `wifi.rssi`
- `wifi.noise`
- `wifi.snr`
- `wifi.channel`

### Network

- `network.primary_interface`
- `network.primary_interface_is_tunnel`
- `network.ipv4_address`
- `network.dns_servers`

### Auth

- `auth.location_authorized`
- `auth.location_permission_state`

## Behavior notes

- Wi-Fi fields require location permission.
- Permission denied returns an error unless unauthorized non-sensitive fields are allowed.
- RSSI is smoothed.
- The agent does not map UI values.

EasyBar converts these into:

- widget state
- Lua event payloads

## Relationship to Lua events

Agent response:

```json
{
  "wifi.ssid": "Office WiFi"
}
```

Lua event:

```json
{
  "name": "wifi_change",
  "network": {
    "interface_name": "en0"
  }
}
```

Agents return flat data.
Lua receives structured data.
