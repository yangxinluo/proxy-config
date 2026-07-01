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
    param(
        [string]$Root,
        [string]$Profile = ''
    )

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
        HEALTH_CHECK_URL = 'http://www.gstatic.com/generate_204'
        NPM_USE_PROXY    = '0'
        PIP_USE_PROXY    = '0'
        DOCKER_USE_PROXY = '0'
        APT_USE_PROXY    = '0'
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

    if ($Profile) {
        $profilePath = Join-Path $Root "config.d/${Profile}.env"
        if (-not (Test-Path $profilePath)) {
            throw "profile not found: $Profile (expected $profilePath)"
        }
        foreach ($line in Get-Content $profilePath) {
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
            if ($trimmed -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $config[$Matches[1]] = $Matches[2]
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

function Get-GitProxyUrl {
    param(
        [hashtable]$Config,
        [string]$HttpUrl,
        [string]$SocksUrl
    )
    $scheme = if ($Config.GIT_PROXY_SCHEME) { $Config.GIT_PROXY_SCHEME.ToLower() } else { 'http' }
    if ($scheme -in @('socks5', 'socks')) {
        return $SocksUrl
    }
    return $HttpUrl
}

function Set-GitSessionProxy {
    param(
        [hashtable]$Config,
        [string]$HttpUrl,
        [string]$SocksUrl
    )
    $proxyUrl = Get-GitProxyUrl -Config $Config -HttpUrl $HttpUrl -SocksUrl $SocksUrl
    $env:GIT_HTTP_PROXY = $proxyUrl
    $env:GIT_HTTPS_PROXY = $proxyUrl
}

function Clear-GitSessionProxy {
    Remove-Item Env:GIT_HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:GIT_HTTPS_PROXY -ErrorAction SilentlyContinue
}

function Set-GitProxy {
    param(
        [hashtable]$Config,
        [string]$HttpUrl,
        [string]$SocksUrl
    )
    $proxyUrl = Get-GitProxyUrl -Config $Config -HttpUrl $HttpUrl -SocksUrl $SocksUrl
    git config --global http.proxy $proxyUrl
    git config --global https.proxy $proxyUrl
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

function Get-ClashProxyVersion {
    $versionFile = Join-Path (Get-ClashProxyRoot) 'VERSION'
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    }
    return 'unknown'
}

function Show-ProxyHelp {
    @'
usage: proxy {on|off|status|toggle|version|help} [options]

commands:
  on       Enable proxy (session by default)
  off      Disable proxy
  status   Show proxy status
  toggle   Switch between on and off
  version  Print version
  help     Show this help

options:
  -g, --global, -Global   Persist settings across terminals
  --git-only, -GitOnly    Configure Git proxy only
  --json                  Machine-readable status output (status only)
'@ | Write-Host
}

function Test-ClashProxyPort {
    param(
        [string]$HostAddr,
        [int]$Port
    )
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostAddr, $Port, $null, $null)
        $ok = $async.AsyncWaitHandle.WaitOne(2000, $false)
        if ($ok -and $client.Connected) {
            $client.Close()
            return $true
        }
        $client.Close()
    } catch {}
    return $false
}

function Test-ClashProxyHealth {
    param(
        [hashtable]$Config,
        [string]$HttpUrl
    )
    if (-not $Config.HEALTH_CHECK_URL) {
        return 'skipped'
    }
    try {
        $response = Invoke-WebRequest -Uri $Config.HEALTH_CHECK_URL `
            -Proxy $HttpUrl -TimeoutSec 3 -UseBasicParsing
        return "ok (HTTP $($response.StatusCode))"
    } catch {
        return 'unreachable'
    }
}

function Get-ClashProxyStatusJson {
    param(
        [hashtable]$Config,
        [string]$HostAddr,
        [string]$HttpUrl,
        [hashtable]$State
    )
    $displayScope = 'off'
    if ($env:CLASH_PROXY_SCOPE) {
        $displayScope = $env:CLASH_PROXY_SCOPE
    } elseif ($State.scope -eq 'global') {
        $displayScope = 'global'
    } elseif ($env:HTTP_PROXY -or $env:http_proxy -or $env:GIT_HTTP_PROXY) {
        $displayScope = 'session'
    }

    $gitHttp = git config --global --get http.proxy 2>$null
    $portOpen = Test-ClashProxyPort -HostAddr $hostAddr -Port ([int]$Config.HTTP_PORT)
    $health = Test-ClashProxyHealth -Config $Config -HttpUrl $httpUrl

    [ordered]@{
        version     = Get-ClashProxyVersion
        platform    = 'powershell'
        host        = $hostAddr
        http_port   = [int]$Config.HTTP_PORT
        socks_port  = [int]$Config.SOCKS_PORT
        scope       = $displayScope
        mode        = $State.mode
        session_env = [bool]($env:HTTP_PROXY -or $env:http_proxy)
        git_session = [bool]($env:GIT_HTTP_PROXY -or $env:GIT_HTTPS_PROXY)
        git_global  = [bool]$gitHttp
        port_open   = $portOpen
        health      = $health
    } | ConvertTo-Json -Compress
}

function Set-ToolProxy {
    param(
        [hashtable]$Config,
        [string]$HttpUrl,
        [string]$SocksUrl
    )
    if ($Config.NPM_USE_PROXY -eq '1' -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        npm config set proxy $HttpUrl 2>$null
        npm config set https-proxy $HttpUrl 2>$null
    }
    if ($Config.PIP_USE_PROXY -eq '1') {
        $env:PIP_PROXY = $HttpUrl
    }
    if ($Config.DOCKER_USE_PROXY -eq '1') {
        $env:DOCKER_HTTP_PROXY = $HttpUrl
        $env:DOCKER_HTTPS_PROXY = $HttpUrl
        $env:DOCKER_ALL_PROXY = $SocksUrl
        $env:DOCKER_NO_PROXY = $Config.NO_PROXY
    }
    if ($Config.APT_USE_PROXY -eq '1') {
        $env:APT_HTTP_PROXY = $HttpUrl
        $env:APT_HTTPS_PROXY = $HttpUrl
    }
}

function Clear-ToolProxy {
    param([hashtable]$Config)
    if ($Config.NPM_USE_PROXY -eq '1' -and (Get-Command npm -ErrorAction SilentlyContinue)) {
        npm config delete proxy 2>$null
        npm config delete https-proxy 2>$null
    }
    Remove-Item Env:PIP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:DOCKER_HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:DOCKER_HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:DOCKER_ALL_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:DOCKER_NO_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:APT_HTTP_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:APT_HTTPS_PROXY -ErrorAction SilentlyContinue
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
        [ValidateSet('on', 'off', 'status', 'toggle', 'version', 'help')]
        [string]$Command,

        [Alias('g')]
        [switch]$Global,

        [switch]$GitOnly,

        [switch]$Json,

        [string]$Profile = ''
    )

    if ($Command -eq 'help') {
        Show-ProxyHelp
        return
    }
    if ($Command -eq 'version') {
        Write-Output (Get-ClashProxyVersion)
        return
    }

    $root = Get-ClashProxyRoot
    $config = Read-ClashProxyConfig -Root $root -Profile $Profile
    $hostAddr = Get-ClashProxyHost -Config $config
    $httpUrl = "http://${hostAddr}:$($config.HTTP_PORT)"
    $socksUrl = "socks5://${hostAddr}:$($config.SOCKS_PORT)"
    $stateDir = $config.STATE_DIR

    if ($Command -eq 'toggle') {
        $state = Read-ClashProxyState -StateDir $stateDir
        $isOn = $env:HTTP_PROXY -or $env:http_proxy -or $env:GIT_HTTP_PROXY -or ($state.scope -eq 'global')
        if ($isOn) {
            proxy -Command off -Global:$Global -GitOnly:$GitOnly -Profile $Profile
        } else {
            proxy -Command on -Global:$Global -GitOnly:$GitOnly -Profile $Profile
        }
        return
    }

    switch ($Command) {
        'on' {
            if ($Global) {
                $env:CLASH_PROXY_SCOPE = 'global'

                if ($GitOnly) {
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
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
                    Set-ToolProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
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
                        Set-GitSessionProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
                    }
                    Write-Host 'Clash proxy enabled (git-only, session)'
                    Write-Host "  Host: $hostAddr"
                    Write-Host "  HTTP: $httpUrl"
                } else {
                    Set-SessionProxyEnv -HttpUrl $httpUrl -SocksUrl $socksUrl -NoProxy $config.NO_PROXY
                    Set-ToolProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
                    if ($config.GIT_USE_HTTP -eq '1') {
                        Set-GitSessionProxy -Config $config -HttpUrl $httpUrl -SocksUrl $socksUrl
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
                Clear-ToolProxy -Config $config

                $state = Read-ClashProxyState -StateDir $stateDir
                $clearGlobal = $Global -or ($state.scope -eq 'global')

                if ($clearGlobal) {
                    Clear-UserProxyEnv
                    Clear-WslPersistEnvBlock
                    Clear-GitProxy
                    Clear-ToolProxy -Config $config
                    Clear-ClashProxyState -StateDir $stateDir
                    Write-Host 'Clash proxy disabled (session + global)'
                } else {
                    Write-Host 'Clash proxy disabled (session)'
                }
            }
        }
        'status' {
            $state = Read-ClashProxyState -StateDir $stateDir

            if ($Json) {
                Write-Output (Get-ClashProxyStatusJson -Config $config -HostAddr $hostAddr -HttpUrl $httpUrl -State $state)
                return
            }

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

            if (Test-ClashProxyPort -HostAddr $hostAddr -Port ([int]$config.HTTP_PORT)) {
                Write-Host "  port:        open (TCP $($config.HTTP_PORT))"
            } else {
                Write-Host "  port:        closed (TCP $($config.HTTP_PORT))"
            }

            Write-Host "  health:      $(Test-ClashProxyHealth -Config $config -HttpUrl $httpUrl)"
        }
    }
}

# Direct invocation: proxy.cmd or powershell -File proxy.ps1 on|off|status
if ($MyInvocation.InvocationName -ne '.') {
    $cmd = 'status'
    $gitOnly = $false
    $globalFlag = $false
    $gitGlobalOnly = $false
    $jsonFlag = $false
    $profileName = ''
    $parsedArgs = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $args.Count; $i++) {
        if ($args[$i] -eq '--profile' -and ($i + 1) -lt $args.Count) {
            $profileName = $args[$i + 1]
            $i++
            continue
        }
        $parsedArgs.Add($args[$i])
    }
    foreach ($arg in $parsedArgs) {
        switch -Regex ($arg) {
            '^(-GitOnly|--git-only)$' { $gitOnly = $true; continue }
            '^(-g|-Global|--global)$' { $globalFlag = $true; continue }
            '^--git-global-only$' { $gitGlobalOnly = $true; continue }
            '^--json$' { $jsonFlag = $true; continue }
            '^(on|off|status|toggle|version|help)$' { $cmd = $arg; continue }
            '^(-h|--help)$' { $cmd = 'help'; continue }
        }
    }
    if ($gitGlobalOnly -and $cmd -eq 'status') {
        $root = Get-ClashProxyRoot
        $config = Read-ClashProxyConfig -Root $root -Profile $profileName
        Show-ClashProxyGlobalStatus -StateDir $config.STATE_DIR
        return
    }
    proxy -Command $cmd -Global:$globalFlag -GitOnly:$gitOnly -Json:$jsonFlag -Profile $profileName
}
