@echo off
if not defined CLASH_PROXY_ROOT (
    echo error: CLASH_PROXY_ROOT is not set. Run install.ps1 first. >&2
    exit /b 1
)

set "CMD_ARG="
set "GLOBAL_FLAG=0"
set "GIT_ONLY=0"

:parse_args
if "%~1"=="" goto done_parse
if /i "%~1"=="on" set "CMD_ARG=on" & shift & goto parse_args
if /i "%~1"=="off" set "CMD_ARG=off" & shift & goto parse_args
if /i "%~1"=="status" set "CMD_ARG=status" & shift & goto parse_args
if /i "%~1"=="-g" set "GLOBAL_FLAG=1" & shift & goto parse_args
if /i "%~1"=="--global" set "GLOBAL_FLAG=1" & shift & goto parse_args
if /i "%~1"=="-Global" set "GLOBAL_FLAG=1" & shift & goto parse_args
if /i "%~1"=="--git-only" set "GIT_ONLY=1" & shift & goto parse_args
if /i "%~1"=="-GitOnly" set "GIT_ONLY=1" & shift & goto parse_args
shift
goto parse_args

:done_parse
if not defined CMD_ARG set "CMD_ARG=status"

if "%CMD_ARG%"=="on" if "%GLOBAL_FLAG%"=="0" (
    if "%GIT_ONLY%"=="1" (
        call "%CLASH_PROXY_ROOT%\bin\proxy-session.cmd" --git-only
    ) else (
        call "%CLASH_PROXY_ROOT%\bin\proxy-session.cmd"
    )
    exit /b %ERRORLEVEL%
)

if "%CMD_ARG%"=="off" if "%GLOBAL_FLAG%"=="0" (
    call "%CLASH_PROXY_ROOT%\bin\proxy-session-off.cmd"
    set "PS_OFF_ARGS=off"
    if "%GIT_ONLY%"=="1" set "PS_OFF_ARGS=off --git-only"
    where pwsh >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_OFF_ARGS%
    ) else (
        pwsh -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_OFF_ARGS%
    )
    exit /b %ERRORLEVEL%
)

if "%CMD_ARG%"=="status" if "%GLOBAL_FLAG%"=="0" (
    call "%CLASH_PROXY_ROOT%\bin\proxy-session-status.cmd"
    exit /b %ERRORLEVEL%
)

set "PS_ARGS=%CMD_ARG%"
if "%GLOBAL_FLAG%"=="1" set "PS_ARGS=%PS_ARGS% -g"
if "%GIT_ONLY%"=="1" set "PS_ARGS=%PS_ARGS% --git-only"

where pwsh >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_ARGS%
) else (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%CLASH_PROXY_ROOT%\bin\proxy.ps1" %PS_ARGS%
)
exit /b %ERRORLEVEL%
