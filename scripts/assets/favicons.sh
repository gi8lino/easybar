#!/bin/sh
set -eu

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 IMAGE_CONVERT ICON_FONT SVG ICON_DIR SIZE [SIZE ...]" >&2
  exit 2
fi

image_convert=$1
icon_font=$2
svg=$3
icon_dir=$4
shift 4

if ! command -v "$image_convert" >/dev/null 2>&1; then
  echo "Missing $image_convert. Install ImageMagick or set IMAGE_CONVERT=/path/to/convert." >&2
  exit 1
fi

if [ ! -f "$icon_font" ]; then
  echo "Missing icon font: $icon_font" >&2
  exit 1
fi

if [ ! -f "$svg" ]; then
  echo "Missing icon SVG: $svg" >&2
  exit 1
fi

mkdir -p "$icon_dir"

for size in "$@"; do
  outfile="favicon-$size.png"
  echo "create $outfile"
  "$image_convert" \
    -background none \
    -font "$icon_font" \
    "$svg" \
    -fuzz 5% -transparent white \
    -resize "$size" \
    "$icon_dir/$outfile" \
    >/dev/null 2>&1
done

echo "create apple-touch-icon.png"
"$image_convert" \
  -background none \
  -font "$icon_font" \
  "$svg" \
  -fuzz 5% -transparent white \
  -resize 180x180 \
  "$icon_dir/apple-touch-icon.png" \
  >/dev/null 2>&1
