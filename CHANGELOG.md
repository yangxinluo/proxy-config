# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/example/proxy-config/releases/tag/v1.0.0
