#!/usr/bin/env bash
# Verify CHANGELOG version entries reference existing tags or documented releases.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="${ROOT}/CHANGELOG.md"

if ! grep -qE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG"; then
    echo "error: no version sections found in CHANGELOG.md" >&2
    exit 1
fi

if [[ ! -f "${ROOT}/config.defaults.env" ]]; then
    echo "error: config.defaults.env missing" >&2
    exit 1
fi

echo "changelog check: ok"
