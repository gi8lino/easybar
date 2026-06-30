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

rm -rf "$package_stage" "$package_zip"
mkdir -p "$package_stage"

cp -R "$app_bundle" "$package_stage/EasyBar.app"
cp -R "$calendar_agent_bundle" "$package_stage/EasyBarCalendarAgent.app"
cp -R "$network_agent_bundle" "$package_stage/EasyBarNetworkAgent.app"
cp "$cli_bin" "$package_stage/easybar"

(
  cd "$package_stage"
  zip -qry "../$(basename "$package_zip")" \
    "EasyBar.app" \
    "EasyBarCalendarAgent.app" \
    "EasyBarNetworkAgent.app" \
    "easybar"
)

rm -rf "$package_stage"
echo "Created $package_zip"
