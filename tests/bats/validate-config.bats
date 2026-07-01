#!/usr/bin/env bats

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    # shellcheck disable=SC1091
    source "${ROOT}/lib/validate-config.sh"
    HTTP_PORT=7890
    SOCKS_PORT=7891
    HOST=
}

@test "validate accepts default config" {
    run validate_clash_proxy_config
    [ "$status" -eq 0 ]
}

@test "validate rejects invalid host" {
    HOST="bad host!"
    run validate_clash_proxy_config
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid HOST"* ]]
}

@test "validate rejects non-numeric port" {
    HTTP_PORT=abc
    run validate_clash_proxy_config
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid HTTP_PORT"* ]]
}

@test "validate rejects port out of range" {
    SOCKS_PORT=70000
    run validate_clash_proxy_config
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid SOCKS_PORT"* ]]
}

@test "validate accepts IPv6 host" {
    HOST="::1"
    run validate_clash_proxy_config
    [ "$status" -eq 0 ]
}

@test "validate proxy env key whitelist" {
    run _validate_proxy_env_key HTTP_PROXY
    [ "$status" -eq 0 ]
    run _validate_proxy_env_key EVIL_KEY
    [ "$status" -eq 1 ]
}
