#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 9 ]; then
  echo "Usage: $0 <package-zip> <app-bin> <plist> <app-icon-icns> <calendar-icon-icns> <network-icon-icns> <app-resource-bundle> <app-themes-dir> <app-bundle>" >&2
  exit 2
fi

package_zip="$1"
app_bin="$2"
plist="$3"
app_icon_icns="$4"
calendar_icon_icns="$5"
network_icon_icns="$6"
app_resource_bundle="$7"
app_themes_dir="$8"
app_bundle="$9"

test -f "$package_zip"
test -f "$app_resource_bundle/easybar_api.lua"
test -f "$app_themes_dir/default.toml"

echo "Release package:"
ls -lh "$package_zip"
echo "Build fingerprints:"
shasum -a 256 "$app_bin"
shasum -a 256 "$plist"
shasum -a 256 "$app_icon_icns"
shasum -a 256 "$calendar_icon_icns"
shasum -a 256 "$network_icon_icns"
shasum -a 256 "$app_resource_bundle/easybar_api.lua"
shasum -a 256 "$app_themes_dir/default.toml"
shasum -a 256 "$package_zip"
codesign -dv --verbose=4 "$app_bundle" 2>&1 || true
