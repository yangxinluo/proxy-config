# Clash for Windows proxy — PowerShell module
# Dot-source this file to register the `proxy` function.

$ErrorActionPreference = 'Stop'
$script:ClashProxyScriptRoot = $PSScriptRoot

$script:PersistEnvKeys = @(
    'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY',
    'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy'
)

$script:PersistEnvStart = '# >>> clash-proxy-env >>>'
$script:PersistEnvEnd = '# <<< clash-proxy-env <<<'

function Get-ClashProxyRoot {
    if ($env:CLASH_PROXY_ROOT -and (Test-Path (Join-Path $env:CLASH_PROXY_ROOT 'config.env'))) {
        return $env:CLASH_PROXY_ROOT
    }
    return (Resolve-Path (Join-Path $script:ClashProxyScriptRoot '..')).Path
}

function Read-ClashProxyConfig {
    param([string]$Root)

    $defaultsPath = Join-Path $Root 'config.defaults.env'
    $configPath = Join-Path $Root 'config.env'
    if (-not (Test-Path $configPath)) {
        throw "config not found at $configPath"
    }

    $config = @{
        HTTP_PORT        = 7890
        SOCKS_PORT       = 7891
        NO_PROXY         = 'localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'
        HOST             = ''
        GIT_USE_HTTP     = '1'
        GIT_PROXY_SCHEME = 'http'
        STATE_DIR        = ''
    }

    foreach ($path in @($defaultsPath, $configPath)) {
        if (-not (Test-Path $path)) { continue }
        foreach ($line in Get-Content $path) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $key = $Matches[1]
                $value = $Matches[2]
                $config[$key] = $value
            }
        }
    }

    if (-not $config.STATE_DIR -or $config.STATE_DIR -match '[\$\{]') {
        $xdg = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path $env:USERPROFILE '.local\state' }
        $config.STATE_DIR = Join-Path $xdg 'clash-proxy'
    } else {
        $config.STATE_DIR = $config.STATE_DIR -replace '/', '\'
    }

    Test-ClashProxyConfig -Config $config
    return $config
}

function Test-ClashProxyConfig {
    param([hashtable]$Config)

    if ($Config.HOST -and $Config.HOST -notmatch '^[A-Za-z0-9.:_-]+$') {
        throw "invalid HOST '$($Config.HOST)' (allowed: letters, digits, . : _ -)"
    }
    foreach ($name in @('HTTP_PORT', 'SOCKS_PORT')) {
        $port = $Config[$name]
        if ($port -notmatch '^\d+$') {
            throw "invalid $name '$port' (must be a number)"
        }
        $portNum = [int]$port
        if ($portNum -lt 1 -or $portNum -gt 65535) {
            throw "invalid $name '$port' (must be 1-65535)"
        }
    }
}

function Get-ClashProxyHost {
    param([hashtable]$Config)

    if ($Config.HOST) {
        return $Config.HOST
    }
    return '127.0.0.1'
}

function Set-SessionProxyEnv {
    param(
        [string]$HttpUrl,
        [string]$SocksUrl,
        [string]$NoProxy
    )
    $env:HTTP_PROXY = $HttpUrl
    $env:HTTPS_PROXY = $HttpUrl
    $env:ALL_PROXY = $SocksUrl
    $env:NO_PROXY = $NoProxy
    $env:http_proxy = $HttpUrl
    $env:https_proxy = $HttpUrl
    $env:all_proxy = $SocksUrl
    $env:no_proxy = $NoProxy
}

function Clear-SessionProxyEnv {
    foreach ($key in $script:PersistEnvKeys) {
        Remove-Item "Env:$key" -ErrorAction SilentlyContinue
    }
    Remove-Item Env:GIT_HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:CLASH_PROXY_SCOPE -ErrorAction SilentlyContinue
}

function Set-UserProxyEnv {
    param(
        [string]$HttpUrl,
        [string]$SocksUrl,
        [string]$NoProxy
    )
    [Environment]::SetEnvironmentVariable('HTTP_PROXY', $HttpUrl, 'User')
    [Environment]::SetEnvironmentVariable('HTTPS_PROXY', $HttpUrl, 'User')
    [Environment]::SetEnvironmentVariable('ALL_PROXY', $SocksUrl, 'User')
    [Environment]::SetEnvironmentVariable('NO_PROXY', $NoProxy, 'User')
    [Environment]::SetEnvironmentVariable('http_proxy', $HttpUrl, 'User')
    [Environment]::SetEnvironmentVariable('https_proxy', $HttpUrl, 'User')
    [Environment]::SetEnvironmentVariable('all_proxy', $SocksUrl, 'User')
    [Environment]::SetEnvironmentVariable('no_proxy', $NoProxy, 'User')
}

function Clear-UserProxyEnv {
    foreach ($key in $script:PersistEnvKeys) {
        [Environment]::SetEnvironmentVariable($key, $null, 'User')
    }
}

function Get-UserProxyEnvStatus {
    $any = $false
    foreach ($key in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY')) {
        $val = [Environment]::GetEnvironmentVariable($key, 'User')
        if ($val) {
            if (-not $any) {
                Write-Host '  user env:'
                $any = $true
            }
            Write-Host "    ${key}: $val"
        }
    }
    if (-not $any) {
        Write-Host '  user env:    off'
    }
}

function ConvertTo-WslPath {
    param([string]$WindowsPath)
    $p = $WindowsPath.TrimEnd('\') -replace '\\', '/'
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return "/mnt/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $p
}

function Set-WslPersistEnvBlock {
    param(
        [string]$HttpUrl,
        [string]$SocksUrl,
        [string]$NoProxy
    )
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return }

    $start = $script:PersistEnvStart
    $end = $script:PersistEnvEnd
    $backup = Get-Date -Format 'yyyyMMdd'

    $block = @(
        $start
        "export HTTP_PROXY=`"$HttpUrl`""
        "export HTTPS_PROXY=`"$HttpUrl`""
        "export ALL_PROXY=`"$SocksUrl`""
        "export NO_PROXY=`"$NoProxy`""
        "export http_proxy=`"$HttpUrl`""
        "export https_proxy=`"$HttpUrl`""
        "export all_proxy=`"$SocksUrl`""
        "export no_proxy=`"$NoProxy`""
        $end
    ) -join "`n"

    wsl bash -lc "touch ~/.bashrc" 2>$null
    if ($LASTEXITCODE -ne 0) { return }

    wsl bash -lc "test -f ~/.bashrc && cp ~/.bashrc ~/.bashrc.bak.clash-proxy-env-$backup 2>/dev/null || true"
    wsl bash -lc "grep -qF '$start' ~/.bashrc 2>/dev/null && sed -i '/$start/,/$end/d' ~/.bashrc || true"

    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, "${block}`n", (New-Object System.Text.UTF8Encoding $false))
        $wslTemp = ConvertTo-WslPath -WindowsPath $tempFile
        wsl bash -lc "cat '$wslTemp' >> ~/.bashrc"
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

function Clear-WslPersistEnvBlock {
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return }

    $start = $script:PersistEnvStart
    $end = $script:PersistEnvEnd
    $backup = Get-Date -Format 'yyyyMMdd'

    wsl bash -lc "test -f ~/.bashrc && grep -qF '$start' ~/.bashrc && cp ~/.bashrc ~/.bashrc.bak.clash-proxy-env-$backup 2>/dev/null || true"
    wsl bash -lc "test -f ~/.bashrc && grep -qF '$start' ~/.bashrc && sed -i '/$start/,/$end/d' ~/.bashrc || true"
}

function Test-WslPersistEnvBlock {
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) { return $false }
    $start = $script:PersistEnvStart
    $result = wsl bash -lc "grep -qF '$start' ~/.bashrc 2>/dev/null && echo yes || echo no" 2>$null
    return ($result -match 'yes')
}

function Set-GitSessionProxy {
    param([string]$HttpUrl)
    $env:GIT_HTTP_PROXY = $HttpUrl
    $env:GIT_HTTPS_PROXY = $HttpUrl
}

function Clear-GitSessionProxy {
    Remove-Item Env:GIT_HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_HTTPS_PROXY -ErrorAction SilentlyContinue
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
        [string]$Scope,
        [string]$ClashHost,
        [string]$HttpPort,
        [string]$SocksPort
    )
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    $stateFile = Join-Path $StateDir 'state'
    @(
        "mode=$Mode"
        "scope=$Scope"
        "host=$ClashHost"
        "http_port=$HttpPort"
        "socks_port=$SocksPort"
    ) | Set-Content -Path $stateFile -Encoding utf8
}

function Read-ClashProxyState {
    param([string]$StateDir)

    $stateFile = Join-Path $StateDir 'state'
    $result = @{ mode = 'off'; scope = '' }
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

function Show-ClashProxyGlobalStatus {
    param([string]$StateDir)

    Get-UserProxyEnvStatus

    $gitHttp = git config --global --get http.proxy 2>$null
    $gitHttps = git config --global --get https.proxy 2>$null
    if ($gitHttp -or $gitHttps) {
        Write-Host '  git global:    on'
        Write-Host "    http.proxy:  $gitHttp"
        Write-Host "    https.proxy: $gitHttps"
    } else {
        Write-Host '  git global:    off'
    }

    if (Test-WslPersistEnvBlock) {
        Write-Host '  WSL env block: present'
    }
}

function proxy {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('on', 'off', 'status')]
        [string]$Command,

        [Alias('g')]
        [switch]$Global,

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
            if ($Global) {
                $env:CLASH_PROXY_SCOPE = 'global'

                if ($GitOnly) {
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitProxy -HttpUrl $httpUrl
                    }
                    Write-ClashProxyState -StateDir $stateDir -Mode 'git-only' -Scope 'global' `
                        -ClashHost $hostAddr -HttpPort $config.HTTP_PORT -SocksPort $config.SOCKS_PORT
                    Write-Host 'Clash proxy enabled (git-only, global)'
                    Write-Host "  Host: $hostAddr"
                    Write-Host "  HTTP: $httpUrl"
                } else {
                    Set-SessionProxyEnv -HttpUrl $httpUrl -SocksUrl $socksUrl -NoProxy $config.NO_PROXY
                    Set-UserProxyEnv -HttpUrl $httpUrl -SocksUrl $socksUrl -NoProxy $config.NO_PROXY
                    Set-WslPersistEnvBlock -HttpUrl $httpUrl -SocksUrl $socksUrl -NoProxy $config.NO_PROXY
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitProxy -HttpUrl $httpUrl
                    }
                    Write-ClashProxyState -StateDir $stateDir -Mode 'full' -Scope 'global' `
                        -ClashHost $hostAddr -HttpPort $config.HTTP_PORT -SocksPort $config.SOCKS_PORT
                    Write-Host 'Clash proxy enabled (full, global)'
                    Write-Host '  Platform: powershell'
                    Write-Host "  Host:     $hostAddr"
                    Write-Host "  HTTP:     $httpUrl"
                    Write-Host "  SOCKS:    $socksUrl"
                }
            } else {
                $env:CLASH_PROXY_SCOPE = 'session'

                if ($GitOnly) {
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitSessionProxy -HttpUrl $httpUrl
                    }
                    Write-Host 'Clash proxy enabled (git-only, session)'
                    Write-Host "  Host: $hostAddr"
                    Write-Host "  HTTP: $httpUrl"
                } else {
                    Set-SessionProxyEnv -HttpUrl $httpUrl -SocksUrl $socksUrl -NoProxy $config.NO_PROXY
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitSessionProxy -HttpUrl $httpUrl
                    }
                    Write-Host 'Clash proxy enabled (full, session)'
                    Write-Host '  Platform: powershell'
                    Write-Host "  Host:     $hostAddr"
                    Write-Host "  HTTP:     $httpUrl"
                    Write-Host "  SOCKS:    $socksUrl"
                }
            }
        }
        'off' {
            if ($GitOnly) {
                Clear-GitSessionProxy
                Clear-GitProxy
                $state = Read-ClashProxyState -StateDir $stateDir
                if ($state.mode -eq 'git-only' -and $state.scope -eq 'global') {
                    Clear-ClashProxyState -StateDir $stateDir
                }
                Write-Host 'Git proxy disabled'
            } else {
                Clear-SessionProxyEnv

                $state = Read-ClashProxyState -StateDir $stateDir
                $clearGlobal = $Global -or ($state.scope -eq 'global')

                if ($clearGlobal) {
                    Clear-UserProxyEnv
                    Clear-WslPersistEnvBlock
                    Clear-GitProxy
                    Clear-ClashProxyState -StateDir $stateDir
                    Write-Host 'Clash proxy disabled (session + global)'
                } else {
                    Write-Host 'Clash proxy disabled (session)'
                }
            }
        }
        'status' {
            $state = Read-ClashProxyState -StateDir $stateDir

            $displayScope = 'off'
            if ($env:CLASH_PROXY_SCOPE) {
                $displayScope = $env:CLASH_PROXY_SCOPE
            } elseif ($state.scope -eq 'global') {
                $displayScope = 'global'
            } elseif ($env:HTTP_PROXY -or $env:http_proxy -or $env:GIT_HTTP_PROXY) {
                $displayScope = 'session'
            }

            Write-Host 'Clash proxy status'
            Write-Host '  Platform:  powershell'
            Write-Host "  Host:      $hostAddr"
            Write-Host "  HTTP port: $($config.HTTP_PORT)"
            Write-Host "  SOCKS port:$($config.SOCKS_PORT)"
            Write-Host "  Scope:     $displayScope"
            Write-Host "  Mode:      $($state.mode)"

            if ($env:HTTP_PROXY -or $env:http_proxy) {
                Write-Host '  session env:'
                Write-Host "    HTTP_PROXY:  $($env:HTTP_PROXY)"
                Write-Host "    HTTPS_PROXY: $($env:HTTPS_PROXY)"
                Write-Host "    ALL_PROXY:   $($env:ALL_PROXY)"
                Write-Host "    NO_PROXY:    $($env:NO_PROXY)"
            } else {
                Write-Host '  session env: off'
            }

            Get-UserProxyEnvStatus

            if ($env:GIT_HTTP_PROXY -or $env:GIT_HTTPS_PROXY) {
                Write-Host '  git session:   on'
                Write-Host "    GIT_HTTP_PROXY:  $($env:GIT_HTTP_PROXY)"
                Write-Host "    GIT_HTTPS_PROXY: $($env:GIT_HTTPS_PROXY)"
            } else {
                Write-Host '  git session:   off'
            }

            $gitHttp = git config --global --get http.proxy 2>$null
            $gitHttps = git config --global --get https.proxy 2>$null
            if ($gitHttp -or $gitHttps) {
                Write-Host '  git global:    on'
                Write-Host "    http.proxy:  $gitHttp"
                Write-Host "    https.proxy: $gitHttps"
            } else {
                Write-Host '  git global:    off'
            }

            if (Test-WslPersistEnvBlock) {
                Write-Host '  WSL env block: present'
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
    $globalFlag = $false
    $gitGlobalOnly = $false
    foreach ($arg in $args) {
        switch -Regex ($arg) {
            '^(-GitOnly|--git-only)$' { $gitOnly = $true; continue }
            '^(-g|-Global|--global)$' { $globalFlag = $true; continue }
            '^--git-global-only$' { $gitGlobalOnly = $true; continue }
            '^(on|off|status)$' { $cmd = $arg; continue }
        }
    }
    if ($gitGlobalOnly -and $cmd -eq 'status') {
        $root = Get-ClashProxyRoot
        $config = Read-ClashProxyConfig -Root $root
        Show-ClashProxyGlobalStatus -StateDir $config.STATE_DIR
        return
    }
    proxy -Command $cmd -Global:$globalFlag -GitOnly:$gitOnly
}
