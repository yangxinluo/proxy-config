#!/usr/bin/env bash
# Sourceable CLI entry — used by bin/proxy and shell proxy() functions.

_proxy_resolve_root() {
    if [[ -n "${CLASH_PROXY_ROOT:-}" && -f "${CLASH_PROXY_ROOT}/config.env" ]]; then
        return 0
    fi
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CLASH_PROXY_ROOT="$(cd "${script_dir}/.." && pwd)"
    export CLASH_PROXY_ROOT
}

_proxy_load_config() {
    local config_file="${CLASH_PROXY_ROOT}/config.env"
    local defaults_file="${CLASH_PROXY_ROOT}/config.defaults.env"
    if [[ -f "$defaults_file" ]]; then
        # shellcheck disable=SC1090
        source "$defaults_file"
    fi
    if [[ ! -f "$config_file" ]]; then
        echo "error: config not found at ${config_file}" >&2
        return 1
    fi
    # shellcheck disable=SC1090
    source "$config_file"
    export HTTP_PORT SOCKS_PORT NO_PROXY GIT_USE_HTTP STATE_DIR HOST GIT_PROXY_SCHEME
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/validate-config.sh"
    validate_clash_proxy_config || return 1
}

_proxy_source_libs() {
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/detect-host.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/git-proxy.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/persist-env.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/proxy-core.sh"
}

_proxy_cli() {
    _proxy_resolve_root
    _proxy_load_config || return 1
    _proxy_source_libs

    local cmd="${1:-status}"
    shift || true

    local global_flag=0 git_only=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -g|--global|-Global)
                global_flag=1
                shift
                ;;
            --git-only|-GitOnly)
                git_only=1
                shift
                ;;
            *)
                echo "usage: proxy {on|off|status} [-g|--global] [--git-only]" >&2
                return 1
                ;;
        esac
    done

    case "$cmd" in
        on)
            if [[ "$git_only" -eq 1 ]]; then
                proxy_on $([[ "$global_flag" -eq 1 ]] && echo --global) --git-only
            elif [[ "$global_flag" -eq 1 ]]; then
                proxy_on --global
            else
                proxy_on
            fi
            ;;
        off)
            if [[ "$git_only" -eq 1 ]]; then
                proxy_off --git-only
            elif [[ "$global_flag" -eq 1 ]]; then
                proxy_off --global
            else
                proxy_off
            fi
            ;;
        status)
            proxy_status
            ;;
        *)
            echo "usage: proxy {on|off|status} [-g|--global] [--git-only]" >&2
            return 1
            ;;
    esac
}
