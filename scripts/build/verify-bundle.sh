#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 20 ]; then
  echo "Usage: $0 <arch> <app-bin> <lua-runtime-bin> <calendar-agent-bin> <network-agent-bin> <cli-bin> <plist> <calendar-plist> <network-plist> <app-resource-bundle> <app-themes-dir> <app-icon-icns> <calendar-icon-icns> <network-icon-icns> <app-icon-file> <calendar-icon-file> <network-icon-file> <app-bundle> <app-contents> <app-resources>" >&2
  exit 2
fi

arch="$1"
app_bin="$2"
lua_runtime_bin="$3"
calendar_agent_bin="$4"
network_agent_bin="$5"
cli_bin="$6"
plist="$7"
calendar_plist="$8"
network_plist="$9"
app_resource_bundle="${10}"
app_themes_dir="${11}"
app_icon_icns="${12}"
calendar_icon_icns="${13}"
network_icon_icns="${14}"
app_icon_file="${15}"
calendar_icon_file="${16}"
network_icon_file="${17}"
app_bundle="${18}"
app_contents="${19}"
app_resources="${20}"

echo "Built $arch artifacts:"
file "$app_bin"
file "$lua_runtime_bin"
file "$calendar_agent_bin"
file "$network_agent_bin"
file "$cli_bin"

test -f "$plist"
test -f "$calendar_plist"
test -f "$network_plist"
test -d "$app_resource_bundle"
test -d "$app_themes_dir"
test -s "$app_icon_icns"
test -s "$calendar_icon_icns"
test -s "$network_icon_icns"

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" = "$app_icon_file"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$calendar_plist")" = "$calendar_icon_file"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$network_plist")" = "$network_icon_file"

echo "Info.plist:"
plutil -p "$plist"
echo "Calendar agent Info.plist:"
plutil -p "$calendar_plist"
echo "Network agent Info.plist:"
plutil -p "$network_plist"
echo "Packaged app root:"
ls -1 "$app_bundle"
echo "Packaged Contents:"
ls -1 "$app_contents"
echo "Packaged Resources:"
ls -1 "$app_resources" 2>/dev/null || true
