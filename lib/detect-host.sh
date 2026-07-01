#!/usr/bin/env bash
# Platform detection and Clash host resolution for Git Bash and WSL2.

detect_clash_platform() {
    if [[ -n "${CLASH_PROXY_PLATFORM:-}" ]]; then
        return 0
    fi

    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        CLASH_PROXY_PLATFORM="wsl2"
    elif [[ -n "${MSYSTEM:-}" ]] || [[ -n "${MINGW_PREFIX:-}" ]]; then
        CLASH_PROXY_PLATFORM="git-bash"
    elif [[ "$(uname -s 2>/dev/null)" == "Linux" ]]; then
        CLASH_PROXY_PLATFORM="linux"
    else
        CLASH_PROXY_PLATFORM="unknown"
    fi
    export CLASH_PROXY_PLATFORM
}

detect_clash_host() {
    detect_clash_platform

    if [[ -n "${HOST:-}" ]]; then
        CLASH_PROXY_HOST="$HOST"
        export CLASH_PROXY_HOST
        return 0
    fi

    case "$CLASH_PROXY_PLATFORM" in
        git-bash)
            CLASH_PROXY_HOST="127.0.0.1"
            ;;
        wsl2)
            local nameserver gateway
            if [[ -f /etc/resolv.conf ]]; then
                nameserver="$(awk '/^nameserver[[:space:]]+/ { print $2; exit }' /etc/resolv.conf)"
            fi
            if [[ -n "$nameserver" && "$nameserver" != "127.0.0.1" && "$nameserver" != "127.0.0.53" ]]; then
                CLASH_PROXY_HOST="$nameserver"
            else
                gateway="$(ip route show default 2>/dev/null | awk '/default/ { print $3; exit }')"
                CLASH_PROXY_HOST="${gateway:-127.0.0.1}"
            fi
            ;;
        *)
            CLASH_PROXY_HOST="127.0.0.1"
            ;;
    esac
    export CLASH_PROXY_HOST
}
