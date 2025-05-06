@echo off
:: Cross-platform test runner script for Windows
:: Runs the unified test runner with all arguments passed through

setlocal enabledelayedexpansion

:: Set default license key for testing if not set
if "%NEW_RELIC_LICENSE_KEY%"=="" (
  set NEW_RELIC_LICENSE_KEY=dummy012345678901234567890123456789
  echo WARNING: Using dummy license key for testing. Set NEW_RELIC_LICENSE_KEY for production use.
)

:: Parse command line arguments
set CATEGORY=
set TEST=
set VERBOSE=0

:parse_args
if "%~1"=="" goto end_parse_args
if "%~1"=="--category" (
  set CATEGORY=%~2
  shift
  shift
  goto parse_args
)
if "%~1"=="--test" (
  set TEST=%~2
  shift
  shift
  goto parse_args
)
if "%~1"=="--verbose" (
  set VERBOSE=1
  shift
  goto parse_args
)
echo Unknown option: %~1
echo Usage: %0 [--category CATEGORY] [--test TEST_NAME] [--verbose]
exit /b 1

:end_parse_args

:: Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker is not running. Please start Docker and try again.
  exit /b 1
)

:: Check if Docker Compose is available
docker compose version >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker Compose is not available. Please install Docker Compose and try again.
  exit /b 1
)

:: If specific category is requested, create a filter
if not "%CATEGORY%"=="" (
  if not "%TEST%"=="" (
    echo Running specific test: %CATEGORY%/%TEST%
    docker exec test-runner sh -c "/testing/tests/%CATEGORY%/%TEST%.sh"
  ) else (
    echo Running category: %CATEGORY%
    docker exec test-runner sh -c "cd /testing && /testing/tests/run_all_tests.sh --category %CATEGORY%"
  )
) else (
  echo Running all tests...
  docker exec test-runner sh -c "cd /testing && /testing/tests/run_all_tests.sh"
)

exit /b %ERRORLEVEL%
