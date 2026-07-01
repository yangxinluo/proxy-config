#!/usr/bin/env bats

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    HTTP_PORT=7890
    SOCKS_PORT=7891
    GIT_USE_HTTP=1
    GIT_PROXY_SCHEME=http
    NO_PROXY=localhost,127.0.0.1
    STATE_DIR="${BATS_TMPDIR}/clash-proxy-state"
    CLASH_PROXY_HOST=127.0.0.1
    CLASH_PROXY_PLATFORM=linux
    export HTTP_PORT SOCKS_PORT GIT_USE_HTTP GIT_PROXY_SCHEME NO_PROXY STATE_DIR
    export CLASH_PROXY_HOST CLASH_PROXY_PLATFORM
    # shellcheck disable=SC1091
    source "${ROOT}/lib/git-proxy.sh"
}

@test "git_session_proxy_on uses http url by default" {
    git_session_proxy_on "http://127.0.0.1:7890" "socks5://127.0.0.1:7891"
    [ "$GIT_HTTP_PROXY" = "http://127.0.0.1:7890" ]
    [ "$GIT_HTTPS_PROXY" = "http://127.0.0.1:7890" ]
}

@test "git_session_proxy_on uses socks url when GIT_PROXY_SCHEME=socks5" {
    GIT_PROXY_SCHEME=socks5
    git_session_proxy_on "http://127.0.0.1:7890" "socks5://127.0.0.1:7891"
    [ "$GIT_HTTP_PROXY" = "socks5://127.0.0.1:7891" ]
}

@test "git_session_proxy_off clears session vars" {
    git_session_proxy_on "http://127.0.0.1:7890"
    git_session_proxy_off
    [ -z "${GIT_HTTP_PROXY:-}" ]
    [ -z "${GIT_HTTPS_PROXY:-}" ]
}
