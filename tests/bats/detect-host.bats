#!/usr/bin/env bats

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    # shellcheck disable=SC1091
    source "${ROOT}/lib/detect-host.sh"
    unset CLASH_PROXY_PLATFORM CLASH_PROXY_HOST HOST MSYSTEM MINGW_PREFIX
}

@test "forced HOST overrides detection" {
    HOST="10.0.0.5"
    detect_clash_host
    [ "$CLASH_PROXY_HOST" = "10.0.0.5" ]
}

@test "git-bash platform uses 127.0.0.1" {
    MSYSTEM=MINGW64
    detect_clash_host
    [ "$CLASH_PROXY_PLATFORM" = "git-bash" ]
    [ "$CLASH_PROXY_HOST" = "127.0.0.1" ]
}

@test "linux platform defaults to 127.0.0.1" {
    detect_clash_platform
    if [ "$CLASH_PROXY_PLATFORM" = "wsl2" ]; then
        skip "WSL2 environment detected"
    fi
    detect_clash_host
    [ "$CLASH_PROXY_HOST" = "127.0.0.1" ]
}
