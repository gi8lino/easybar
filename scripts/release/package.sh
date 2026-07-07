#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <package-stage> <package-zip> <app-bundle> <calendar-agent-bundle> <network-agent-bundle> <cli-bin>" >&2
  exit 2
fi

package_stage=$1
package_zip=$2
app_bundle=$3
calendar_agent_bundle=$4
network_agent_bundle=$5
cli_bin=$6

require_path() {
  local path="$1"
  local label="$2"

  if [ ! -e "$path" ]; then
    echo "Missing ${label}: ${path}" >&2
    exit 1
  fi
}

require_path "$app_bundle" "app bundle"
require_path "$calendar_agent_bundle" "calendar agent bundle"
require_path "$network_agent_bundle" "network agent bundle"
require_path "$cli_bin" "CLI binary"

package_dir=$(dirname "$package_zip")
package_name=$(basename "$package_zip")
mkdir -p "$package_dir"
package_zip="$(cd "$package_dir" && pwd)/${package_name}"

rm -rf "$package_stage" "$package_zip"
mkdir -p "$package_stage"

cp -R "$app_bundle" "$package_stage/EasyBar.app"
cp -R "$calendar_agent_bundle" "$package_stage/EasyBarCalendarAgent.app"
cp -R "$network_agent_bundle" "$package_stage/EasyBarNetworkAgent.app"
cp "$cli_bin" "$package_stage/easybar"

(
  cd "$package_stage"
  zip -qry "$package_zip" \
    "EasyBar.app" \
    "EasyBarCalendarAgent.app" \
    "EasyBarNetworkAgent.app" \
    "easybar"
)

rm -rf "$package_stage"
echo "Created $package_zip"
