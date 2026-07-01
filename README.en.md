# Clash for Windows Multi-Mode Proxy

> **中文文档:** [README.md](README.md)

Unified proxy scripts for **Git Bash**, **WSL2**, **PowerShell**, **cmd**, and **git-only** mode. Works with any local HTTP/SOCKS proxy.

## Overview

This directory (`proxy-config`) provides lightweight scripts to enable or disable proxy settings on demand. By default **`proxy on` affects only the current terminal**; add **`-g` / `--global`** to persist env vars and Git config across Bash, WSL, PowerShell, and cmd.

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

## Scope (session vs global)

| Command | Env vars | Git | Persistence |
|---------|----------|-----|---------------|
| `proxy on` (default) | Current shell | `GIT_HTTP_PROXY` session env | None |
| `proxy on -g` | User env + current shell | `git config --global` | User env + WSL bashrc block + state |
| `proxy on --git-only` | None | `GIT_HTTP_PROXY` session env | None |
| `proxy on -g --git-only` | None | `git config --global` | git global + state |
| `proxy off` | Clear current shell | Clear session Git env | Clears all persistent layers if state is global |
| `proxy off -g` | Clear User env + shell | Clear git global | Clear WSL block + state |

| Shell | Long flag | Short flag |
|-------|-----------|------------|
| Bash / Git Bash / WSL | `--global` | `-g` |
| PowerShell | `-Global` | `-g` |
| cmd | `--global` | `-g` |

**cmd note:** Default `proxy on` uses `proxy-session.cmd` to `set` vars in the current process; `proxy on -g` writes User env — **new cmd windows** inherit it.

## Git configuration

Default `proxy on` does **not** modify `git config --global`; it sets `GIT_HTTP_PROXY` / `GIT_HTTPS_PROXY` for the current session only.

`proxy on -g` (or `proxy on -g --git-only`) modifies **`git config --global`** `http.proxy` and `https.proxy` when `GIT_USE_HTTP=1` (default), affecting all Git HTTP/HTTPS traffic on the machine. Use `proxy off` to clear (global state removes all persistent layers).

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
│   ├── proxy.cmd           # cmd.exe wrapper (-g uses User env)
│   ├── proxy-session.cmd   # cmd session on
│   └── proxy-session-off.cmd # cmd session off
├── lib/                    # Shared bash libraries
│   ├── detect-host.sh      # Platform and host detection
│   ├── git-proxy.sh        # Git session + global helpers
│   ├── persist-env.sh      # User env + WSL bashrc persistence
│   ├── proxy-core.sh       # Core on/off/status logic
│   └── proxy-invoke.sh     # Sourceable CLI entry
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

## Usage modes

| Mode | Shell | Command | Effect |
|------|-------|---------|--------|
| Session full | Git Bash / WSL2 / PS | `proxy on` | Current-window env + Git session env |
| Global full | All platforms | `proxy on -g` | User env + git global + current window |
| Session git-only | Bash / PS | `proxy on --git-only` | `GIT_HTTP_PROXY` session env only |
| Global git-only | All platforms | `proxy on -g --git-only` | git global only |

Turn off with `proxy off` (clears persistent layers when global was active; or `proxy off -g` to force global cleanup).

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
proxy on -g
proxy off
proxy on -GitOnly
```

```bash
proxy status
proxy on
proxy on -g
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
proxy on -g
proxy on --git-only
proxy off
proxy off -g
proxy status
```

### PowerShell / cmd

```powershell
proxy on
proxy on -g
proxy on -GitOnly
proxy off
proxy off -Global
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
| STATE_DIR | ~/.local/state/clash-proxy | Persists `scope=global` when using `-g` |

## State file

Written **only for `proxy on -g`**, at `~/.local/state/clash-proxy/state` with `scope=global` and `mode=full|git-only`. Default session mode does not write a state file. Cleared on `proxy off` when global was active.

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

## License

This project is licensed under the [MIT License](LICENSE).
