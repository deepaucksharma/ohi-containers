@echo off
REM Windows wrapper for the platform-independent test runner
REM Version: 1.0.0

echo Starting New Relic Infrastructure Docker Test Suite on Windows
echo ===========================================================

REM Parse command line arguments
set CATEGORY=all
set VERBOSE=0
set SKIP_SETUP=0
set SKIP_CLEANUP=0

:parse_args
if "%~1"=="" goto end_parse_args
if "%~1"=="-c" (
    set CATEGORY=%~2
    shift
    goto next_arg
)
if "%~1"=="--category" (
    set CATEGORY=%~2
    shift
    goto next_arg
)
if "%~1"=="-v" (
    set VERBOSE=1
    goto next_arg
)
if "%~1"=="--verbose" (
    set VERBOSE=1
    goto next_arg
)
if "%~1"=="--skip-setup" (
    set SKIP_SETUP=1
    goto next_arg
)
if "%~1"=="--skip-cleanup" (
    set SKIP_CLEANUP=1
    goto next_arg
)
if "%~1"=="-h" (
    call :show_help
    exit /b 0
)
if "%~1"=="--help" (
    call :show_help
    exit /b 0
)

echo Unknown option: %~1
call :show_help
exit /b 1

:next_arg
shift
goto parse_args

:end_parse_args

REM Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Docker is not running. Please start Docker and try again.
    exit /b 1
)

REM Find a suitable shell
set SHELL=bash.exe
where %SHELL% >nul 2>&1
if %ERRORLEVEL% neq 0 (
    set SHELL=sh.exe
    where %SHELL% >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        set SHELL=wsl.exe
        where %SHELL% >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: No suitable shell found. Please install Git Bash, MSYS2, WSL, or similar.
            exit /b 1
        )
    )
)

REM Build command arguments
set ARGS=
if "%CATEGORY%" neq "all" (
    set ARGS=%ARGS% --category %CATEGORY%
)
if %VERBOSE% equ 1 (
    set ARGS=%ARGS% --verbose
)
if %SKIP_SETUP% equ 1 (
    set ARGS=%ARGS% --skip-setup
)
if %SKIP_CLEANUP% equ 1 (
    set ARGS=%ARGS% --skip-cleanup
)

REM Run the platform-independent test runner
echo Using shell: %SHELL%
echo Running command: %SHELL% "%~dp0bin\run-tests.sh" %ARGS%
cd /d "%~dp0"
%SHELL% bin/run-tests.sh %ARGS%

REM Check the exit code
if %ERRORLEVEL% neq 0 (
    echo Tests failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo All tests passed successfully!
exit /b 0

:show_help
echo Usage: run-tests.bat [OPTIONS]
echo Run New Relic Infrastructure Docker validation tests
echo.
echo Options:
echo   -c, --category CATEGORY  Run specific test category (unit, integration, security,
echo                           performance, image, config, or all) [default: all]
echo   -v, --verbose            Enable verbose output
echo   --skip-setup             Skip environment setup
echo   --skip-cleanup           Skip environment cleanup
echo   -h, --help               Show this help message
echo.
echo Example:
echo   run-tests.bat --category integration --verbose
exit /b 0
