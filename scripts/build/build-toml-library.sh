#!/usr/bin/env bash
set -euo pipefail

configuration=${1:-debug}
arch=${2:-$(uname -m)}
manifest=Rust/EasyBarTOML/Cargo.toml
output_dir=.build/easybar-toml
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-14.0}

if command -v brew >/dev/null 2>&1 && [ -x "$(brew --prefix rustup 2>/dev/null)/bin/cargo" ]; then
  export PATH="$(brew --prefix rustup)/bin:$PATH"
fi

case "$configuration" in
debug) cargo_profile=debug ;;
release) cargo_profile=release ;;
*)
  echo "Unsupported configuration '$configuration'. Use debug or release." >&2
  exit 2
  ;;
esac

case "$arch" in
arm64) targets=(aarch64-apple-darwin) ;;
x86_64) targets=(x86_64-apple-darwin) ;;
universal) targets=(aarch64-apple-darwin x86_64-apple-darwin) ;;
*)
  echo "Unsupported architecture '$arch'. Use arm64, x86_64, or universal." >&2
  exit 2
  ;;
esac

mkdir -p "$output_dir"
libraries=()
for target in "${targets[@]}"; do
  arguments=(build --manifest-path "$manifest" --target "$target")
  if [ "$configuration" = release ]; then
    arguments+=(--release)
  fi
  cargo "${arguments[@]}"
  libraries+=("Rust/EasyBarTOML/target/$target/$cargo_profile/libeasybar_toml.a")
done

if [ "${#libraries[@]}" -eq 1 ]; then
  cp "${libraries[0]}" "$output_dir/libeasybar_toml.a"
else
  lipo -create "${libraries[@]}" -output "$output_dir/libeasybar_toml.a"
fi
