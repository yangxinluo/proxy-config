#!/usr/bin/env bash
# User-level environment persistence (Windows User env + WSL ~/.bashrc export block).

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-config.sh"

PERSIST_ENV_START='# >>> clash-proxy-env >>>'
PERSIST_ENV_END='# <<< clash-proxy-env <<<'

_PERSIST_PROXY_KEYS=(HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy)

_persist_env_is_wsl() {
    [[ "${CLASH_PROXY_PLATFORM:-}" == "wsl2" ]]
}

_persist_env_powershell_set() {
    local key="$1"
    local value="$2"
    _validate_proxy_env_key "$key" || return 1
    export _CLASH_PERSIST_KEY="$key"
    export _CLASH_PERSIST_VALUE="$value"
    powershell.exe -NoProfile -Command \
        "[Environment]::SetEnvironmentVariable(\$env:_CLASH_PERSIST_KEY, \$env:_CLASH_PERSIST_VALUE, 'User')" 2>/dev/null
    unset _CLASH_PERSIST_KEY _CLASH_PERSIST_VALUE
}

_persist_env_powershell_clear() {
    local key="$1"
    _validate_proxy_env_key "$key" || return 1
    export _CLASH_PERSIST_KEY="$key"
    powershell.exe -NoProfile -Command \
        "[Environment]::SetEnvironmentVariable(\$env:_CLASH_PERSIST_KEY, \$null, 'User')" 2>/dev/null
    unset _CLASH_PERSIST_KEY
}

_persist_env_powershell_get() {
    local key="$1"
    _validate_proxy_env_key "$key" || return 1
    export _CLASH_PERSIST_KEY="$key"
    powershell.exe -NoProfile -Command \
        "[Environment]::GetEnvironmentVariable(\$env:_CLASH_PERSIST_KEY, 'User')" 2>/dev/null | tr -d '\r'
    unset _CLASH_PERSIST_KEY
}

persist_env_on() {
    local http_url="$1"
    local socks_url="$2"
    local no_proxy_val="${3:-$NO_PROXY}"

    if _persist_env_is_wsl; then
        local bashrc="${HOME}/.bashrc"
        local backup_suffix
        backup_suffix="$(date +%Y%m%d 2>/dev/null || echo backup)"
        if [[ -f "$bashrc" ]]; then
            cp "$bashrc" "${bashrc}.bak.clash-proxy-env-${backup_suffix}" 2>/dev/null || true
        fi
        if grep -qF "$PERSIST_ENV_START" "$bashrc" 2>/dev/null; then
            local tmp
            tmp="$(mktemp)"
            awk -v start="$PERSIST_ENV_START" -v end="$PERSIST_ENV_END" '
                $0 ~ start { skip=1; next }
                $0 ~ end { skip=0; next }
                !skip { print }
            ' "$bashrc" >"$tmp"
            mv "$tmp" "$bashrc"
        fi
        {
            echo "$PERSIST_ENV_START"
            echo "export HTTP_PROXY=\"${http_url}\""
            echo "export HTTPS_PROXY=\"${http_url}\""
            echo "export ALL_PROXY=\"${socks_url}\""
            echo "export NO_PROXY=\"${no_proxy_val}\""
            echo "export http_proxy=\"${http_url}\""
            echo "export https_proxy=\"${http_url}\""
            echo "export all_proxy=\"${socks_url}\""
            echo "export no_proxy=\"${no_proxy_val}\""
            echo "$PERSIST_ENV_END"
        } >>"$bashrc"
        return 0
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        _persist_env_powershell_set HTTP_PROXY "$http_url"
        _persist_env_powershell_set HTTPS_PROXY "$http_url"
        _persist_env_powershell_set ALL_PROXY "$socks_url"
        _persist_env_powershell_set NO_PROXY "$no_proxy_val"
        _persist_env_powershell_set http_proxy "$http_url"
        _persist_env_powershell_set https_proxy "$http_url"
        _persist_env_powershell_set all_proxy "$socks_url"
        _persist_env_powershell_set no_proxy "$no_proxy_val"
    fi
}

persist_env_off() {
    if _persist_env_is_wsl; then
        local bashrc="${HOME}/.bashrc"
        if [[ -f "$bashrc" ]] && grep -qF "$PERSIST_ENV_START" "$bashrc" 2>/dev/null; then
            local backup_suffix tmp
            backup_suffix="$(date +%Y%m%d 2>/dev/null || echo backup)"
            cp "$bashrc" "${bashrc}.bak.clash-proxy-env-${backup_suffix}" 2>/dev/null || true
            tmp="$(mktemp)"
            awk -v start="$PERSIST_ENV_START" -v end="$PERSIST_ENV_END" '
                $0 ~ start { skip=1; next }
                $0 ~ end { skip=0; next }
                !skip { print }
            ' "$bashrc" >"$tmp"
            mv "$tmp" "$bashrc"
        fi
        return 0
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        local key
        for key in "${_PERSIST_PROXY_KEYS[@]}"; do
            _persist_env_powershell_clear "$key"
        done
    fi
}

persist_env_status() {
    local key val any=0

    if _persist_env_is_wsl; then
        if [[ -f "${HOME}/.bashrc" ]] && grep -qF "$PERSIST_ENV_START" "${HOME}/.bashrc" 2>/dev/null; then
            echo "  user env:    on (WSL ~/.bashrc clash-proxy-env block)"
            return 0
        fi
        echo "  user env:    off"
        return 0
    fi

    if command -v powershell.exe >/dev/null 2>&1; then
        for key in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
            val="$(_persist_env_powershell_get "$key")"
            if [[ -n "$val" ]]; then
                if [[ "$any" -eq 0 ]]; then
                    echo "  user env:"
                    any=1
                fi
                echo "    ${key}: ${val}"
            fi
        done
    fi

    if [[ "$any" -eq 0 ]]; then
        echo "  user env:    off"
    fi
}
