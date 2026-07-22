#!/usr/bin/env bash
#
# run-macos-mock.sh -- HOST driver for Task 2 (macOS shell-logic mock).
# NOT a macOS runtime test -- see Dockerfile.macos-mock / the transcript disclaimer.
# Builds the mock-Darwin image and runs deploy/macos/install-macos.sh under it in
# arm64 + Intel brew-prefix modes, then validates the generated plists/config.
#
# Usage:  bash run-macos-mock.sh [language]   (default: hi)
set -euo pipefail

LANG_CODE="${1:-hi}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) REPO_MOUNT="$(cygpath -w "$REPO_ROOT")" ;;
  *)                    REPO_MOUNT="$REPO_ROOT" ;;
esac

echo "==================================================================="
echo " macOS MOCK (shell-logic ONLY, NOT a macOS runtime test)  lang=$LANG_CODE"
echo "==================================================================="
docker build -f Dockerfile.macos-mock -t upes-macos-mock:latest .
docker run --rm \
  -v "${REPO_MOUNT}:/repo:ro" \
  -v "${HERE}:/out" \
  -e "OUT=/out/transcript-macos-mock.txt" \
  upes-macos-mock:latest "$LANG_CODE" \
  || echo "(container exited non-zero -- see transcript-macos-mock.txt for the matrix)"

echo
echo "== cleaning up mock image =="
docker rmi upes-macos-mock:latest >/dev/null 2>&1 || true
echo "Transcript written to $HERE/transcript-macos-mock.txt"
