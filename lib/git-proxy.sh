#!/usr/bin/env bash
# Git proxy configuration helpers (session env + global config).

git_session_proxy_on() {
    local http_url="$1"
    export GIT_HTTP_PROXY="$http_url"
    export GIT_HTTPS_PROXY="$http_url"
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
    git config --global http.proxy "$http_url"
    git config --global https.proxy "$http_url"
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
