#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <debug|release> <arm64|x86_64|universal> <product> <output>" >&2
  exit 2
fi

configuration="$1"
arch="$2"
product="$3"
output="$4"

case "$configuration" in
  debug|release) ;;
  *)
    echo "Unsupported configuration '$configuration'. Use debug or release." >&2
    exit 2
    ;;
esac

case "$arch" in
  arm64|x86_64|universal) ;;
  *)
    echo "Unsupported architecture '$arch'. Use arm64, x86_64, or universal." >&2
    exit 2
    ;;
esac

mkdir -p "$(dirname "$output")"

if [ "$arch" = "universal" ]; then
  swift build -c "$configuration" --arch arm64 --product "$product"
  swift build -c "$configuration" --arch x86_64 --product "$product"
  lipo -create \
    ".build/arm64-apple-macosx/$configuration/$product" \
    ".build/x86_64-apple-macosx/$configuration/$product" \
    -output "$output"
else
  swift build -c "$configuration" --arch "$arch" --product "$product"
  cp ".build/$arch-apple-macosx/$configuration/$product" "$output"
fi
