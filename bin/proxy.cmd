@echo off
setlocal
if not defined CLASH_PROXY_ROOT (
    echo error: CLASH_PROXY_ROOT is not set. Run install.ps1 first. >&2
    exit /b 1
)
where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %*
)
