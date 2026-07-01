#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstall Clash proxy scripts: PATH, CLASH_PROXY_ROOT, shell hooks.
#>
param(
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$KeepEnvVar,
    [switch]$PurgeProxyEnv
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$BinDir = Join-Path $Root 'bin'

$StartMarker = '# >>> clash-proxy >>>'
$EndMarker = '# <<< clash-proxy <<<'

function Get-PowerShellProfilePaths {
    $paths = @()

    if ($PROFILE) {
        $paths += $PROFILE
    }

    $ps51Profile = Join-Path $HOME 'Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
    $paths += $ps51Profile

    $pwshProfile = Join-Path $HOME 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1'
    $paths += $pwshProfile

    $seen = @{}
    $result = @()
    foreach ($p in $paths) {
        $key = $p.ToLowerInvariant()
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $result += $p
        }
    }
    return $result
}

function Test-PathInPathList {
    param([string]$PathValue, [string]$Entry)
    if (-not $PathValue) { return $false }
    $normalized = $Entry.TrimEnd('\')
    foreach ($part in $PathValue -split ';') {
        if ($part.TrimEnd('\') -eq $normalized) { return $true }
    }
    return $false
}

function Remove-UserPathEntry {
    param([string]$Entry)
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if (-not (Test-PathInPathList -PathValue $userPath -Entry $Entry)) {
        Write-Host "PATH does not contain: $Entry" -ForegroundColor DarkGray
        return $false
    }
    $normalized = $Entry.TrimEnd('\')
    $parts = @($userPath -split ';' | Where-Object { $_.TrimEnd('\') -ne $normalized })
    $newPath = ($parts -join ';').Trim(';')
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove from User PATH: $Entry" -ForegroundColor Yellow
    } else {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        Write-Host "Removed from User PATH: $Entry" -ForegroundColor Green
    }
    return $true
}

function Remove-UserEnvVar {
    param([string]$Name)
    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if (-not $existing) {
        Write-Host "$Name is not set (User)" -ForegroundColor DarkGray
        return $false
    }
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove User $Name (was: $existing)" -ForegroundColor Yellow
    } else {
        [Environment]::SetEnvironmentVariable($Name, $null, 'User')
        Remove-Item "Env:$Name" -ErrorAction SilentlyContinue
        Write-Host "Removed User $Name (was: $existing)" -ForegroundColor Green
    }
    return $true
}

function Remove-MarkedBlock {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) {
        Write-Host "No file: $FilePath" -ForegroundColor DarkGray
        return $false
    }
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content -or $content -notmatch [regex]::Escape($StartMarker)) {
        Write-Host "No clash-proxy block in: $FilePath" -ForegroundColor DarkGray
        return $false
    }
    $pattern = '\r?\n?' + [regex]::Escape($StartMarker) + '[\s\S]*?' + [regex]::Escape($EndMarker) + '\r?\n?'
    $updated = [regex]::Replace($content, $pattern, "`n").TrimEnd()
    if ($WhatIf) {
        Write-Host "[WhatIf] Would remove marked block from: $FilePath" -ForegroundColor Yellow
    } else {
        if ($updated) {
            Set-Content -Path $FilePath -Value $updated -NoNewline
            Add-Content -Path $FilePath -Value "`n"
        } else {
            Set-Content -Path $FilePath -Value "`n" -NoNewline
        }
        Write-Host "Removed hook from: $FilePath" -ForegroundColor Green
    }
    return $true
}

function Remove-WslHook {
    try {
        $null = Get-Command wsl -ErrorAction Stop
    } catch {
        Write-Host 'WSL not available — skipped.' -ForegroundColor DarkGray
        return
    }
    if ($WhatIf) {
        Write-Host '[WhatIf] Would remove WSL hook from ~/.bashrc' -ForegroundColor Yellow
        return
    }
    wsl bash -lc "grep -qF '$StartMarker' ~/.bashrc 2>/dev/null && sed -i '/$StartMarker/,/$EndMarker/d' ~/.bashrc && echo removed || echo 'no clash-proxy block'" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'Removed WSL hook from ~/.bashrc (if present)' -ForegroundColor Green
    }
}

$profilePaths = Get-PowerShellProfilePaths
$bashrcPath = Join-Path $env:USERPROFILE '.bashrc'
$clashRoot = [Environment]::GetEnvironmentVariable('CLASH_PROXY_ROOT', 'User')

Write-Host ''
Write-Host 'Clash Proxy Uninstaller' -ForegroundColor Cyan
Write-Host '=========================' -ForegroundColor Cyan
Write-Host ''
Write-Host "User PATH entry:    $BinDir"
Write-Host "CLASH_PROXY_ROOT:   $(if ($clashRoot) { $clashRoot } else { '(not set)' })"
Write-Host ''
Write-Host 'PowerShell profiles to check:' -ForegroundColor Cyan
foreach ($p in $profilePaths) {
    Write-Host "  $p"
}
Write-Host "Git Bash ~/.bashrc: $bashrcPath"
Write-Host 'WSL ~/.bashrc:      (inside WSL home)'
Write-Host ''

if (-not $Force -and -not $WhatIf) {
    Write-Host 'This will remove PATH entry, shell hooks'
    if (-not $KeepEnvVar) { Write-Host '  and CLASH_PROXY_ROOT user env var' }
    if ($PurgeProxyEnv) { Write-Host '  and persistent proxy env (User env, WSL block, git global, state)' }
    Write-Host ''
    $answer = Read-Host 'Continue? [Y/n]'
    if ($answer -match '^[Nn]') {
        Write-Host 'Uninstall cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

Remove-UserPathEntry -Entry $BinDir | Out-Null
foreach ($profilePath in $profilePaths) {
    Remove-MarkedBlock -FilePath $profilePath | Out-Null
}
Remove-MarkedBlock -FilePath $bashrcPath | Out-Null
Remove-WslHook

if ($PurgeProxyEnv) {
    if ($WhatIf) {
        Write-Host '[WhatIf] Would purge persistent proxy env (User env, WSL block, git global, state)' -ForegroundColor Yellow
    } else {
        $proxyScript = Join-Path $Root 'bin\proxy.ps1'
        if (Test-Path $proxyScript) {
            . $proxyScript
            $config = Read-ClashProxyConfig -Root $Root
            Clear-UserProxyEnv
            Clear-WslPersistEnvBlock
            Clear-GitProxy
            Clear-ToolProxy -Config $config
            Clear-ClashProxyState -StateDir $config.STATE_DIR
            Write-Host 'Purged persistent proxy configuration' -ForegroundColor Green
        } else {
            Write-Host 'proxy.ps1 not found — skipped proxy env purge' -ForegroundColor Yellow
        }
    }
}

if (-not $KeepEnvVar) {
    Remove-UserEnvVar -Name 'CLASH_PROXY_ROOT' | Out-Null
}

Write-Host ''
Write-Host 'Uninstall complete.' -ForegroundColor Green
Write-Host 'Open a new terminal to pick up PATH changes.' -ForegroundColor DarkGray
Write-Host ''
