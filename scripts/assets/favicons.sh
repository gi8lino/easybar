#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 IMAGE_CONVERT ICON_FONT SVG ICON_DIR SIZE [SIZE ...]" >&2
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing $1. Install ImageMagick or set IMAGE_CONVERT=/path/to/convert." >&2
    exit 1
  fi
}

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing $2: $1" >&2
    exit 1
  fi
}

if [ "$#" -lt 5 ]; then
  usage
  exit 2
fi

image_convert=$1
icon_font=$2
svg=$3
icon_dir=$4
shift 4

require_command "$image_convert"
require_file "$icon_font" "icon font"
require_file "$svg" "icon SVG"
mkdir -p "$icon_dir"

create_icon() {
  size=$1
  outfile=$2
  path="$icon_dir/$outfile"

  echo "create $path"
  "$image_convert" \
    -background none \
    -font "$icon_font" \
    "$svg" \
    -fuzz 5% -transparent white \
    -resize "$size" \
    "$path"

  if [ ! -s "$path" ]; then
    echo "Could not create icon: $path" >&2
    exit 1
  fi
}

for size in "$@"; do
  create_icon "$size" "favicon-$size.png"
done

create_icon 180x180 apple-touch-icon.png
