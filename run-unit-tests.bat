@echo off
REM Direct unit test runner
echo Starting unit tests...

REM Change to the script directory
cd /d "%~dp0"

REM Verify files exist
echo Checking if test files exist...
if not exist "tests\unit\config_parser_test.sh" (
  echo ERROR: Test file not found: tests\unit\config_parser_test.sh
  exit /b 1
)

if not exist "tests\unit\environment_test.sh" (
  echo ERROR: Test file not found: tests\unit\environment_test.sh
  exit /b 1
)

echo Checking if utilities exist...
if not exist "lib\common.sh" (
  echo ERROR: Utility file not found: lib\common.sh
  exit /b 1
)

if not exist "lib\assertions.sh" (
  echo ERROR: Utility file not found: lib\assertions.sh
  exit /b 1
)

REM Run Docker command to verify it works
echo Verifying Docker is running...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
  echo ERROR: Docker is not running. Please start Docker and try again.
  exit /b 1
)

echo Docker is running. Creating test container...

REM Create a test container to run the scripts
docker run --rm -it -v "%CD%:/workspace" alpine:latest sh -c "cd /workspace && chmod +x tests/unit/*.sh && sh tests/unit/environment_test.sh && sh tests/unit/config_parser_test.sh"

echo Tests completed.
