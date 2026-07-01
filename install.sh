#!/usr/bin/env bash
# Install Clash proxy hooks from Git Bash or WSL.
# On Windows, prefer install.ps1 for full setup (User PATH + CLASH_PROXY_ROOT).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${ROOT}/hooks"
START_MARKER='# >>> clash-proxy >>>'
END_MARKER='# <<< clash-proxy <<<'

WHATIF=false
FORCE=false
SKIP_WSL=false

usage() {
    echo "usage: $0 [--what-if] [--force] [--skip-wsl]" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --what-if) WHATIF=true; shift ;;
        --force) FORCE=true; shift ;;
        --skip-wsl) SKIP_WSL=true; shift ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done

_render_snippet() {
    local snippet="$1"
    local proxy_root="$2"
    sed "s|__CLASH_PROXY_ROOT__|${proxy_root}|g" "${snippet}"
}

_install_block() {
    local file="$1"
    local block="$2"
    local dir
    dir="$(dirname "${file}")"
    mkdir -p "${dir}"
    touch "${file}"

    if grep -qF "${START_MARKER}" "${file}" 2>/dev/null; then
        if [[ "${WHATIF}" == true ]]; then
            echo "[WhatIf] Would update marked block in: ${file}"
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
        printf '\n%s' "${block}" >> "${file}"
        echo "Updated hook in: ${file}"
    else
        if [[ "${WHATIF}" == true ]]; then
            echo "[WhatIf] Would append hook to: ${file}"
            return
        fi
        printf '\n%s' "${block}" >> "${file}"
        echo "Installed hook in: ${file}"
    fi
}

_to_git_bash_path() {
    local win_path="$1"
    local normalized drive rest
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "${win_path}"
        return
    fi
    normalized="${win_path//\\//}"
    if [[ "${normalized}" =~ ^([A-Za-z]):/(.*)$ ]]; then
        drive="${BASH_REMATCH[1],,}"
        rest="${BASH_REMATCH[2]}"
        echo "/${drive}/${rest}"
        return
    fi
    echo "${normalized}"
}

_to_wsl_path() {
    local win_path="$1"
    echo "${win_path}" | sed -E 's|^([A-Za-z]):/|/mnt/\L\1/|; s|\\|/|g'
}

if [[ "${FORCE}" != true && "${WHATIF}" != true ]]; then
    echo "This will install shell hooks for Clash proxy at: ${ROOT}"
    read -r -p 'Continue? [Y/n] ' answer
    if [[ "${answer}" =~ ^[Nn]$ ]]; then
        echo 'Install cancelled.'
        exit 0
    fi
fi

# Git Bash / MSYS: ~/.bashrc with Unix-style path
if [[ -n "${MSYSTEM:-}" || "${OSTYPE:-}" == msys* ]]; then
    PROXY_ROOT="$(_to_git_bash_path "${ROOT}")"
    BLOCK="$(_render_snippet "${HOOKS_DIR}/bashrc.snippet" "${PROXY_ROOT}")"
    _install_block "${HOME}/.bashrc" "${BLOCK}"
fi

# WSL: ~/.bashrc with /mnt/... path
if [[ "${SKIP_WSL}" != true ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    if [[ "${ROOT}" == /mnt/* ]]; then
        PROXY_ROOT="${ROOT}"
    else
        PROXY_ROOT="$(_to_wsl_path "${ROOT}")"
    fi
    BLOCK="$(_render_snippet "${HOOKS_DIR}/profile.snippet" "${PROXY_ROOT}")"
    _install_block "${HOME}/.bashrc" "${BLOCK}"
fi

# Try Windows User env via PowerShell when available (Git Bash on Windows)
if command -v powershell.exe >/dev/null 2>&1; then
    if [[ "${WHATIF}" == true ]]; then
        echo "[WhatIf] Would set User CLASH_PROXY_ROOT and PATH via PowerShell"
    else
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${ROOT}/install.ps1" -Force -SkipGitBash -SkipWsl
    fi
else
    echo "Tip: run install.ps1 on Windows for User PATH and CLASH_PROXY_ROOT."
fi

echo ''
echo 'Install complete. Open a new terminal and run: proxy status'
