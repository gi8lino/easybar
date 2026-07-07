#!/usr/bin/env bash
set -euo pipefail

if ! command -v magick >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install imagemagick
fi

if ! command -v lua >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install lua
fi

image_convert=$(command -v magick)
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "IMAGE_CONVERT=${image_convert}" >>"$GITHUB_ENV"
else
  echo "IMAGE_CONVERT=${image_convert}"
fi

magick -version
lua -v
