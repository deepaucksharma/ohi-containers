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
set SKIP_SETUP=0
set SKIP_CLEANUP=0
set BUILD_ONLY=0

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
if "%~1"=="--skip-setup" (
  set SKIP_SETUP=1
  shift
  goto parse_args
)
if "%~1"=="--skip-cleanup" (
  set SKIP_CLEANUP=1
  shift
  goto parse_args
)
if "%~1"=="--build-only" (
  set BUILD_ONLY=1
  shift
  goto parse_args
)
echo Unknown option: %~1
echo Usage: %0 [--category CATEGORY] [--test TEST_NAME] [--verbose] [--skip-setup] [--skip-cleanup] [--build-only]
exit /b 1

:end_parse_args

:: Check if Docker is running
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker is not running. Please start Docker and try again.
  exit /b 1
)

:: Check if Docker Compose is available
call scripts\compose-helper.bat version >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker Compose is not available. Please install Docker Compose and try again.
  exit /b 1
)

:: Build Docker image first
if %SKIP_SETUP%==0 (
  echo Building Docker image...
  docker build -t newrelic-infra:latest .
  
  if %BUILD_ONLY%==1 (
    echo Build only mode - exiting.
    exit /b 0
  )

  echo Starting Docker containers...
  call scripts\compose-helper.bat -f docker-compose.yml up -d
  
  echo Waiting for containers to be healthy...
  
  set timeout_seconds=300
  set start_time=%time%
  
  :wait_loop
  for /f %%i in ('docker ps --format "{{.Status}}" ^| findstr /c:"(healthy)" ^| find /c /v ""') do set healthy_count=%%i
  for /f %%i in ('docker ps --format "{{.Names}}" ^| findstr /c:"test-" ^| find /c /v ""') do set container_count=%%i
  
  set current_time=%time%
  
  :: Calculate elapsed time (simplified version)
  set elapsed=30
  
  if !healthy_count! GEQ !container_count! if !container_count! GTR 0 (
    echo All containers are healthy! (!healthy_count!/!container_count!)
    goto containers_ready
  )
  
  if !elapsed! GEQ %timeout_seconds% (
    echo Timeout waiting for containers to be healthy.
    docker ps
    exit /b 1
  )
  
  echo Waiting for containers to be healthy... (!healthy_count!/!container_count!) - !elapsed!/%timeout_seconds% seconds
  timeout /t 5 /nobreak > nul
  goto wait_loop
  
  :containers_ready
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

set TEST_EXIT_CODE=%ERRORLEVEL%

:: Clean up containers if not skipped
if %SKIP_CLEANUP%==0 (
  echo Cleaning up Docker containers...
  call scripts\compose-helper.bat -f docker-compose.yml down -v
)

exit /b %TEST_EXIT_CODE%
