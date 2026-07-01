# Clash for Windows Multi-Mode Proxy

> **中文文档:** [README.md](README.md)

Unified proxy scripts for **Git Bash**, **WSL2**, **PowerShell**, **cmd**, and **git-only** mode. Works with any local HTTP/SOCKS proxy.

## Overview

This directory (`proxy-config`) provides lightweight scripts to enable or disable proxy settings on demand in your development environment. Four usage modes are supported: full proxy (env vars + Git), git-only proxy, plus off and status commands per shell.

The installer detects its own directory automatically — **no hardcoded paths** required.

## Proxy client compatibility

> **Clash for Windows (CFW) is discontinued.** This tool is not tied to a specific client. Any local **HTTP + SOCKS** proxy works, for example:
>
> - [Clash Verge Rev](https://github.com/clash-verge-rev/clash-verge-rev)
> - [Mihomo / Clash Meta](https://github.com/MetaCubeX/mihomo)
> - Other Clash-compatible HTTP/SOCKS endpoints

Default ports are HTTP `7890` and SOCKS `7891`. Edit `config.env` if yours differ.

### Prerequisites

1. Your proxy client is running with system proxy or manual ports configured.
2. **WSL2 only**: Enable **Allow LAN** in the client so WSL can reach the Windows host proxy.

## PowerShell profile paths

Windows has **two separate PowerShell installations**, each with its own `$PROFILE`:

| Shell | Typical `$PROFILE` path |
|-------|-------------------------|
| Windows PowerShell 5.1 | `%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1` |
| PowerShell 7+ (`pwsh`) | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` |

**Recommendation:** Run `.\install.ps1` from **Windows PowerShell 5.1** (used by default from cmd via `powershell.exe`). The installer writes hooks to **both** profile paths (creating directories/files if needed) so `proxy` works in either shell.

## Git global config warning

`proxy on` (full mode) and `proxy on --git-only` / `proxy on -GitOnly` modify **`git config --global`** `http.proxy` and `https.proxy` when `GIT_USE_HTTP=1` (default). This affects Git HTTP/HTTPS traffic for all repositories on the machine. Use `proxy off` to clear these settings.

## Health check disclaimer

When `curl` is available, `proxy status` sends a test request through the HTTP proxy to:

```
http://www.gstatic.com/generate_204
```

This verifies connectivity via Google’s static content endpoint. It does **not** upload local files or repository data. To avoid external requests, skip `proxy status` or run without `curl` (the check is skipped). See [SECURITY.md](SECURITY.md).

## Directory layout

```
proxy-config/
├── LICENSE                 # MIT License
├── CHANGELOG.md
├── SECURITY.md
├── config.env              # Ports, NO_PROXY, optional HOST override
├── bin/
│   ├── proxy               # Bash CLI (Git Bash / WSL2)
│   ├── proxy.ps1           # PowerShell CLI
│   └── proxy.cmd           # cmd.exe wrapper
├── lib/                    # Shared bash libraries
│   ├── detect-host.sh      # Platform and host detection
│   ├── git-proxy.sh        # Git proxy configuration
│   └── proxy-core.sh       # Core on/off/status logic
├── hooks/                  # Shell profile snippets (installed by scripts)
│   ├── bashrc.snippet      # Git Bash
│   ├── profile.snippet     # WSL2
│   └── powershell-profile.snippet
├── install.ps1             # Windows installer (recommended)
├── uninstall.ps1           # Windows uninstaller
├── install.sh              # Git Bash / WSL installer (optional)
├── uninstall.sh            # Git Bash / WSL uninstaller (optional)
├── README.md               # Chinese documentation
└── README.en.md            # English documentation (this file)
```

## Four usage modes

| Mode | Shell | Command | Effect |
|------|-------|---------|--------|
| Full (Bash) | Git Bash / WSL2 | `proxy on` | Env vars + git config |
| Git-only (Bash) | Git Bash / WSL2 | `proxy on --git-only` | Git config only |
| Full (PS) | PowerShell | `proxy on` | Env vars + git config |
| Git-only (PS) | PowerShell | `proxy on -GitOnly` | Git config only |

Turn off with `proxy off` (or `proxy off --git-only` / `proxy off -GitOnly`).

## Installation

From the `proxy-config` directory (any location):

```powershell
cd path\to\proxy-config
.\install.ps1
```

The installer will:

1. Set user env var `CLASH_PROXY_ROOT` to the install directory
2. Add `bin` to user **PATH**
3. Write marked hook snippets into **both Windows PowerShell 5.1 and pwsh `$PROFILE` paths**, Git Bash `~/.bashrc`, and WSL `~/.bashrc` (if WSL is detected)

Actual paths (PATH entry, `CLASH_PROXY_ROOT`, each profile and bashrc path) are printed during install.

Options:

```powershell
.\install.ps1 -WhatIf      # Preview without changes
.\install.ps1 -Force       # Skip confirmation
.\install.ps1 -SkipGitBash # Skip Git Bash hook
.\install.ps1 -SkipWsl     # Skip WSL hook
```

**Git Bash / WSL** can also use the bash installer:

```bash
cd /path/to/proxy-config
./install.sh
```

### Verify after install

**Open a new terminal window**, then:

```powershell
proxy status
proxy on
proxy off
proxy on -GitOnly
```

```bash
proxy status
proxy on --git-only
```

In cmd.exe, `proxy on`, `proxy status`, etc. work via `proxy.cmd`.

## Uninstall

```powershell
cd path\to\proxy-config
.\uninstall.ps1
```

Or from Git Bash / WSL:

```bash
./uninstall.sh
```

This removes the PATH entry, hook blocks from **all** PowerShell profile paths and bashrc files, and the `CLASH_PROXY_ROOT` user env var. Safe to run multiple times (idempotent). Empty profile files are kept (not deleted) after hook removal.

### Verify after uninstall

Open a **new terminal** and confirm cleanup:

```powershell
# proxy should be unavailable (or not point to this project's bin)
Get-Command proxy -ErrorAction SilentlyContinue

# User env var should be removed
[Environment]::GetEnvironmentVariable('CLASH_PROXY_ROOT', 'User')

# Git global proxy should be cleared (if you had run proxy on)
git config --global --get http.proxy
git config --global --get https.proxy
```

```bash
# Bash / WSL
command -v proxy
echo "$CLASH_PROXY_ROOT"
git config --global --get http.proxy
```

If `Get-Command proxy` still returns a path, close all old terminal windows and retry.

## Commands

### Bash (Git Bash / WSL2)

```bash
proxy on
proxy on --git-only
proxy off
proxy off --git-only
proxy status
```

### PowerShell / cmd

```powershell
proxy on
proxy on -GitOnly
proxy off
proxy off -GitOnly
proxy status
```

## Configuration (config.env)

| Variable | Default | Description |
|----------|---------|-------------|
| HTTP_PORT | 7890 | HTTP proxy port |
| SOCKS_PORT | 7891 | SOCKS proxy port |
| NO_PROXY | localhost, private ranges | Bypass list |
| HOST | (auto) | Force Clash host (WSL2: usually Windows IP) |
| GIT_USE_HTTP | 1 | Set git http/https proxy when enabling |
| STATE_DIR | ~/.local/state/clash-proxy | Persists active mode |

### Host detection

- **Git Bash / PowerShell**: 127.0.0.1
- **WSL2**: /etc/resolv.conf nameserver, fallback to default gateway
- **Override**: set HOST in config.env

## Troubleshooting

### WSL2 cannot reach proxy

- Enable **Allow LAN** in your proxy client.
- Run `proxy status` and confirm host is your Windows IP (not 127.0.0.1).
- Set HOST to your Windows IP in config.env if auto-detection fails.

### proxy: command not found

- Confirm you ran `install.ps1` and **opened a new terminal** for PATH to apply.
- Check `echo $env:CLASH_PROXY_ROOT` (PowerShell) or `echo $CLASH_PROXY_ROOT` (Bash).
- Reload manually: `source ~/.bashrc` or restart PowerShell.

### Git still slow or fails

- Use `proxy on --git-only` if you only need git through the proxy.
- Check `git config --global --get http.proxy`.

### Health check fails

- Ensure your proxy client is running and ports match config.env.
- Confirm firewall allows local connections on 7890/7891.
- The health check hits `http://www.gstatic.com/generate_204`; it may show unreachable when offline or blocked.

## State file

When enabled, mode is stored at `~/.local/state/clash-proxy/state` with `mode=full` or `mode=git-only`. Cleared on `proxy off`.

## License

This project is licensed under the [MIT License](LICENSE).
