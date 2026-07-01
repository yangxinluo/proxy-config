#!/usr/bin/env bash
# Extended CLI commands: help, version, toggle, JSON status.

proxy_version() {
    local version_file="${CLASH_PROXY_ROOT}/VERSION"
    if [[ -f "$version_file" ]]; then
        tr -d '\r\n' <"$version_file"
    else
        echo "unknown"
    fi
}

proxy_help() {
    cat <<'EOF'
usage: proxy {on|off|status|toggle|version|help} [options]

commands:
  on       Enable proxy (session by default)
  off      Disable proxy
  status   Show proxy status
  toggle   Switch between on and off
  version  Print version
  help     Show this help

options:
  -g, --global, -Global   Persist settings across terminals
  --git-only, -GitOnly    Configure Git proxy only
  --json                  Machine-readable status output (status only)

examples:
  proxy on
  proxy on -g
  proxy on --git-only
  proxy off
  proxy status --json
  proxy toggle
EOF
}

proxy_status_json() {
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

    local port_open="false"
    if _check_tcp_port "$CLASH_PROXY_HOST" "$HTTP_PORT"; then
        port_open="true"
    fi

    local health
    health="$(_proxy_health_check "$HTTP_PROXY_URL")"

    local session_http="${HTTP_PROXY:-${http_proxy:-}}"
    local git_global_http
    git_global_http="$(git config --global --get http.proxy 2>/dev/null || true)"

    printf '{"version":"%s","platform":"%s","host":"%s","http_port":%s,"socks_port":%s,"scope":"%s","mode":"%s","session_env":%s,"git_session":%s,"git_global":%s,"port_open":%s,"health":"%s"}\n' \
        "$(proxy_version)" \
        "${CLASH_PROXY_PLATFORM}" \
        "${CLASH_PROXY_HOST}" \
        "${HTTP_PORT}" \
        "${SOCKS_PORT}" \
        "${display_scope}" \
        "${mode:-off}" \
        "$(if [[ -n "$session_http" ]]; then echo true; else echo false; fi)" \
        "$(if [[ -n "${GIT_HTTP_PROXY:-}" ]]; then echo true; else echo false; fi)" \
        "$(if [[ -n "$git_global_http" ]]; then echo true; else echo false; fi)" \
        "${port_open}" \
        "${health}"
}

proxy_toggle() {
    _read_state
    if [[ -n "${HTTP_PROXY:-}" || -n "${http_proxy:-}" || -n "${GIT_HTTP_PROXY:-}" || "${scope:-}" == "global" ]]; then
        proxy_off "$@"
    else
        proxy_on "$@"
    fi
}
