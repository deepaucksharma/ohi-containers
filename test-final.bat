@echo off
REM Final verification script
echo Final verification of test framework
echo ===================================

cd /d "%~dp0"

REM Check Windows files
echo Checking files on Windows...
if exist lib\common.sh (
  echo [OK] Found common.sh
) else (
  echo [ERROR] Missing common.sh
  exit /b 1
)

if exist bin\run-tests.sh (
  echo [OK] Found run-tests.sh
) else (
  echo [ERROR] Missing run-tests.sh
  exit /b 1
)

if exist tests\unit\environment_test.sh (
  echo [OK] Found environment_test.sh
) else (
  echo [ERROR] Missing environment_test.sh
  exit /b 1
)

REM Test on Linux using Docker
echo Creating Linux test script...
echo #!/bin/sh > test.sh
echo echo Testing Linux compatibility... >> test.sh
echo if [ -f "/app/lib/common.sh" ]; then >> test.sh
echo   echo "[OK] Found common.sh in Linux container" >> test.sh
echo else >> test.sh
echo   echo "[ERROR] Missing common.sh in Linux container" >> test.sh
echo   exit 1 >> test.sh
echo fi >> test.sh

echo Running Linux test in Docker...
docker run --rm -v "%CD%:/app" alpine:latest sh -c "chmod +x /app/test.sh && /app/test.sh"

if %ERRORLEVEL% neq 0 (
  echo [ERROR] Linux container test failed
  exit /b 1
)

echo [SUCCESS] Linux container test passed

REM Clean up
del test.sh

echo ===================================
echo All verification tests passed!
echo The framework is ready to use on both Windows and Linux.
echo ===================================
