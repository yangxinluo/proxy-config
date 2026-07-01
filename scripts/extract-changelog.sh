#!/usr/bin/env bash
# Extract the CHANGELOG section for a given version (e.g. 1.4.0).
# Usage: extract-changelog.sh <version> [changelog-file]

set -euo pipefail

VERSION="${1:?usage: extract-changelog.sh <version> [changelog-file]}"
CHANGELOG="${2:-CHANGELOG.md}"

if [[ ! -f "$CHANGELOG" ]]; then
    echo "error: changelog not found: ${CHANGELOG}" >&2
    exit 1
fi

found=0
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^##\ \[${VERSION}\] ]]; then
        found=1
        continue
    fi
    if [[ "$found" -eq 1 && "$line" =~ ^##\ \[ ]]; then
        break
    fi
    if [[ "$found" -eq 1 ]]; then
        printf '%s\n' "$line"
    fi
done <"$CHANGELOG"

if [[ "$found" -eq 0 ]]; then
    echo "error: no changelog section for version ${VERSION}" >&2
    exit 1
fi
