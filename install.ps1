#Requires -Version 5.1
<#
.SYNOPSIS
    Install Clash proxy scripts: PATH, CLASH_PROXY_ROOT, shell hooks, proxy.cmd.
#>
param(
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$SkipGitBash,
    [switch]$SkipWsl
)

$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$BinDir = Join-Path $Root 'bin'
$HooksDir = Join-Path $Root 'hooks'

$StartMarker = '# >>> clash-proxy >>>'
$EndMarker = '# <<< clash-proxy <<<'

function ConvertTo-GitBashPath {
    param([string]$WindowsPath)
    $p = $WindowsPath.TrimEnd('\') -replace '\\', '/'
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return "/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $p
}

function ConvertTo-WslPath {
    param([string]$WindowsPath)
    $p = $WindowsPath.TrimEnd('\') -replace '\\', '/'
    if ($p -match '^([A-Za-z]):/(.*)$') {
        return "/mnt/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $p
}

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

function Add-UserPathEntry {
    param([string]$Entry)
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if (Test-PathInPathList -PathValue $userPath -Entry $Entry) {
        Write-Host "PATH already contains: $Entry" -ForegroundColor DarkGray
        return $false
    }
    $newPath = if ($userPath) { "$Entry;$userPath" } else { $Entry }
    if ($WhatIf) {
        Write-Host "[WhatIf] Would add to User PATH: $Entry" -ForegroundColor Yellow
    } else {
        [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        $env:PATH = "$Entry;$env:PATH"
        Write-Host "Added to User PATH: $Entry" -ForegroundColor Green
    }
    return $true
}

function Set-UserEnvVar {
    param([string]$Name, [string]$Value)
    $existing = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($existing -eq $Value) {
        Write-Host "$Name already set to: $Value" -ForegroundColor DarkGray
        return $false
    }
    if ($WhatIf) {
        Write-Host "[WhatIf] Would set User $Name=$Value" -ForegroundColor Yellow
    } else {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Set-Item -Path "Env:$Name" -Value $Value
        Write-Host "Set User $Name=$Value" -ForegroundColor Green
    }
    return $true
}

function Get-RenderedSnippet {
    param(
        [string]$SnippetPath,
        [string]$ProxyRoot
    )
    $content = Get-Content $SnippetPath -Raw
    return $content.Replace('__CLASH_PROXY_ROOT__', $ProxyRoot)
}

function Install-MarkedBlock {
    param(
        [string]$FilePath,
        [string]$BlockContent
    )
    $dir = Split-Path -Parent $FilePath
    if ($dir -and -not (Test-Path $dir)) {
        if ($WhatIf) {
            Write-Host "[WhatIf] Would create directory: $dir" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
    }

    $existing = ''
    if (Test-Path $FilePath) {
        $existing = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
        if (-not $existing) { $existing = '' }
    }

    if ($existing -match [regex]::Escape($StartMarker)) {
        $pattern = [regex]::Escape($StartMarker) + '[\s\S]*?' + [regex]::Escape($EndMarker)
        $updated = [regex]::Replace($existing, $pattern, $BlockContent.TrimEnd())
        if ($WhatIf) {
            Write-Host "[WhatIf] Would update marked block in: $FilePath" -ForegroundColor Yellow
        } else {
            if (-not (Test-Path $FilePath)) {
                New-Item -ItemType File -Force -Path $FilePath | Out-Null
            }
            Set-Content -Path $FilePath -Value $updated.TrimEnd() -NoNewline
            Add-Content -Path $FilePath -Value "`n"
            Write-Host "Updated hook in: $FilePath" -ForegroundColor Green
        }
    } else {
        $append = if ($existing -and -not $existing.EndsWith("`n")) { "`n`n$BlockContent" } else { "`n$BlockContent" }
        if ($WhatIf) {
            Write-Host "[WhatIf] Would append hook to: $FilePath" -ForegroundColor Yellow
        } else {
            if (-not (Test-Path $FilePath)) {
                New-Item -ItemType File -Force -Path $FilePath | Out-Null
            }
            Add-Content -Path $FilePath -Value $append
            Write-Host "Installed hook in: $FilePath" -ForegroundColor Green
        }
    }
}

function Test-WslAvailable {
    try {
        $null = Get-Command wsl -ErrorAction Stop
        $null = wsl -e true 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Install-WslHook {
    param([string]$WslRoot)
    $block = Get-RenderedSnippet -SnippetPath (Join-Path $HooksDir 'profile.snippet') -ProxyRoot $WslRoot
    $backupSuffix = Get-Date -Format 'yyyyMMdd'

    if ($WhatIf) {
        Write-Host "[WhatIf] Would backup WSL ~/.bashrc to ~/.bashrc.bak.clash-proxy-$backupSuffix (if present)" -ForegroundColor Yellow
        Write-Host "[WhatIf] Would install WSL hook in ~/.bashrc (CLASH_PROXY_ROOT=$WslRoot)" -ForegroundColor Yellow
        return
    }

    wsl bash -lc "touch ~/.bashrc" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'WSL: could not access ~/.bashrc — skipping.' -ForegroundColor Yellow
        return
    }

    wsl bash -lc "test -f ~/.bashrc && cp ~/.bashrc ~/.bashrc.bak.clash-proxy-$backupSuffix 2>/dev/null || true"
    wsl bash -lc "grep -qF '$StartMarker' ~/.bashrc 2>/dev/null && sed -i '/$StartMarker/,/$EndMarker/d' ~/.bashrc || true"
    $tempFile = [System.IO.Path]::GetTempFileName()
    try {
        [System.IO.File]::WriteAllText($tempFile, $block, (New-Object System.Text.UTF8Encoding $false))
        $wslTemp = ConvertTo-WslPath -WindowsPath $tempFile
        wsl bash -lc "cat '$wslTemp' >> ~/.bashrc"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installed WSL hook in ~/.bashrc (CLASH_PROXY_ROOT=$WslRoot)" -ForegroundColor Green
            Write-Host "  WSL backup: ~/.bashrc.bak.clash-proxy-$backupSuffix (if ~/.bashrc existed)" -ForegroundColor DarkGray
        } else {
            Write-Host 'WSL: could not append hook — add hooks/profile.snippet to WSL ~/.bashrc manually.' -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WSL: hook install skipped ($($_.Exception.Message))" -ForegroundColor Yellow
    } finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

$profilePaths = Get-PowerShellProfilePaths
$bashrcPath = Join-Path $env:USERPROFILE '.bashrc'
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')

Write-Host ''
Write-Host 'Clash Proxy Installer' -ForegroundColor Cyan
Write-Host '=====================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Install root:       $Root"
Write-Host "Bin directory:      $BinDir"
Write-Host "CLASH_PROXY_ROOT:   $Root"
Write-Host "User PATH entry:    $BinDir"
Write-Host ''
Write-Host 'PowerShell profiles:' -ForegroundColor Cyan
foreach ($p in $profilePaths) {
    Write-Host "  $p"
}
if (-not $SkipGitBash) {
    Write-Host "Git Bash ~/.bashrc: $bashrcPath"
}
if (-not $SkipWsl -and (Test-WslAvailable)) {
    Write-Host 'WSL ~/.bashrc:      (inside WSL home)'
}
Write-Host ''

if (-not $Force -and -not $WhatIf) {
    Write-Host 'This will:' -ForegroundColor Yellow
    Write-Host '  - Set user env var CLASH_PROXY_ROOT'
    Write-Host '  - Add bin directory to User PATH'
    Write-Host '  - Install PowerShell hook in each profile listed above'
    if (-not $SkipGitBash) { Write-Host "  - Install Git Bash hook in $bashrcPath" }
    if (-not $SkipWsl) { Write-Host '  - Install WSL hook in ~/.bashrc (if WSL available, with backup)' }
    Write-Host ''
    $answer = Read-Host 'Continue? [Y/n]'
    if ($answer -match '^[Nn]') {
        Write-Host 'Install cancelled.' -ForegroundColor Yellow
        exit 0
    }
}

Set-UserEnvVar -Name 'CLASH_PROXY_ROOT' -Value $Root | Out-Null
Add-UserPathEntry -Entry $BinDir | Out-Null

$psSnippet = Get-Content (Join-Path $HooksDir 'powershell-profile.snippet') -Raw
foreach ($profilePath in $profilePaths) {
    Install-MarkedBlock -FilePath $profilePath -BlockContent $psSnippet
}

if (-not $SkipGitBash) {
    $gitBashRoot = ConvertTo-GitBashPath -WindowsPath $Root
    $bashBlock = Get-RenderedSnippet -SnippetPath (Join-Path $HooksDir 'bashrc.snippet') -ProxyRoot $gitBashRoot
    Install-MarkedBlock -FilePath $bashrcPath -BlockContent $bashBlock
}

if (-not $SkipWsl -and (Test-WslAvailable)) {
    $wslRoot = ConvertTo-WslPath -WindowsPath $Root
    Install-WslHook -WslRoot $wslRoot
} elseif (-not $SkipWsl) {
    Write-Host 'WSL not detected — skipped WSL hook.' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Install complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Verification (open a NEW terminal window):' -ForegroundColor Yellow
Write-Host '  proxy status'
Write-Host '  proxy on               # session only (current window)'
Write-Host '  proxy on -g            # persistent (User env + git global)'
Write-Host '  proxy off'
Write-Host '  proxy on --git-only    # Git Bash / cmd via proxy.cmd'
Write-Host '  proxy on -GitOnly      # PowerShell'
Write-Host ''
Write-Host 'To remove: .\uninstall.ps1' -ForegroundColor DarkGray
Write-Host ''
