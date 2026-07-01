#!/usr/bin/env bash
# Optional dev-tool proxy integration (npm, pip, docker, apt).

tool_proxy_on() {
    local http_url="$1"
    local socks_url="$2"

    if [[ "${NPM_USE_PROXY:-0}" == "1" ]] && command -v npm >/dev/null 2>&1; then
        npm config set proxy "$http_url" 2>/dev/null || true
        npm config set https-proxy "$http_url" 2>/dev/null || true
    fi

    if [[ "${PIP_USE_PROXY:-0}" == "1" ]]; then
        export PIP_PROXY="$http_url"
    fi

    if [[ "${DOCKER_USE_PROXY:-0}" == "1" ]] && command -v docker >/dev/null 2>&1; then
        export DOCKER_HTTP_PROXY="$http_url"
        export DOCKER_HTTPS_PROXY="$http_url"
        export DOCKER_ALL_PROXY="$socks_url"
        export DOCKER_NO_PROXY="$NO_PROXY"
    fi

    if [[ "${APT_USE_PROXY:-0}" == "1" ]]; then
        export APT_HTTP_PROXY="$http_url"
        export APT_HTTPS_PROXY="$http_url"
    fi
}

tool_proxy_off() {
    if [[ "${NPM_USE_PROXY:-0}" == "1" ]] && command -v npm >/dev/null 2>&1; then
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
    fi

    unset PIP_PROXY
    unset DOCKER_HTTP_PROXY DOCKER_HTTPS_PROXY DOCKER_ALL_PROXY DOCKER_NO_PROXY
    unset APT_HTTP_PROXY APT_HTTPS_PROXY
}

tool_proxy_status() {
    local any=0
    if [[ "${NPM_USE_PROXY:-0}" == "1" ]] && command -v npm >/dev/null 2>&1; then
        local npm_proxy npm_https
        npm_proxy="$(npm config get proxy 2>/dev/null || true)"
        npm_https="$(npm config get https-proxy 2>/dev/null || true)"
        if [[ -n "$npm_proxy" && "$npm_proxy" != "null" ]]; then
            [[ "$any" -eq 0 ]] && echo "  tools:" && any=1
            echo "    npm proxy:       $npm_proxy"
            echo "    npm https-proxy: $npm_https"
        fi
    fi
    if [[ -n "${PIP_PROXY:-}" ]]; then
        [[ "$any" -eq 0 ]] && echo "  tools:" && any=1
        echo "    PIP_PROXY:       $PIP_PROXY"
    fi
    if [[ -n "${DOCKER_HTTP_PROXY:-}" ]]; then
        [[ "$any" -eq 0 ]] && echo "  tools:" && any=1
        echo "    DOCKER_HTTP_PROXY: $DOCKER_HTTP_PROXY"
    fi
    if [[ -n "${APT_HTTP_PROXY:-}" ]]; then
        [[ "$any" -eq 0 ]] && echo "  tools:" && any=1
        echo "    APT_HTTP_PROXY:  $APT_HTTP_PROXY"
    fi
}
