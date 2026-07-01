# Security Policy

## What this project modifies

Installing `proxy-config` makes **local, user-scoped** changes on your machine:

| Target | Change |
|--------|--------|
| User `PATH` | Adds the `bin` directory so `proxy` is available |
| User env var | Sets `CLASH_PROXY_ROOT` to the install directory |
| PowerShell profiles | Appends a marked `# >>> clash-proxy >>>` hook block (Windows PowerShell 5.1 and/or pwsh) |
| Git Bash `~/.bashrc` | Appends a marked hook block |
| WSL `~/.bashrc` | Appends a marked hook block (with optional backup) |

### Default session mode (`proxy on`)

- Sets proxy environment variables **only in the current terminal session**
- Sets `GIT_HTTP_PROXY` / `GIT_HTTPS_PROXY` in the current session (does **not** modify `git config --global`)
- Does **not** write User-level proxy environment variables or a state file

### Global mode (`proxy on -g` / `--global` / `-Global`)

When you explicitly opt in to global persistence:

| Target | Change |
|--------|--------|
| User env vars | Sets `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `NO_PROXY` (and lowercase aliases) at User scope |
| WSL `~/.bashrc` | Appends a marked `# >>> clash-proxy-env >>>` export block (with backup on update/remove) |
| Git global config | Sets `git config --global` `http.proxy` and `https.proxy` when `GIT_USE_HTTP=1` |
| State file | Writes `~/.local/state/clash-proxy/state` with `scope=global` |

Use `proxy off` to clear session settings; if global mode was active (or `-g` is passed), persistent layers are removed as well.

Uninstall scripts remove the marked hook blocks and PATH/`CLASH_PROXY_ROOT` entries. They do **not** delete entire profile files when only the hook block remains. Global proxy env vars and WSL env blocks are cleared by `proxy off` when global mode was enabled; uninstall does not automatically remove them if left enabled.

## What this project does NOT do

- No telemetry, analytics, or phone-home behavior
- No network requests except when **you** run `proxy status` (health check) or enable proxy for your own tools
- No elevation to Administrator unless you run the installer as admin (not required)
- No modification of system-wide (Machine) environment variables by default

## Health check disclaimer

`proxy status` may perform an optional connectivity test through your configured HTTP proxy:

```
http://www.gstatic.com/generate_204
```

This sends a single HTTP request to Google's static content endpoint to verify the proxy path works. It does not transmit personal data from this repository. If you prefer not to hit external URLs, avoid `proxy status` or disable curl on your system (the check is skipped when `curl` is unavailable).

## Local secrets

- Do **not** commit `config.env.local` (listed in `.gitignore`) if you store machine-specific overrides there
- Review hook snippets in `hooks/` before installing — they only reference `CLASH_PROXY_ROOT` and load local scripts

## Reporting vulnerabilities

If you discover a security issue in this project, please open a GitHub issue or contact the maintainers privately with steps to reproduce and impact assessment.
