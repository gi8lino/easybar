#!/usr/bin/env bash
set -euo pipefail

missing=()

required_files=(
  "Makefile"
  "Package.swift"
  "LICENSE"
  "config.defaults.toml"
  "themes/default.toml"
  "Sources/EasyBarApp/Info.plist"
  "Sources/EasyBarCalendarAgent/Info.plist"
  "Sources/EasyBarNetworkAgent/Info.plist"
  "Sources/EasyBarApp/Events/event_catalog.json"
  "Sources/EasyBarApp/Theme/theme_tokens.json"
  "Sources/EasyBarApp/Lua/easybar_api.base.lua"
  "Sources/EasyBarApp/Lua/easybar_api.events.lua"
  "Sources/EasyBarApp/Lua/easybar_api.themes.lua"
  "Sources/EasyBarApp/Lua/easybar_api.lua"
  "Sources/EasyBarApp/Lua/easybar/event_tokens.lua"
  "Sources/EasyBarApp/Lua/easybar/theme_tokens.lua"
  "scripts/assets/app_icons.sh"
  "scripts/assets/favicons.sh"
  "scripts/build/build-products.sh"
  "scripts/build/bundle.sh"
  "scripts/build/copy-resources.sh"
  "scripts/build/stamp-plist.sh"
  "scripts/build/stamp_build_info.py"
  "scripts/build/verify-bundle.sh"
  "scripts/ci/install-lua.sh"
  "scripts/ci/install-release-dependencies.sh"
  "scripts/ci/run-swift-tests.sh"
  "scripts/dev/run-local.sh"
  "scripts/dev/stop-local.sh"
  "scripts/generate/theme_tokens.py"
  "scripts/generate/event_catalog.py"
  "scripts/generate/lua_reference_docs.py"
  "scripts/generate/config_reference_docs.py"
  "scripts/generate/generated_artifacts.py"
  "scripts/release/package.sh"
  "scripts/release/update-homebrew-formulas.sh"
  "packaging/easybar-icon.svg"
  "packaging/easybar-calendar-agent-icon.svg"
  "packaging/easybar-network-agent-icon.svg"
)

for file in "${required_files[@]}"; do
  if [ ! -e "${file}" ]; then
    missing+=("${file}")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Required source-tree inputs are missing:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

tap_dir="$(mktemp -d)"
trap 'rm -rf "${tap_dir}"' EXIT

scripts/release/update-homebrew-formulas.sh \
  --tap-dir "${tap_dir}" \
  --repository "gi8lino/easybar" \
  --tag "v0.0.0" \
  --version "0.0.0" \
  --sha "0000000000000000000000000000000000000000000000000000000000000000"

easybar_formula="${tap_dir}/Formula/easybar.rb"
calendar_formula="${tap_dir}/Formula/easybar-calendar-agent.rb"
network_formula="${tap_dir}/Formula/easybar-network-agent.rb"

grep -q 'depends_on "lua"' "${easybar_formula}"
grep -q 'depends_on "easybar-calendar-agent"' "${easybar_formula}"
grep -q 'depends_on "easybar-network-agent"' "${easybar_formula}"
grep -q 'libexec.install "EasyBar.app"' "${easybar_formula}"
grep -q 'libexec.install "EasyBarCalendarAgent.app"' "${calendar_formula}"
grep -q 'libexec.install "EasyBarNetworkAgent.app"' "${network_formula}"

echo "Source tree and generated formula smoke checks passed."




