@echo off
REM Verification script to test all components
echo Starting New Relic Infrastructure Docker Test Suite Verification
echo =============================================================

REM Verify Docker is running
echo Checking if Docker is running...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker is not running. Please start Docker and try again.
  exit /b 1
)
echo [SUCCESS] Docker is running.

REM Verify directory structure
echo Checking directory structure...
dir bin >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: bin directory not found
  exit /b 1
)
dir lib >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: lib directory not found
  exit /b 1
)
dir tests >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: tests directory not found
  exit /b 1
)
echo [SUCCESS] Directory structure is correct.

REM Verify unit tests
echo Running unit tests in Docker container...
docker run --rm -v "%CD%:/workspace" -w /workspace alpine:latest sh -c "chmod +x lib/*.sh tests/unit/*.sh && sh tests/unit/environment_test.sh"
if %ERRORLEVEL% neq 0 (
  echo ERROR: Unit tests failed
  exit /b 1
)
echo [SUCCESS] Unit tests passed.

REM Verify image validation tests
echo Running image validation tests...
docker run --rm -v "%CD%:/workspace" -v /var/run/docker.sock:/var/run/docker.sock -w /workspace alpine:latest sh -c "apk add --no-cache docker-cli && chmod +x lib/*.sh tests/image_validation/*.sh && sh tests/image_validation/layer_test.sh"
if %ERRORLEVEL% neq 0 (
  echo ERROR: Image validation tests failed
  exit /b 1
)
echo [SUCCESS] Image validation tests passed.

REM Verify Docker Compose setup
echo Setting up Docker Compose environment...
docker-compose up -d
if %ERRORLEVEL% neq 0 (
  echo ERROR: Failed to start Docker Compose environment
  exit /b 1
)
echo [SUCCESS] Docker Compose environment started.

echo Waiting for services to initialize...
timeout /t 10 /nobreak > NUL

REM Check if containers are running
echo Checking if containers are running...
docker-compose ps
echo [SUCCESS] Containers are running.

REM Clean up Docker Compose environment
echo Cleaning up Docker Compose environment...
docker-compose down
if %ERRORLEVEL% neq 0 (
  echo ERROR: Failed to clean up Docker Compose environment
  exit /b 1
)
echo [SUCCESS] Docker Compose environment cleaned up.

echo =============================================================
echo All verification tests passed!
echo =============================================================
