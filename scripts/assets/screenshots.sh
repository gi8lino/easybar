#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo "Usage: $0 IMAGE_CONVERT MANIFEST RAW_DIR OUTPUT_DIR [--check]" >&2
  exit 2
fi

image_convert=$1
manifest=$2
raw_dir=$3
output_dir=$4
mode=${5:-write}

if ! command -v "$image_convert" >/dev/null 2>&1; then
  echo "Missing $image_convert. Install ImageMagick or set IMAGE_CONVERT." >&2
  exit 1
fi

if [[ ! -f "$manifest" ]]; then
  echo "Screenshot manifest not found: $manifest" >&2
  exit 1
fi

target_dir=$output_dir
temporary_dir=
if [[ "$mode" == "--check" ]]; then
  temporary_dir=$(mktemp -d)
  trap 'rm -rf "$temporary_dir"' EXIT
  target_dir=$temporary_dir
elif [[ "$mode" != "write" ]]; then
  echo "Unknown mode: $mode" >&2
  exit 2
fi

mkdir -p "$target_dir"
while IFS='|' read -r name crop padding; do
  [[ -z "$name" || "$name" == \#* ]] && continue

  source="$raw_dir/$name.png"
  output="$target_dir/$name.png"
  if [[ ! -f "$source" ]]; then
    echo "Raw screenshot not found: $source" >&2
    exit 1
  fi

  arguments=("$source")
  if [[ "$crop" != "-" ]]; then
    arguments+=(-crop "$crop" +repage)
  fi
  if ((padding > 0)); then
    arguments+=(-bordercolor none -border "$padding")
  fi
  arguments+=(-strip -define png:exclude-chunks=date,time "$output")
  "$image_convert" "${arguments[@]}"

  if [[ "$mode" == "--check" ]] && ! cmp -s "$output" "$output_dir/$name.png"; then
    echo "Generated screenshot is stale: $output_dir/$name.png" >&2
    exit 1
  fi
done <"$manifest"
