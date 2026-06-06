#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <notary-submit> <codesign-identity> <notarytool-profile> <app-bundle> <notary-zip>" >&2
  exit 2
fi

notary_submit="$1"
identity="$2"
profile="$3"
app_bundle="$4"
notary_zip="$5"

if [ "$notary_submit" != "1" ]; then
  echo "Skipping notarization (NOTARY_SUBMIT=$notary_submit)"
elif [ "$identity" = "-" ]; then
  echo "Skipping notarization for ad-hoc signed build"
elif [ -z "$profile" ]; then
  echo "NOTARYTOOL_PROFILE is required when NOTARY_SUBMIT=1" >&2
  exit 1
else
  echo "Submitting $app_bundle for notarization"
  rm -f "$notary_zip"
  ditto -c -k --keepParent "$app_bundle" "$notary_zip"
  xcrun notarytool submit "$notary_zip" --keychain-profile "$profile" --wait
  xcrun stapler staple "$app_bundle"
fi
