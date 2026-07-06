#!/usr/bin/env bash
set -euo pipefail

if ! command -v magick >/dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install imagemagick
fi

if [ ! -x /opt/homebrew/bin/lua ]; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install lua
fi

echo "IMAGE_CONVERT=$(command -v magick)" >>"${GITHUB_ENV:?GITHUB_ENV is required}"

magick -version
/opt/homebrew/bin/lua -v
