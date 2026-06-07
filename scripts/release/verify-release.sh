#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 9 ]; then
  echo "Usage: $0 <package-zip> <app-bin> <plist> <app-icon-icns> <calendar-icon-icns> <network-icon-icns> <app-resource-dir> <app-themes-dir> <app-bundle>" >&2
  exit 2
fi

package_zip="$1"
app_bin="$2"
plist="$3"
app_icon_icns="$4"
calendar_icon_icns="$5"
network_icon_icns="$6"
app_resource_dir="$7"
app_themes_dir="$8"
app_bundle="$9"

require_file() {
  local path="$1"
  local label="$2"

  if [ ! -f "$path" ]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

require_file "$package_zip" "release package"
require_file "$app_resource_dir/Lua/easybar_api.lua" "Lua API stub"
require_file "$app_resource_dir/Lua/runtime.lua" "Lua runtime"
require_file "$app_resource_dir/Events/event_catalog.json" "event catalog"
require_file "$app_resource_dir/ThemeTokens/theme_tokens.json" "theme token catalog"
require_file "$app_themes_dir/default.toml" "default bundled theme"

echo "Release package:"
ls -lh "$package_zip"
echo "Build fingerprints:"
shasum -a 256 "$app_bin"
shasum -a 256 "$plist"
shasum -a 256 "$app_icon_icns"
shasum -a 256 "$calendar_icon_icns"
shasum -a 256 "$network_icon_icns"
shasum -a 256 "$app_resource_dir/Lua/easybar_api.lua"
shasum -a 256 "$app_themes_dir/default.toml"
shasum -a 256 "$package_zip"
codesign -dv --verbose=4 "$app_bundle" 2>&1 || true
