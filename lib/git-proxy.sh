#!/usr/bin/env bash
# Git proxy configuration helpers.

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
        echo "  git http.proxy:  ${http_proxy_val:-<unset>}"
        echo "  git https.proxy: ${https_proxy_val:-<unset>}"
    else
        echo "  git proxy:       off"
    fi
}
