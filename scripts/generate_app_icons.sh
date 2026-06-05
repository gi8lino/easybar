#!/bin/sh
set -eu

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 IMAGE_CONVERT ICON_FONT DIST_DIR SVG:ICNS [SVG:ICNS ...]" >&2
  exit 2
fi

image_convert=$1
icon_font=$2
dist_dir=$3
shift 3

if ! command -v "$image_convert" >/dev/null 2>&1; then
  echo "Missing $image_convert. Install ImageMagick or set IMAGE_CONVERT=/path/to/convert." >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "Missing sips. This target must run on macOS." >&2
  exit 1
fi

if ! command -v iconutil >/dev/null 2>&1; then
  echo "Missing iconutil. This target must run on macOS." >&2
  exit 1
fi

if [ ! -f "$icon_font" ]; then
  echo "Missing icon font: $icon_font" >&2
  exit 1
fi

for spec in "$@"; do
  svg=${spec%%:*}
  icns=${spec#*:}
  base=$(basename "$icns" .icns)
  tmp_dir="$dist_dir/.$base.iconset"
  render_dir="$dist_dir/.$base.render"
  rendered_png="$render_dir/icon_1024x1024.png"

  if [ ! -f "$svg" ]; then
    echo "Missing icon SVG: $svg" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$icns")" "$tmp_dir" "$render_dir"
  rm -rf "$tmp_dir" "$render_dir" "$icns"
  mkdir -p "$tmp_dir" "$render_dir"

  "$image_convert" \
    -background none \
    -font "$icon_font" \
    -density 1024 \
    "$svg" \
    -resize 1024x1024 \
    -gravity center \
    -extent 1024x1024 \
    "$rendered_png"

  if [ ! -f "$rendered_png" ]; then
    echo "Could not render SVG icon: $svg" >&2
    exit 1
  fi

  cp "$rendered_png" "$tmp_dir/icon_512x512@2x.png"
  sips -z 16 16 "$rendered_png" --out "$tmp_dir/icon_16x16.png" >/dev/null
  sips -z 32 32 "$rendered_png" --out "$tmp_dir/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$rendered_png" --out "$tmp_dir/icon_32x32.png" >/dev/null
  sips -z 64 64 "$rendered_png" --out "$tmp_dir/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$rendered_png" --out "$tmp_dir/icon_128x128.png" >/dev/null
  sips -z 256 256 "$rendered_png" --out "$tmp_dir/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$rendered_png" --out "$tmp_dir/icon_256x256.png" >/dev/null
  sips -z 512 512 "$rendered_png" --out "$tmp_dir/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$rendered_png" --out "$tmp_dir/icon_512x512.png" >/dev/null

  iconutil -c icns "$tmp_dir" -o "$icns"

  if [ ! -s "$icns" ]; then
    echo "Could not create icon: $icns" >&2
    exit 1
  fi

  rm -rf "$tmp_dir" "$render_dir"
done
