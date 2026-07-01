@echo off
setlocal EnableDelayedExpansion
if not defined CLASH_PROXY_ROOT (
    echo error: CLASH_PROXY_ROOT is not set. Run install.ps1 first. >&2
    exit /b 1
)

set "GIT_ONLY=0"
if /i "%~1"=="--git-only" set "GIT_ONLY=1"
if /i "%~1"=="-GitOnly" set "GIT_ONLY=1"

set "HTTP_PORT=7890"
set "SOCKS_PORT=7891"
set "NO_PROXY=localhost,127.0.0.1"
set "HOST="
set "GIT_USE_HTTP=1"

for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%CLASH_PROXY_ROOT%\config.env") do (
    if /i "%%a"=="HTTP_PORT" set "HTTP_PORT=%%b"
    if /i "%%a"=="SOCKS_PORT" set "SOCKS_PORT=%%b"
    if /i "%%a"=="NO_PROXY" set "NO_PROXY=%%b"
    if /i "%%a"=="HOST" set "HOST=%%b"
    if /i "%%a"=="GIT_USE_HTTP" set "GIT_USE_HTTP=%%b"
)

set "CLASH_HOST=127.0.0.1"
if defined HOST if not "!HOST!"=="" set "CLASH_HOST=!HOST!"

set "HTTP_URL=http://!CLASH_HOST!:!HTTP_PORT!"
set "SOCKS_URL=socks5://!CLASH_HOST!:!SOCKS_PORT!"

if "!GIT_ONLY!"=="1" (
    echo Clash proxy enabled ^(git-only, session^)
    echo   Host: !CLASH_HOST!
    echo   HTTP: !HTTP_URL!
    if "!GIT_USE_HTTP!"=="1" (
        endlocal & set "GIT_HTTP_PROXY=%HTTP_URL%" & set "GIT_HTTPS_PROXY=%HTTP_URL%"
    ) else (
        endlocal
    )
    exit /b 0
)

echo Clash proxy enabled (full, session)
echo   Platform: cmd
echo   Host:     !CLASH_HOST!
echo   HTTP:     !HTTP_URL!
echo   SOCKS:    !SOCKS_URL!

if "!GIT_USE_HTTP!"=="1" (
    endlocal & set "HTTP_PROXY=%HTTP_URL%" & set "HTTPS_PROXY=%HTTP_URL%" & set "ALL_PROXY=%SOCKS_URL%" & set "NO_PROXY=%NO_PROXY%" & set "http_proxy=%HTTP_URL%" & set "https_proxy=%HTTP_URL%" & set "all_proxy=%SOCKS_URL%" & set "no_proxy=%NO_PROXY%" & set "GIT_HTTP_PROXY=%HTTP_URL%" & set "GIT_HTTPS_PROXY=%HTTP_URL%"
) else (
    endlocal & set "HTTP_PROXY=%HTTP_URL%" & set "HTTPS_PROXY=%HTTP_URL%" & set "ALL_PROXY=%SOCKS_URL%" & set "NO_PROXY=%NO_PROXY%" & set "http_proxy=%HTTP_URL%" & set "https_proxy=%HTTP_URL%" & set "all_proxy=%SOCKS_URL%" & set "no_proxy=%NO_PROXY%"
)
exit /b 0
