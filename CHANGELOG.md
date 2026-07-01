# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-07-01

### Fixed

- **cmd `proxy status`:** New `bin/proxy-session-status.cmd` reads session env vars from the current cmd process instead of delegating to PowerShell (which could not see `set` values).
- **Default config drift:** Added `config.defaults.env` as the single source of default values; Bash, PowerShell, and cmd all load it before `config.env`.

### Security

- **PowerShell injection:** `persist-env.sh` now passes User env values via environment variables instead of string interpolation in `-Command`.
- **Config validation:** Host and port values are validated at startup in Bash (`lib/validate-config.sh`) and PowerShell (`Test-ClashProxyConfig`).

## [1.1.0] - 2026-07-01

### Changed

- **Breaking:** `proxy on` now enables proxy for the **current terminal session only** (environment variables + `GIT_HTTP_PROXY` / `GIT_HTTPS_PROXY`). It no longer writes `git config --global`, User-level environment variables, or a state file by default.
- Bash `proxy()` functions now **source** `lib/proxy-invoke.sh` in the current shell instead of spawning a subprocess, so session env vars persist correctly in Git Bash and WSL.

### Added

- **Global mode:** `proxy on -g` / `--global` / `-Global` persists proxy settings across new terminals:
  - Windows: User-level `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY` (and lowercase aliases)
  - WSL: marked `# >>> clash-proxy-env >>>` export block in `~/.bashrc`
  - Git: `git config --global` for `http.proxy` / `https.proxy`
  - State file records `scope=global`
- `lib/persist-env.sh` and `lib/proxy-invoke.sh` for shared persistence and sourceable CLI
- `bin/proxy-session.cmd` and `bin/proxy-session-off.cmd` for cmd.exe session-only proxy (current process `set`)
- `proxy status` now reports **Scope** (`session` | `global` | `off`), session env, User env, git session vs global

### Migration from v1.0.0

If you previously ran `proxy on` and want the old persistent behavior, run `proxy on -g` once, then use `proxy off` to clear everything when done. After upgrading hooks, run `install.ps1 -Force` to refresh the source-based `proxy()` in your shell profiles.

## [1.0.0] - 2026-07-01

### Added

- Unified `proxy` CLI for Git Bash, WSL2, PowerShell, and cmd
- Four usage modes: full proxy, git-only, off, and status
- Windows installer (`install.ps1`) and uninstaller (`uninstall.ps1`)
- Bash installer (`install.sh`) and uninstaller (`uninstall.sh`) for Git Bash / WSL
- Idempotent marked hook blocks for PowerShell profiles, Git Bash, and WSL `~/.bashrc`
- Dual PowerShell profile support (Windows PowerShell 5.1 and PowerShell 7 / pwsh)
- Auto-detection of Clash host (127.0.0.1 on Windows; Windows IP in WSL2)
- Health check via HTTP proxy to `http://www.gstatic.com/generate_204`
- MIT License, `.gitignore`, `SECURITY.md`, and bilingual README documentation

### Notes

- Default HTTP/SOCKS ports match common Clash setups (7890 / 7891); override in `config.env`
- Compatible with any local HTTP+SOCKS proxy (Clash Verge, Mihomo, legacy CFW, etc.)

[1.1.1]: https://github.com/example/proxy-config/releases/tag/v1.1.1
[1.1.0]: https://github.com/example/proxy-config/releases/tag/v1.1.0
[1.0.0]: https://github.com/example/proxy-config/releases/tag/v1.0.0
