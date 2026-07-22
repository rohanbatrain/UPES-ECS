#!/usr/bin/env bash
#
# run-linux-test.sh -- HOST driver for Task 1 (Linux airtight).
# Builds the clean-base image for ubuntu:22.04 AND debian:12, runs the installer
# end-to-end in each, and saves the real transcript to tests/docker/.
#
# Usage:  bash run-linux-test.sh [language]   (default: hi)
# Requires: Docker Desktop (Linux engine). Run from repo root or tests/docker/.
set -euo pipefail

LANG_CODE="${1:-hi}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"

# Docker Desktop on Windows accepts Windows-style paths for -v; normalise.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) REPO_MOUNT="$(cygpath -w "$REPO_ROOT")" ;;
  *)                    REPO_MOUNT="$REPO_ROOT" ;;
esac

run_one() {  # <base-image> <tag> <transcript-name>
  local base="$1" tag="$2" name="$3"
  echo "==================================================================="
  echo " LINUX AIRTIGHT TEST  base=$base  tag=$tag  language=$LANG_CODE"
  echo "==================================================================="
  docker build -f Dockerfile.linux-test --build-arg "BASE=$base" -t "$tag" .
  # Fresh, clean container. Repo read-only; transcript bind-mounted to $HERE.
  docker run --rm \
    -v "${REPO_MOUNT}:/repo:ro" \
    -v "${HERE}:/out" \
    -e "OUT=/out/${name}" \
    "$tag" "$LANG_CODE" || echo "(container exited non-zero -- see ${name} for the PASS/FAIL matrix)"
}

run_one "ubuntu:22.04" "upes-linux-test:ubuntu" "transcript-linux-ubuntu2204.txt"
run_one "debian:12"    "upes-linux-test:debian" "transcript-linux-debian12.txt"

echo
echo "== cleaning up test images =="
docker rmi upes-linux-test:ubuntu upes-linux-test:debian >/dev/null 2>&1 || true
echo "Transcripts written to $HERE"
