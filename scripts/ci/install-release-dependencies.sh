#!/usr/bin/env bash
set -euo pipefail

brew update

if ! command -v magick >/dev/null 2>&1; then
  brew install imagemagick
fi

if [ ! -x /opt/homebrew/bin/lua ]; then
  brew install lua
fi

echo "IMAGE_CONVERT=$(command -v magick)" >> "${GITHUB_ENV:?GITHUB_ENV is required}"

magick -version
/opt/homebrew/bin/lua -v
