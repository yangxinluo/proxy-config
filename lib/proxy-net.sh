#!/usr/bin/env bash
# Network helpers for status checks.

_check_tcp_port() {
    local host="$1"
    local port="$2"
    if command -v nc >/dev/null 2>&1; then
        nc -z -w2 "$host" "$port" 2>/dev/null
        return $?
    fi
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
        return 0
    fi
    return 1
}

_proxy_health_check() {
    local http_url="$1"
    if [[ -z "${HEALTH_CHECK_URL:-}" ]]; then
        echo "skipped"
        return 0
    fi
    if ! command -v curl >/dev/null 2>&1; then
        echo "skipped (no curl)"
        return 0
    fi
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
        -x "$http_url" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")"
    if [[ "$code" == "204" || "$code" == "200" ]]; then
        echo "ok (HTTP ${code})"
    else
        echo "unreachable (HTTP ${code})"
    fi
}
