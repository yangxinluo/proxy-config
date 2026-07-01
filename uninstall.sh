#!/usr/bin/env bash
# Uninstall Clash proxy shell hooks from Git Bash or WSL.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_MARKER='# >>> clash-proxy >>>'
END_MARKER='# <<< clash-proxy <<<'

WHATIF=false
FORCE=false

usage() {
    echo "usage: $0 [--what-if] [--force]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --what-if) WHATIF=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done

_remove_block() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        echo "No file: ${file}"
        return
    fi
    if ! grep -qF "${START_MARKER}" "${file}" 2>/dev/null; then
        echo "No clash-proxy block in: ${file}"
        return
    fi
    if [[ "${WHATIF}" == true ]]; then
        echo "[WhatIf] Would remove marked block from: ${file}"
        return
    fi
    local tmp
    tmp="$(mktemp)"
    awk -v start="${START_MARKER}" -v end="${END_MARKER}" '
        $0 ~ start { skip=1; next }
        $0 ~ end { skip=0; next }
        !skip { print }
    ' "${file}" > "${tmp}"
    mv "${tmp}" "${file}"
    echo "Removed hook from: ${file}"
}

if [[ "${FORCE}" != true && "${WHATIF}" != true ]]; then
    read -r -p 'Remove Clash proxy hooks? [Y/n] ' answer
    if [[ "${answer}" =~ ^[Nn]$ ]]; then
        echo 'Uninstall cancelled.'
        exit 0
    fi
fi

_remove_block "${HOME}/.bashrc"

if command -v powershell.exe >/dev/null 2>&1; then
    if [[ "${WHATIF}" == true ]]; then
        echo "[WhatIf] Would run uninstall.ps1 for Windows User PATH and env"
    else
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${ROOT}/uninstall.ps1" -Force
    fi
else
    echo "Tip: run uninstall.ps1 on Windows to remove User PATH and CLASH_PROXY_ROOT."
fi

echo ''
echo 'Uninstall complete.'
