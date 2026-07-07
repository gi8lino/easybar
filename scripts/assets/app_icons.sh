#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 IMAGE_CONVERT ICON_FONT DIST_DIR SVG:ICNS [SVG:ICNS ...]" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing $1. $2" >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing $2: $1" >&2
    exit 1
  fi
}

if [ "$#" -lt 4 ]; then
  usage
  exit 2
fi

image_convert=$1
icon_font=$2
dist_dir=$3
shift 3

require_command "$image_convert" "Install ImageMagick or set IMAGE_CONVERT=/path/to/convert."
require_command sips "This target must run on macOS."
require_command iconutil "This target must run on macOS."
require_file "$icon_font" "icon font"

create_icon_variant() {
  size=$1
  output=$2
  sips -z "$size" "$size" "$rendered_png" --out "$tmp_dir/$output" >/dev/null
}

for spec in "$@"; do
  svg=${spec%%:*}
  icns=${spec#*:}
  base=$(basename "$icns" .icns)
  tmp_dir="$dist_dir/.$base.iconset"
  render_dir="$dist_dir/.$base.render"
  rendered_png="$render_dir/icon_1024x1024.png"

  require_file "$svg" "icon SVG"

  rm -rf "$tmp_dir" "$render_dir" "$icns"
  mkdir -p "$(dirname "$icns")" "$tmp_dir" "$render_dir"

  "$image_convert" \
    -background none \
    -font "$icon_font" \
    -density 1024 \
    "$svg" \
    -resize 1024x1024 \
    -gravity center \
    -extent 1024x1024 \
    "$rendered_png"

  require_file "$rendered_png" "rendered SVG icon"

  cp "$rendered_png" "$tmp_dir/icon_512x512@2x.png"
  create_icon_variant 16 icon_16x16.png
  create_icon_variant 32 icon_16x16@2x.png
  create_icon_variant 32 icon_32x32.png
  create_icon_variant 64 icon_32x32@2x.png
  create_icon_variant 128 icon_128x128.png
  create_icon_variant 256 icon_128x128@2x.png
  create_icon_variant 256 icon_256x256.png
  create_icon_variant 512 icon_256x256@2x.png
  create_icon_variant 512 icon_512x512.png

  iconutil -c icns "$tmp_dir" -o "$icns"

  if [ ! -s "$icns" ]; then
    echo "Could not create icon: $icns" >&2
    exit 1
  fi

  rm -rf "$tmp_dir" "$render_dir"
done
