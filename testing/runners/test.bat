@echo off
REM Unified Test Runner for Windows
REM This calls the platform-independent test runner script

REM Get the directory of this script
SET SCRIPT_DIR=%~dp0
SET PROJECT_ROOT=%SCRIPT_DIR%\..\..

REM Find a suitable shell
SET SHELL=bash.exe
where %SHELL% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    SET SHELL=sh.exe
    where %SHELL% >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        SET SHELL=wsl.exe
        where %SHELL% >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: No suitable shell found. Please install Git Bash, MSYS2, WSL, or similar.
            exit /b 1
        )
    )
)

REM Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Forward all arguments to the unified test runner
echo Using shell: %SHELL%
echo Running test runner with arguments: %*
cd /d "%PROJECT_ROOT%"
%SHELL% testing/bin/unified/test-runner.sh %*

REM Return the exit code from the test runner
exit /b %ERRORLEVEL%
