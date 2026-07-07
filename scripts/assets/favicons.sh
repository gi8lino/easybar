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

create_icon() {
  size=$1
  outfile=$2

  echo "create $outfile"
  "$image_convert" \
    -background none \
    -font "$icon_font" \
    "$svg" \
    -fuzz 5% -transparent white \
    -resize "$size" \
    "$icon_dir/$outfile"

  if [ ! -s "$icon_dir/$outfile" ]; then
    echo "Could not create icon: $icon_dir/$outfile" >&2
    exit 1
  fi
}

for size in "$@"; do
  create_icon "$size" "favicon-$size.png"
done

create_icon 180x180 apple-touch-icon.png
