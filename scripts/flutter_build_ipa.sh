#!/usr/bin/env bash
# Builds an IPA using --build-name / --build-number from pubspec.yaml so
# CFBundleVersion always matches App Store requirements (must increase each upload).
# In Codemagic: use this script for the iOS build step INSTEAD of plain "flutter build ipa".
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LINE="$(grep '^version:' pubspec.yaml | head -1 | sed 's/^version:[[:space:]]*//;s/[[:space:]]*$//')"
if [[ "$LINE" != *+* ]]; then
  echo "pubspec version must use the form 1.2.3+456 (got: $LINE)" >&2
  exit 1
fi
BUILD_NAME="${LINE%+*}"
BUILD_NUMBER="${LINE#*+}"

echo "flutter_build_ipa: build-name=$BUILD_NAME build-number=$BUILD_NUMBER"
flutter build ipa --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" "$@"
