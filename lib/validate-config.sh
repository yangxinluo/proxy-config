#!/usr/bin/env bash
# Configuration validation shared by proxy-invoke.sh.

_validate_host() {
    local host="$1"
    if [[ -z "$host" ]]; then
        return 0
    fi
    if [[ ! "$host" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "error: invalid HOST '${host}' (allowed: letters, digits, . : _ -)" >&2
        return 1
    fi
    return 0
}

_validate_port() {
    local name="$1"
    local port="$2"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        echo "error: invalid ${name} '${port}' (must be a number)" >&2
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo "error: invalid ${name} '${port}' (must be 1-65535)" >&2
        return 1
    fi
    return 0
}

_validate_proxy_env_key() {
    local key="$1"
    case "$key" in
        HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|http_proxy|https_proxy|all_proxy|no_proxy)
            return 0
            ;;
        *)
            echo "error: invalid proxy env key '${key}'" >&2
            return 1
            ;;
    esac
}

validate_clash_proxy_config() {
    _validate_host "${HOST:-}" || return 1
    _validate_port HTTP_PORT "${HTTP_PORT}" || return 1
    _validate_port SOCKS_PORT "${SOCKS_PORT}" || return 1
    return 0
}
