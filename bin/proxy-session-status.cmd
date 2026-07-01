@echo off
setlocal EnableDelayedExpansion
if not defined CLASH_PROXY_ROOT (
    echo error: CLASH_PROXY_ROOT is not set. Run install.ps1 first. >&2
    exit /b 1
)

set "HTTP_PORT=7890"
set "SOCKS_PORT=7891"
set "HOST="
set "GIT_USE_HTTP=1"

for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%CLASH_PROXY_ROOT%\config.env") do (
    if /i "%%a"=="HTTP_PORT" set "HTTP_PORT=%%b"
    if /i "%%a"=="SOCKS_PORT" set "SOCKS_PORT=%%b"
    if /i "%%a"=="HOST" set "HOST=%%b"
    if /i "%%a"=="GIT_USE_HTTP" set "GIT_USE_HTTP=%%b"
)

set "CLASH_HOST=127.0.0.1"
if defined HOST if not "!HOST!"=="" set "CLASH_HOST=!HOST!"

set "DISPLAY_SCOPE=off"
if defined HTTP_PROXY set "DISPLAY_SCOPE=session"
if defined http_proxy if "!DISPLAY_SCOPE!"=="off" set "DISPLAY_SCOPE=session"
if defined GIT_HTTP_PROXY if "!DISPLAY_SCOPE!"=="off" set "DISPLAY_SCOPE=session"

echo Clash proxy status
echo   Platform:  cmd
echo   Host:      !CLASH_HOST!
echo   HTTP port: !HTTP_PORT!
echo   SOCKS port:!SOCKS_PORT!
echo   Scope:     !DISPLAY_SCOPE!
echo   Mode:      session

if defined HTTP_PROXY (
    echo   session env:
    echo     HTTP_PROXY:  !HTTP_PROXY!
    echo     HTTPS_PROXY: !HTTPS_PROXY!
    echo     ALL_PROXY:   !ALL_PROXY!
    echo     NO_PROXY:    !NO_PROXY!
) else if defined http_proxy (
    echo   session env:
    echo     HTTP_PROXY:  !http_proxy!
    echo     HTTPS_PROXY: !https_proxy!
    echo     ALL_PROXY:   !all_proxy!
    echo     NO_PROXY:    !no_proxy!
) else (
    echo   session env: off
)

if defined GIT_HTTP_PROXY (
    echo   git session:   on
    echo     GIT_HTTP_PROXY:  !GIT_HTTP_PROXY!
    echo     GIT_HTTPS_PROXY: !GIT_HTTPS_PROXY!
) else (
    echo   git session:   off
)

set "PS_ARGS=status --git-global-only"
where pwsh >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_ARGS%
) else (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_ARGS%
)
exit /b %ERRORLEVEL%
