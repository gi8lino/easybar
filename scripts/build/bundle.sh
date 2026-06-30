#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 27 ]; then
  echo "Usage: $0 <dist-dir> <app-macos> <app-resources> <calendar-agent-macos> <calendar-agent-resources> <network-agent-macos> <network-agent-resources> <app-bin> <lua-runtime-bin> <calendar-agent-bin> <network-agent-bin> <cli-bin> <plist-template> <plist> <calendar-agent-plist-template> <calendar-agent-plist> <network-agent-plist-template> <network-agent-plist> <app-bundle> <calendar-agent-bundle> <network-agent-bundle> <arch> <version> <bundle-id> <codesign-identity> <notarytool-profile> <notary-submit>" >&2
  exit 2
fi

dist_dir=$1
app_macos=$2
app_resources=$3
calendar_agent_macos=$4
calendar_agent_resources=$5
network_agent_macos=$6
network_agent_resources=$7
app_bin=$8
lua_runtime_bin=$9
calendar_agent_bin=${10}
network_agent_bin=${11}
cli_bin=${12}
plist_template=${13}
plist=${14}
calendar_agent_plist_template=${15}
calendar_agent_plist=${16}
network_agent_plist_template=${17}
network_agent_plist=${18}
app_bundle=${19}
calendar_agent_bundle=${20}
network_agent_bundle=${21}
arch=${22}
version=${23}
bundle_id=${24}
codesign_identity=${25}
notarytool_profile=${26}
notary_submit=${27}

make_cmd=${MAKE:-make}

rm -rf "$dist_dir" ".build"
mkdir -p \
  "$app_macos" \
  "$app_resources" \
  "$calendar_agent_macos" \
  "$calendar_agent_resources" \
  "$network_agent_macos" \
  "$network_agent_resources" \
  "$dist_dir"

"$make_cmd" --no-print-directory build-app ARCH="$arch" VERSION="$version"
"$make_cmd" --no-print-directory build-lua-runtime ARCH="$arch" VERSION="$version"
"$make_cmd" --no-print-directory build-calendar-agent ARCH="$arch" VERSION="$version"
"$make_cmd" --no-print-directory build-network-agent ARCH="$arch" VERSION="$version"
"$make_cmd" --no-print-directory build-cli ARCH="$arch" VERSION="$version"
"$make_cmd" --no-print-directory copy-resources ARCH="$arch"
"$make_cmd" --no-print-directory icons

cp "$plist_template" "$plist"
cp "$calendar_agent_plist_template" "$calendar_agent_plist"
cp "$network_agent_plist_template" "$network_agent_plist"

"$make_cmd" --no-print-directory stamp-plist VERSION="$version" BUNDLE_ID="$bundle_id"
"$make_cmd" --no-print-directory stamp-calendar-agent-plist VERSION="$version"
"$make_cmd" --no-print-directory stamp-network-agent-plist VERSION="$version"

chmod +x \
  "$app_bin" \
  "$lua_runtime_bin" \
  "$calendar_agent_bin" \
  "$network_agent_bin" \
  "$cli_bin"

"$make_cmd" --no-print-directory sign CODESIGN_IDENTITY="$codesign_identity"
"$make_cmd" --no-print-directory notarize \
  CODESIGN_IDENTITY="$codesign_identity" \
  NOTARYTOOL_PROFILE="$notarytool_profile" \
  NOTARY_SUBMIT="$notary_submit"

touch "$app_bundle" "$calendar_agent_bundle" "$network_agent_bundle"
"$make_cmd" --no-print-directory verify ARCH="$arch"
