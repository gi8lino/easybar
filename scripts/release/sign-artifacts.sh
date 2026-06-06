#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <codesign-identity> <app-bundle> <calendar-agent-bundle> <network-agent-bundle> <cli-bin>" >&2
  exit 2
fi

identity="$1"
app_bundle="$2"
calendar_agent_bundle="$3"
network_agent_bundle="$4"
cli_bin="$5"

if [ "$identity" = "-" ]; then
  echo "Signing artifacts with ad-hoc identity"
  codesign --force --deep --sign - "$app_bundle"
  codesign --force --deep --sign - "$calendar_agent_bundle"
  codesign --force --deep --sign - "$network_agent_bundle"
  codesign --force --sign - "$cli_bin"
else
  echo "Signing artifacts with $identity"
  codesign --force --deep --options runtime --timestamp --sign "$identity" "$app_bundle"
  codesign --force --deep --options runtime --timestamp --sign "$identity" "$calendar_agent_bundle"
  codesign --force --deep --options runtime --timestamp --sign "$identity" "$network_agent_bundle"
  codesign --force --options runtime --timestamp --sign "$identity" "$cli_bin"
fi
