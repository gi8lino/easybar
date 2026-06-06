#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <app-exec> <calendar-agent-exec> <network-agent-exec> <app-bundle> <calendar-agent-bundle> <network-agent-bundle>" >&2
  exit 2
fi

app_exec="$1"
calendar_agent_exec="$2"
network_agent_exec="$3"
app_bundle="$4"
calendar_agent_bundle="$5"
network_agent_bundle="$6"

if command -v brew >/dev/null 2>&1; then
  brew services stop gi8lino/tap/easybar >/dev/null 2>&1 || true
  brew services stop gi8lino/tap/easybar-calendar-agent >/dev/null 2>&1 || true
  brew services stop gi8lino/tap/easybar-network-agent >/dev/null 2>&1 || true
fi

pkill -x "$app_exec" >/dev/null 2>&1 || true
pkill -x "$calendar_agent_exec" >/dev/null 2>&1 || true
pkill -x "$network_agent_exec" >/dev/null 2>&1 || true
pkill -f "$app_bundle/Contents/MacOS/$app_exec" >/dev/null 2>&1 || true
pkill -f "$calendar_agent_bundle/Contents/MacOS/$calendar_agent_exec" >/dev/null 2>&1 || true
pkill -f "$network_agent_bundle/Contents/MacOS/$network_agent_exec" >/dev/null 2>&1 || true
