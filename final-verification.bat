@echo off
REM Final verification script for testing framework
echo Starting final framework verification...
echo =============================================

REM Change to script directory
cd /d "%~dp0"

REM Verify file structure
echo Verifying file structure...
if exist bin\run-tests.sh (
    echo [OK] Found bin\run-tests.sh
) else (
    echo [ERROR] Missing bin\run-tests.sh
    exit /b 1
)

if exist lib\common.sh (
    echo [OK] Found lib\common.sh
) else (
    echo [ERROR] Missing lib\common.sh
    exit /b 1
)

if exist lib\assertions.sh (
    echo [OK] Found lib\assertions.sh
) else (
    echo [ERROR] Missing lib\assertions.sh
    exit /b 1
)

if exist tests\unit\environment_test.sh (
    echo [OK] Found tests\unit\environment_test.sh
) else (
    echo [ERROR] Missing tests\unit\environment_test.sh
    exit /b 1
)

if exist tests\image_validation\layer_test.sh (
    echo [OK] Found tests\image_validation\layer_test.sh
) else (
    echo [ERROR] Missing tests\image_validation\layer_test.sh
    exit /b 1
)

echo All required files are present.

REM Run a simple shell script test in Docker
echo Creating test file...
echo #!/bin/sh > test-verify.sh
echo echo "Platform: $(uname -s)" >> test-verify.sh
echo if [ -f "/app/lib/common.sh" ]; then >> test-verify.sh
echo     echo "[OK] Found common.sh" >> test-verify.sh
echo else >> test-verify.sh
echo     echo "[ERROR] Missing common.sh" >> test-verify.sh
echo     exit 1 >> test-verify.sh
echo fi >> test-verify.sh
echo echo "Verification successful!" >> test-verify.sh

echo Running test in Docker...
docker run --rm -v "%CD%:/app" alpine:latest /bin/sh -c "chmod +x /app/test-verify.sh && /app/test-verify.sh"

REM Clean up
del test-verify.sh

echo =============================================
echo Framework structure verification complete!
echo.
echo To run actual tests when Docker is ready, use:
echo   run-tests.bat --category unit --verbose
echo   run-tests.bat --category image --verbose
echo   run-tests.bat --verbose (for all tests)
echo =============================================
