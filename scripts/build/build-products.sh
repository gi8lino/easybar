#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <debug|release> <arm64|x86_64|universal> <product=output> [...]" >&2
  exit 2
fi

configuration=$1
arch=$2
shift 2

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

products=()
outputs=()
for pair in "$@"; do
  case "$pair" in
    *=*) ;;
    *)
      echo "Invalid product mapping '$pair'. Expected <product=output>." >&2
      exit 2
      ;;
  esac

  product=${pair%%=*}
  output=${pair#*=}
  if [ -z "$product" ] || [ -z "$output" ]; then
    echo "Invalid product mapping '$pair'. Expected non-empty product and output." >&2
    exit 2
  fi

  products+=("$product")
  outputs+=("$output")
  mkdir -p "$(dirname "$output")"
done

build_arch() {
  local build_arch=$1
  local args=(swift build -c "$configuration" --arch "$build_arch")

  for product in "${products[@]}"; do
    args+=(--product "$product")
  done

  "${args[@]}"
}

copy_arch_outputs() {
  local built_arch=$1
  local index=0
  local build_dir=".build/${built_arch}-apple-macosx/${configuration}"

  while [ "$index" -lt "${#products[@]}" ]; do
    cp "${build_dir}/${products[$index]}" "${outputs[$index]}"
    index=$((index + 1))
  done
}

lipo_universal_outputs() {
  local index=0

  while [ "$index" -lt "${#products[@]}" ]; do
    lipo -create \
      ".build/arm64-apple-macosx/${configuration}/${products[$index]}" \
      ".build/x86_64-apple-macosx/${configuration}/${products[$index]}" \
      -output "${outputs[$index]}"
    index=$((index + 1))
  done
}

if [ "$arch" = "universal" ]; then
  build_arch arm64
  build_arch x86_64
  lipo_universal_outputs
else
  build_arch "$arch"
  copy_arch_outputs "$arch"
fi
