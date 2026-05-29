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

### Wi-Fi fields

Wi-Fi fields describe CoreWLAN state.

Common Wi-Fi fields include:

- `wifi.ssid`
- `wifi.bssid`
- `wifi.interface`
- `wifi.hardware_address`
- `wifi.power`
- `wifi.service_active`
- `wifi.rssi`
- `wifi.noise`
- `wifi.snr`
- `wifi.link_quality`
- `wifi.tx_rate`
- `wifi.channel`
- `wifi.channel_band`
- `wifi.channel_width`
- `wifi.security`
- `wifi.phy_mode`
- `wifi.interface_mode`
- `wifi.country_code`
- `wifi.roaming`
- `wifi.ssid_changed_at`
- `wifi.interface_changed_at`

These fields are permission-sensitive on macOS because Wi-Fi identification depends on Location Services permission.

### Network fields

Network fields describe the current routing and primary interface state.

Common network fields include:

- `network.primary_interface`
- `network.primary_interface_is_tunnel`
- `network.active_tunnel_interface`
- `network.active_tunnel_interfaces`
- `network.ipv4_address`
- `network.ipv6_address`
- `network.default_gateway`
- `network.dns_servers`
- `network.internet_reachable`
- `network.captive_portal`

The built-in Wi-Fi widget can render `network.ipv4_address` and `network.ipv6_address` in inline and details views. They are network fields, not CoreWLAN fields.

### Auth fields

Auth fields describe permission state:

- `auth.location_authorized`
- `auth.location_permission_state`

## Selectors

Clients can request individual fields or namespace selectors.

Examples:

```json
{
  "command": "fetch",
  "fields": ["wifi.ssid", "network.ipv4_address"]
}
```

```json
{
  "command": "fetch",
  "fields": ["wifi.*"]
}
```

```json
{
  "command": "fetch",
  "fields": ["network.*"]
}
```

```json
{
  "command": "fetch",
  "fields": ["all"]
}
```

Selectors are expanded by the shared protocol layer before values are fetched.

## Snapshot usage

The main EasyBar app subscribes to a stable snapshot field set for the native Wi-Fi widget.

That snapshot contains:

- authorization state
- generated timestamp
- selected Wi-Fi fields
- primary IPv4 and IPv6 addresses
- primary tunnel state

The agent still returns a flat field map. EasyBar converts that field map into the typed snapshot consumed by the native widget.

## Behavior notes

- Wi-Fi fields require location permission.
- Permission denied returns an error unless unauthorized non-sensitive fields are allowed.
- RSSI is smoothed before it is returned.
- Primary IPv4 and IPv6 addresses are read from system network state.
- The agent does not map UI labels.
- The agent does not format values for presentation.
- EasyBar decides how fields are rendered.

EasyBar converts agent values into:

- native widget state
- Lua event payloads
- UI-specific labels and detail rows

## Relationship to native widgets

Agent response:

```json
{
  "network.ipv4_address": "10.0.0.91",
  "network.ipv6_address": "fd88:84dd:4eb:43ba:189a:8f88:cdb5:3a4",
  "wifi.ssid": "Office WiFi"
}
```

Native Wi-Fi inline view:

```text
Office WiFi | 10.0.0.91 | fd88:84dd:4eb:43ba:189a:8f88:cdb5:3a4
```

Native Wi-Fi details view:

```text
SSID:         Office WiFi
IPv4 Address: 10.0.0.91
IPv6 Address: fd88:84dd:4eb:43ba:189a:8f88:cdb5:3a4
```

The native widget owns the final display layout. In inline mode, it joins enabled field values with the configured inline separator. In details mode, it renders labels and values in separate columns.

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
Lua receives structured event data.
