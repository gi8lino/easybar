#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "Usage: $0 <debug|release> <arm64|x86_64|universal> <resource-bundle-name> <app-bundle> <app-resource-dir> <themes-dir> <app-themes-dir>" >&2
  exit 2
fi

configuration="$1"
arch="$2"
resource_bundle_name="$3"
app_bundle="$4"
app_resource_dir="$5"
themes_dir="$6"
app_themes_dir="$7"

case "$configuration" in
debug | release) ;;
*)
  echo "Unsupported configuration '$configuration'. Use debug or release." >&2
  exit 2
  ;;
esac

case "$arch" in
arm64 | x86_64) source_arch="$arch" ;;
universal) source_arch="arm64" ;;
*)
  echo "Unsupported architecture '$arch'. Use arm64, x86_64, or universal." >&2
  exit 2
  ;;
esac

build_dir=".build/$source_arch-apple-macosx/$configuration"
resource_source="$build_dir/$resource_bundle_name"
app_resources_dir="$(dirname "$app_resource_dir")"
legacy_app_root_bundle="$app_bundle/$resource_bundle_name"
legacy_app_resources_bundle="$app_resources_dir/$resource_bundle_name"

mkdir -p "$app_resource_dir/Lua" "$app_resource_dir/Events" "$app_resource_dir/ThemeTokens" "$app_resource_dir/Assets" "$(dirname "$app_themes_dir")"
rm -rf \
  "$app_resource_dir" \
  "$app_themes_dir" \
  "$legacy_app_root_bundle" \
  "$legacy_app_resources_bundle"
mkdir -p "$app_resource_dir/Lua" "$app_resource_dir/Events" "$app_resource_dir/ThemeTokens" "$app_resource_dir/Assets"

if [ ! -d "$resource_source" ]; then
  echo "Missing resource bundle: $resource_source" >&2
  find "$build_dir" -maxdepth 1 -name '*.bundle' -print 2>/dev/null || true
  exit 1
fi

copy_required_file() {
  local source_file="$1"
  local destination_file="$2"

  if [ ! -f "$source_file" ]; then
    echo "Missing required resource: $source_file" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$destination_file")"
  cp "$source_file" "$destination_file"
}

copy_required_dir() {
  local source_dir="$1"
  local destination_dir="$2"

  if [ ! -d "$source_dir" ]; then
    echo "Missing required resource directory: $source_dir" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$destination_dir")"
  cp -R "$source_dir" "$destination_dir"
}

copy_required_file "$resource_source/runtime.lua" "$app_resource_dir/Lua/runtime.lua"
copy_required_file "$resource_source/easybar_api.lua" "$app_resource_dir/Lua/easybar_api.lua"
copy_required_dir "$resource_source/easybar" "$app_resource_dir/Lua/easybar"
copy_required_file "$resource_source/event_catalog.json" "$app_resource_dir/Events/event_catalog.json"
copy_required_file "$resource_source/theme_tokens.json" "$app_resource_dir/ThemeTokens/theme_tokens.json"
copy_required_file "$resource_source/easybar-menubar.svg" "$app_resource_dir/Assets/easybar-menubar.svg"

if [ ! -d "$themes_dir" ]; then
  echo "Missing themes directory: $themes_dir" >&2
  exit 1
fi

cp -R "$themes_dir" "$app_themes_dir"

if [ ! -f "$app_themes_dir/default.toml" ]; then
  echo "Missing bundled theme: $app_themes_dir/default.toml" >&2
  exit 1
fi
