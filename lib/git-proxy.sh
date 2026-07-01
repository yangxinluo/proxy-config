#!/usr/bin/env bash
# Git proxy configuration helpers (session env + global config).

_git_proxy_url() {
    local http_url="$1"
    local socks_url="$2"
    case "${GIT_PROXY_SCHEME:-http}" in
        socks5|socks)
            echo "$socks_url"
            ;;
        *)
            echo "$http_url"
            ;;
    esac
}

git_session_proxy_on() {
    local http_url="$1"
    local socks_url="${2:-}"
    local proxy_url
    if [[ -n "$socks_url" ]]; then
        proxy_url="$(_git_proxy_url "$http_url" "$socks_url")"
    else
        proxy_url="$http_url"
    fi
    export GIT_HTTP_PROXY="$proxy_url"
    export GIT_HTTPS_PROXY="$proxy_url"
}

git_session_proxy_off() {
    unset GIT_HTTP_PROXY GIT_HTTPS_PROXY
}

git_session_proxy_status() {
    if [[ -n "${GIT_HTTP_PROXY:-}" || -n "${GIT_HTTPS_PROXY:-}" ]]; then
        echo "  git session:   on"
        echo "    GIT_HTTP_PROXY:  ${GIT_HTTP_PROXY:-<unset>}"
        echo "    GIT_HTTPS_PROXY: ${GIT_HTTPS_PROXY:-<unset>}"
    else
        echo "  git session:   off"
    fi
}

git_proxy_on() {
    local http_url="$1"
    local socks_url="${2:-}"
    local proxy_url
    if [[ -n "$socks_url" ]]; then
        proxy_url="$(_git_proxy_url "$http_url" "$socks_url")"
    else
        proxy_url="$http_url"
    fi
    git config --global http.proxy "$proxy_url"
    git config --global https.proxy "$proxy_url"
}

git_proxy_off() {
    git config --global --unset http.proxy 2>/dev/null || true
    git config --global --unset https.proxy 2>/dev/null || true
}

git_proxy_status() {
    local http_proxy_val https_proxy_val
    http_proxy_val="$(git config --global --get http.proxy 2>/dev/null || true)"
    https_proxy_val="$(git config --global --get https.proxy 2>/dev/null || true)"

    if [[ -n "$http_proxy_val" || -n "$https_proxy_val" ]]; then
        echo "  git global:    on"
        echo "    http.proxy:  ${http_proxy_val:-<unset>}"
        echo "    https.proxy: ${https_proxy_val:-<unset>}"
    else
        echo "  git global:    off"
    fi
}
