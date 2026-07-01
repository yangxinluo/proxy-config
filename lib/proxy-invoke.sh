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
    if [[ -n "${CLASH_PROXY_PROFILE:-}" ]]; then
        local profile_file="${CLASH_PROXY_ROOT}/config.d/${CLASH_PROXY_PROFILE}.env"
        if [[ ! -f "$profile_file" ]]; then
            echo "error: profile not found: ${CLASH_PROXY_PROFILE} (expected ${profile_file})" >&2
            return 1
        fi
        # shellcheck disable=SC1090
        source "$profile_file"
    fi
    export HTTP_PORT SOCKS_PORT NO_PROXY GIT_USE_HTTP STATE_DIR HOST GIT_PROXY_SCHEME HEALTH_CHECK_URL
    export NPM_USE_PROXY PIP_USE_PROXY DOCKER_USE_PROXY APT_USE_PROXY
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
    source "${CLASH_PROXY_ROOT}/lib/tool-proxy.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/proxy-net.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/proxy-core.sh"
    # shellcheck disable=SC1091
    source "${CLASH_PROXY_ROOT}/lib/proxy-commands.sh"
}

_proxy_cli() {
    _proxy_resolve_root

    local cmd="${1:-status}"
    shift || true

    local global_flag=0 git_only=0 json_flag=0

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
            --json)
                json_flag=1
                shift
                ;;
            --profile)
                shift
                CLASH_PROXY_PROFILE="${1:-}"
                if [[ -z "$CLASH_PROXY_PROFILE" ]]; then
                    echo "error: --profile requires a name" >&2
                    return 1
                fi
                export CLASH_PROXY_PROFILE
                shift
                ;;
            -h|--help)
                _proxy_load_config 2>/dev/null || true
                _proxy_source_libs 2>/dev/null || true
                if declare -f proxy_help >/dev/null 2>&1; then
                    proxy_help
                else
                    echo "usage: proxy {on|off|status|toggle|version|help} [--profile name] [-g] [--git-only] [--json]"
                fi
                return 0
                ;;
            *)
                echo "usage: proxy {on|off|status|toggle|version|help} [--profile name] [-g|--global] [--git-only] [--json]" >&2
                return 1
                ;;
        esac
    done

    _proxy_load_config || return 1
    _proxy_source_libs

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
            if [[ "$json_flag" -eq 1 ]]; then
                proxy_status_json
            else
                proxy_status
            fi
            ;;
        toggle)
            if [[ "$git_only" -eq 1 ]]; then
                proxy_toggle $([[ "$global_flag" -eq 1 ]] && echo --global) --git-only
            elif [[ "$global_flag" -eq 1 ]]; then
                proxy_toggle --global
            else
                proxy_toggle
            fi
            ;;
        version)
            proxy_version
            ;;
        help|-h|--help)
            proxy_help
            ;;
        *)
            echo "usage: proxy {on|off|status|toggle|version|help} [--profile name] [-g|--global] [--git-only] [--json]" >&2
            return 1
            ;;
    esac
}
