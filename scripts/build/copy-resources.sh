#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 7 ]; then
  echo "Usage: $0 <debug|release> <arm64|x86_64|universal> <resource-bundle-name> <app-bundle> <app-resource-bundle> <themes-dir> <app-themes-dir>" >&2
  exit 2
fi

configuration="$1"
arch="$2"
resource_bundle_name="$3"
app_bundle="$4"
app_resource_bundle="$5"
themes_dir="$6"
app_themes_dir="$7"

case "$configuration" in
  debug|release) ;;
  *)
    echo "Unsupported configuration '$configuration'. Use debug or release." >&2
    exit 2
    ;;
esac

case "$arch" in
  arm64|x86_64) source_arch="$arch" ;;
  universal) source_arch="arm64" ;;
  *)
    echo "Unsupported architecture '$arch'. Use arm64, x86_64, or universal." >&2
    exit 2
    ;;
esac

build_dir=".build/$source_arch-apple-macosx/$configuration"
resource_source="$build_dir/$resource_bundle_name"

mkdir -p "$app_bundle" "$(dirname "$app_themes_dir")"
rm -rf "$app_resource_bundle" "$app_themes_dir"

if [ ! -d "$resource_source" ]; then
  echo "Missing resource bundle: $resource_source" >&2
  find "$build_dir" -maxdepth 1 -name '*.bundle' -print 2>/dev/null || true
  exit 1
fi

cp -R "$resource_source" "$app_resource_bundle"

if [ ! -d "$themes_dir" ]; then
  echo "Missing themes directory: $themes_dir" >&2
  exit 1
fi

cp -R "$themes_dir" "$app_themes_dir"

if [ ! -f "$app_themes_dir/default.toml" ]; then
  echo "Missing bundled theme: $app_themes_dir/default.toml" >&2
  exit 1
fi
