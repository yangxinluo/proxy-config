#!/usr/bin/env bash
# Core proxy on/off/status logic shared by bin/proxy.

STATE_FILE="${STATE_DIR}/state"

_ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

_write_state() {
    local mode="$1"
    _ensure_state_dir
    printf 'mode=%s\nhost=%s\nhttp_port=%s\nsocks_port=%s\n' \
        "$mode" "$CLASH_PROXY_HOST" "$HTTP_PORT" "$SOCKS_PORT" >"$STATE_FILE"
}

_read_state() {
    local key
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
    fi
}

_clear_state() {
    rm -f "$STATE_FILE"
}

_set_env_proxies() {
    local http_url="$1"
    local socks_url="$2"

    export HTTP_PROXY="$http_url"
    export HTTPS_PROXY="$http_url"
    export ALL_PROXY="$socks_url"
    export NO_PROXY="$NO_PROXY"
    export http_proxy="$http_url"
    export https_proxy="$http_url"
    export all_proxy="$socks_url"
    export no_proxy="$NO_PROXY"
}

_unset_env_proxies() {
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    unset http_proxy https_proxy all_proxy no_proxy
}

_proxy_urls() {
  HTTP_PROXY_URL="http://${CLASH_PROXY_HOST}:${HTTP_PORT}"
  SOCKS_PROXY_URL="socks5://${CLASH_PROXY_HOST}:${SOCKS_PORT}"
  export HTTP_PROXY_URL SOCKS_PROXY_URL
}

proxy_on() {
    local git_only=0
    if [[ "${1:-}" == "--git-only" ]]; then
        git_only=1
    fi

    detect_clash_host
    _proxy_urls
    local http_url="$HTTP_PROXY_URL"
    local socks_url="$SOCKS_PROXY_URL"

    if [[ "$git_only" -eq 1 ]]; then
        if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
            git_proxy_on "$http_url"
        fi
        _write_state "git-only"
        echo "Clash proxy enabled (git-only)"
        echo "  Host: ${CLASH_PROXY_HOST}"
        echo "  HTTP: ${http_url}"
        return 0
    fi

    _set_env_proxies "$http_url" "$socks_url"
    if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
        git_proxy_on "$http_url"
    fi
    _write_state "full"
    echo "Clash proxy enabled (full)"
    echo "  Platform: ${CLASH_PROXY_PLATFORM}"
    echo "  Host:     ${CLASH_PROXY_HOST}"
    echo "  HTTP:     ${http_url}"
    echo "  SOCKS:    ${socks_url}"
}

proxy_off() {
    local git_only=0
    if [[ "${1:-}" == "--git-only" ]]; then
        git_only=1
    fi

    if [[ "$git_only" -eq 1 ]]; then
        git_proxy_off
        _read_state
        if [[ "${mode:-}" == "git-only" ]]; then
            _clear_state
        fi
        echo "Git proxy disabled"
        return 0
    fi

    _unset_env_proxies
    git_proxy_off
    _clear_state
    echo "Clash proxy disabled"
}

proxy_status() {
    detect_clash_host
    _proxy_urls
    _read_state

    echo "Clash proxy status"
    echo "  Platform:  ${CLASH_PROXY_PLATFORM}"
    echo "  Host:      ${CLASH_PROXY_HOST}"
    echo "  HTTP port: ${HTTP_PORT}"
    echo "  SOCKS port:${SOCKS_PORT}"
    echo "  Mode:      ${mode:-off}"

    if [[ -n "${HTTP_PROXY:-}" || -n "${http_proxy:-}" ]]; then
        echo "  HTTP_PROXY:  ${HTTP_PROXY:-${http_proxy:-}}"
        echo "  HTTPS_PROXY: ${HTTPS_PROXY:-${https_proxy:-}}"
        echo "  ALL_PROXY:   ${ALL_PROXY:-${all_proxy:-}}"
        echo "  NO_PROXY:    ${NO_PROXY:-${no_proxy:-}}"
    else
        echo "  env proxy:   off"
    fi

    git_proxy_status

    if command -v curl >/dev/null 2>&1; then
        local code
        code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 \
            -x "$HTTP_PROXY_URL" "http://www.gstatic.com/generate_204" 2>/dev/null || echo "000")"
        if [[ "$code" == "204" || "$code" == "200" ]]; then
            echo "  health:      ok (HTTP ${code})"
        else
            echo "  health:      unreachable (HTTP ${code})"
        fi
    fi
}
