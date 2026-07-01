# Clash for Windows proxy — PowerShell module
# Dot-source this file to register the `proxy` function.

$ErrorActionPreference = 'Stop'
$script:ClashProxyScriptRoot = $PSScriptRoot

function Get-ClashProxyRoot {
    if ($env:CLASH_PROXY_ROOT -and (Test-Path (Join-Path $env:CLASH_PROXY_ROOT 'config.env'))) {
        return $env:CLASH_PROXY_ROOT
    }
    return (Resolve-Path (Join-Path $script:ClashProxyScriptRoot '..')).Path
}

function Read-ClashProxyConfig {
    param([string]$Root)

    $configPath = Join-Path $Root 'config.env'
    if (-not (Test-Path $configPath)) {
        throw "config not found at $configPath"
    }

    $config = @{
        HTTP_PORT  = 7890
        SOCKS_PORT = 7891
        NO_PROXY   = 'localhost,127.0.0.1'
        HOST       = ''
        GIT_USE_HTTP = '1'
        STATE_DIR  = ''
    }

    foreach ($line in Get-Content $configPath) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            $config[$key] = $value
        }
    }

    if (-not $config.STATE_DIR -or $config.STATE_DIR -match '[\$\{]') {
        $xdg = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path $env:USERPROFILE '.local\state' }
        $config.STATE_DIR = Join-Path $xdg 'clash-proxy'
    } else {
        $config.STATE_DIR = $config.STATE_DIR -replace '/', '\'
    }

    return $config
}

function Get-ClashProxyHost {
    param([hashtable]$Config)

    if ($Config.HOST) {
        return $Config.HOST
    }
    return '127.0.0.1'
}

function Set-GitProxy {
    param([string]$HttpUrl)
    git config --global http.proxy $HttpUrl
    git config --global https.proxy $HttpUrl
}

function Clear-GitProxy {
    git config --global --unset http.proxy 2>$null
    git config --global --unset https.proxy 2>$null
}

function Write-ClashProxyState {
    param(
        [string]$StateDir,
        [string]$Mode,
        [string]$ClashHost,
        [string]$HttpPort,
        [string]$SocksPort
    )
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    $stateFile = Join-Path $StateDir 'state'
    @(
        "mode=$Mode"
        "host=$ClashHost"
        "http_port=$HttpPort"
        "socks_port=$SocksPort"
    ) | Set-Content -Path $stateFile -Encoding utf8
}

function Read-ClashProxyState {
    param([string]$StateDir)

    $stateFile = Join-Path $StateDir 'state'
    $result = @{ mode = 'off' }
    if (Test-Path $stateFile) {
        foreach ($line in Get-Content $stateFile) {
            if ($line -match '^([^=]+)=(.*)$') {
                $result[$Matches[1]] = $Matches[2]
            }
        }
    }
    return $result
}

function Clear-ClashProxyState {
    param([string]$StateDir)
    $stateFile = Join-Path $StateDir 'state'
    if (Test-Path $stateFile) { Remove-Item $stateFile -Force }
}

function proxy {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('on', 'off', 'status')]
        [string]$Command,

        [switch]$GitOnly
    )

    $root = Get-ClashProxyRoot
    $config = Read-ClashProxyConfig -Root $root
    $hostAddr = Get-ClashProxyHost -Config $config
    $httpUrl = "http://${hostAddr}:$($config.HTTP_PORT)"
    $socksUrl = "socks5://${hostAddr}:$($config.SOCKS_PORT)"
    $stateDir = $config.STATE_DIR

    switch ($Command) {
        'on' {
            if ($GitOnly) {
                if ($config.GIT_USE_HTTP -eq '1') {
                    Set-GitProxy -HttpUrl $httpUrl
                }
                Write-ClashProxyState -StateDir $stateDir -Mode 'git-only' -ClashHost $hostAddr `
                    -HttpPort $config.HTTP_PORT -SocksPort $config.SOCKS_PORT
                Write-Host "Clash proxy enabled (git-only)"
                Write-Host "  Host: $hostAddr"
                Write-Host "  HTTP: $httpUrl"
            } else {
                $env:HTTP_PROXY = $httpUrl
                $env:HTTPS_PROXY = $httpUrl
                $env:ALL_PROXY = $socksUrl
                $env:NO_PROXY = $config.NO_PROXY
                $env:http_proxy = $httpUrl
                $env:https_proxy = $httpUrl
                $env:all_proxy = $socksUrl
                $env:no_proxy = $config.NO_PROXY
                if ($config.GIT_USE_HTTP -eq '1') {
                    Set-GitProxy -HttpUrl $httpUrl
                }
                Write-ClashProxyState -StateDir $stateDir -Mode 'full' -ClashHost $hostAddr `
                    -HttpPort $config.HTTP_PORT -SocksPort $config.SOCKS_PORT
                Write-Host "Clash proxy enabled (full)"
                Write-Host "  Platform: powershell"
                Write-Host "  Host:     $hostAddr"
                Write-Host "  HTTP:     $httpUrl"
                Write-Host "  SOCKS:    $socksUrl"
            }
        }
        'off' {
            if ($GitOnly) {
                Clear-GitProxy
                $state = Read-ClashProxyState -StateDir $stateDir
                if ($state.mode -eq 'git-only') {
                    Clear-ClashProxyState -StateDir $stateDir
                }
                Write-Host 'Git proxy disabled'
            } else {
                Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
                Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
                Remove-Item Env:ALL_PROXY -ErrorAction SilentlyContinue
                Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue
                Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
                Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
                Remove-Item Env:all_proxy -ErrorAction SilentlyContinue
                Remove-Item Env:no_proxy -ErrorAction SilentlyContinue
                Clear-GitProxy
                Clear-ClashProxyState -StateDir $stateDir
                Write-Host 'Clash proxy disabled'
            }
        }
        'status' {
            $state = Read-ClashProxyState -StateDir $stateDir
            Write-Host 'Clash proxy status'
            Write-Host '  Platform:  powershell'
            Write-Host "  Host:      $hostAddr"
            Write-Host "  HTTP port: $($config.HTTP_PORT)"
            Write-Host "  SOCKS port:$($config.SOCKS_PORT)"
            Write-Host "  Mode:      $($state.mode)"

            if ($env:HTTP_PROXY -or $env:http_proxy) {
                Write-Host "  HTTP_PROXY:  $($env:HTTP_PROXY)"
                Write-Host "  HTTPS_PROXY: $($env:HTTPS_PROXY)"
                Write-Host "  ALL_PROXY:   $($env:ALL_PROXY)"
                Write-Host "  NO_PROXY:    $($env:NO_PROXY)"
            } else {
                Write-Host '  env proxy:   off'
            }

            $gitHttp = git config --global --get http.proxy 2>$null
            $gitHttps = git config --global --get https.proxy 2>$null
            if ($gitHttp -or $gitHttps) {
                Write-Host "  git http.proxy:  $gitHttp"
                Write-Host "  git https.proxy: $gitHttps"
            } else {
                Write-Host '  git proxy:       off'
            }

            try {
                $response = Invoke-WebRequest -Uri 'http://www.gstatic.com/generate_204' `
                    -Proxy $httpUrl -TimeoutSec 3 -UseBasicParsing
                Write-Host "  health:      ok (HTTP $($response.StatusCode))"
            } catch {
                Write-Host '  health:      unreachable'
            }
        }
    }
}

# Direct invocation: proxy.cmd or powershell -File proxy.ps1 on|off|status
if ($MyInvocation.InvocationName -ne '.') {
    $cmd = 'status'
    $gitOnly = $false
    foreach ($arg in $args) {
        switch -Regex ($arg) {
            '^(-GitOnly|--git-only)$' { $gitOnly = $true; continue }
            '^(on|off|status)$' { $cmd = $arg; continue }
        }
    }
    proxy -Command $cmd -GitOnly:$gitOnly
}
