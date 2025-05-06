@echo off
REM Simple cross-platform test script
echo Testing cross-platform functionality...
echo =========================================

REM Change to script directory
cd /d "%~dp0"

REM Verify Windows functionality
echo Testing Windows functionality...
if exist lib\common.sh (
    echo [OK] Found common library on Windows
) else (
    echo [ERROR] Missing common library on Windows
    exit /b 1
)

REM Test Linux functionality with Docker
echo Testing Linux functionality in Docker...
echo '#!/bin/sh
if [ -f "/app/lib/common.sh" ]; then
  echo "[OK] Found common library in Linux container"
  exit 0
else
  echo "[ERROR] Missing common library in Linux container"
  exit 1
fi' > linux-test.sh

docker run --rm -v "%CD%:/app" alpine:latest sh -c "chmod +x /app/linux-test.sh && /app/linux-test.sh"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Linux test failed
    exit /b 1
)

REM Clean up
del linux-test.sh

echo =========================================
echo Cross-platform tests passed!
echo The framework should run on both Windows and Linux environments.
echo =========================================
