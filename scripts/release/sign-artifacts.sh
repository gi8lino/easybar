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

sign_options=()

if [ "$identity" = "-" ]; then
  echo "Signing artifacts with ad-hoc identity"
  sign_options=(--sign -)
else
  echo "Signing artifacts with $identity"
  sign_options=(--options runtime --timestamp --sign "$identity")
fi

sign_bundle() {
  local bundle="$1"
  codesign --force --deep "${sign_options[@]}" "$bundle"
}

sign_binary() {
  local binary="$1"
  codesign --force "${sign_options[@]}" "$binary"
}

sign_bundle "$app_bundle"
sign_bundle "$calendar_agent_bundle"
sign_bundle "$network_agent_bundle"
sign_binary "$cli_bin"
