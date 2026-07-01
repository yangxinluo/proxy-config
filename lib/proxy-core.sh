#!/usr/bin/env bash
# Core proxy on/off/status logic shared by bin/proxy and proxy-invoke.sh.

STATE_FILE="${STATE_DIR}/state"

_ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

_write_state() {
    local mode="$1"
    local scope="${2:-global}"
    _ensure_state_dir
    printf 'mode=%s\nscope=%s\nhost=%s\nhttp_port=%s\nsocks_port=%s\n' \
        "$mode" "$scope" "$CLASH_PROXY_HOST" "$HTTP_PORT" "$SOCKS_PORT" >"$STATE_FILE"
}

_read_state() {
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

_parse_proxy_on_flags() {
    GLOBAL_FLAG=0
    GIT_ONLY=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g) GLOBAL_FLAG=1; shift ;;
            --git-only) GIT_ONLY=1; shift ;;
            *) shift ;;
        esac
    done
}

_parse_proxy_off_flags() {
    GLOBAL_FLAG=0
    GIT_ONLY=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global|-g) GLOBAL_FLAG=1; shift ;;
            --git-only) GIT_ONLY=1; shift ;;
            *) shift ;;
        esac
    done
}

proxy_on() {
    _parse_proxy_on_flags "$@"

    detect_clash_host
    _proxy_urls
    local http_url="$HTTP_PROXY_URL"
    local socks_url="$SOCKS_PROXY_URL"

    if [[ "$GLOBAL_FLAG" -eq 1 ]]; then
        export CLASH_PROXY_SCOPE=global

        if [[ "$GIT_ONLY" -eq 1 ]]; then
            if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
                git_proxy_on "$http_url" "$socks_url"
            fi
            _write_state "git-only" "global"
            echo "Clash proxy enabled (git-only, global)"
            echo "  Host: ${CLASH_PROXY_HOST}"
            echo "  HTTP: ${http_url}"
            return 0
        fi

        _set_env_proxies "$http_url" "$socks_url"
        persist_env_on "$http_url" "$socks_url" "$NO_PROXY"
        tool_proxy_on "$http_url" "$socks_url"
        if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
            git_proxy_on "$http_url" "$socks_url"
        fi
        _write_state "full" "global"
        echo "Clash proxy enabled (full, global)"
        echo "  Platform: ${CLASH_PROXY_PLATFORM}"
        echo "  Host:     ${CLASH_PROXY_HOST}"
        echo "  HTTP:     ${http_url}"
        echo "  SOCKS:    ${socks_url}"
        return 0
    fi

    export CLASH_PROXY_SCOPE=session

    if [[ "$GIT_ONLY" -eq 1 ]]; then
        if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
            git_session_proxy_on "$http_url" "$socks_url"
        fi
        echo "Clash proxy enabled (git-only, session)"
        echo "  Host: ${CLASH_PROXY_HOST}"
        echo "  HTTP: ${http_url}"
        return 0
    fi

    _set_env_proxies "$http_url" "$socks_url"
    tool_proxy_on "$http_url" "$socks_url"
    if [[ "${GIT_USE_HTTP:-1}" == "1" ]]; then
        git_session_proxy_on "$http_url" "$socks_url"
    fi
    echo "Clash proxy enabled (full, session)"
    echo "  Platform: ${CLASH_PROXY_PLATFORM}"
    echo "  Host:     ${CLASH_PROXY_HOST}"
    echo "  HTTP:     ${http_url}"
    echo "  SOCKS:    ${socks_url}"
}

proxy_off() {
    _parse_proxy_off_flags "$@"

    if [[ "$GIT_ONLY" -eq 1 ]]; then
        git_session_proxy_off
        git_proxy_off
        _read_state
        if [[ "${mode:-}" == "git-only" && "${scope:-}" == "global" ]]; then
            _clear_state
        fi
        echo "Git proxy disabled"
        return 0
    fi

    _unset_env_proxies
    git_session_proxy_off
    tool_proxy_off
    unset CLASH_PROXY_SCOPE

    _read_state
    local clear_global=0
    if [[ "$GLOBAL_FLAG" -eq 1 ]]; then
        clear_global=1
    elif [[ "${scope:-}" == "global" ]]; then
        clear_global=1
    fi

    if [[ "$clear_global" -eq 1 ]]; then
        persist_env_off
        tool_proxy_off
        git_proxy_off
        _clear_state
        echo "Clash proxy disabled (session + global)"
    else
        echo "Clash proxy disabled (session)"
    fi
}

proxy_status() {
    detect_clash_host
    _proxy_urls
    _read_state

    local display_scope="off"
    if [[ -n "${CLASH_PROXY_SCOPE:-}" ]]; then
        display_scope="$CLASH_PROXY_SCOPE"
    elif [[ "${scope:-}" == "global" ]]; then
        display_scope="global"
    elif [[ -n "${HTTP_PROXY:-}" || -n "${http_proxy:-}" || -n "${GIT_HTTP_PROXY:-}" ]]; then
        display_scope="session"
    fi

    echo "Clash proxy status"
    echo "  Platform:  ${CLASH_PROXY_PLATFORM}"
    echo "  Host:      ${CLASH_PROXY_HOST}"
    echo "  HTTP port: ${HTTP_PORT}"
    echo "  SOCKS port:${SOCKS_PORT}"
    echo "  Scope:     ${display_scope}"
    echo "  Mode:      ${mode:-off}"

    if [[ -n "${HTTP_PROXY:-}" || -n "${http_proxy:-}" ]]; then
        echo "  session env:"
        echo "    HTTP_PROXY:  ${HTTP_PROXY:-${http_proxy:-}}"
        echo "    HTTPS_PROXY: ${HTTPS_PROXY:-${https_proxy:-}}"
        echo "    ALL_PROXY:   ${ALL_PROXY:-${all_proxy:-}}"
        echo "    NO_PROXY:    ${NO_PROXY:-${no_proxy:-}}"
    else
        echo "  session env: off"
    fi

    persist_env_status
    git_session_proxy_status
    git_proxy_status
    tool_proxy_status

    if _check_tcp_port "$CLASH_PROXY_HOST" "$HTTP_PORT" 2>/dev/null; then
        echo "  port:        open (TCP ${HTTP_PORT})"
    else
        echo "  port:        closed (TCP ${HTTP_PORT})"
    fi

    echo "  health:      $(_proxy_health_check "$HTTP_PROXY_URL")"
}
