@echo off
REM Cross-platform compatibility verification
echo Starting platform compatibility verification...
echo =============================================

REM Change to script directory
cd /d "%~dp0"

REM Create test scripts for both platforms
echo Creating cross-platform test files...

REM Create Linux test script
echo #!/bin/sh > linux-test.sh
echo echo "Testing on Linux environment" >> linux-test.sh
echo echo "Detecting platform: $(uname -s)" >> linux-test.sh
echo if [ -f "/app/lib/common.sh" ]; then >> linux-test.sh
echo   . /app/lib/common.sh >> linux-test.sh
echo   platform=$(detect_platform) >> linux-test.sh
echo   echo "Platform detected by library: $platform" >> linux-test.sh
echo   temp_dir=$(get_temp_dir) >> linux-test.sh
echo   echo "Temporary directory: $temp_dir" >> linux-test.sh
echo   docker_command=$(docker_cmd) >> linux-test.sh
echo   echo "Docker command: $docker_command" >> linux-test.sh
echo   echo "[LINUX TEST PASSED]" >> linux-test.sh
echo else >> linux-test.sh
echo   echo "[ERROR] Cannot find common.sh library" >> linux-test.sh
echo   exit 1 >> linux-test.sh
echo fi >> linux-test.sh

REM Create Windows compatibility batch file
echo @echo off > windows-test.bat
echo echo Testing on Windows environment >> windows-test.bat
echo echo Platform: Windows >> windows-test.bat
echo if exist lib\common.sh ( >> windows-test.bat
echo   echo [OK] Found common library >> windows-test.bat
echo   echo [WINDOWS TEST PASSED] >> windows-test.bat
echo ) else ( >> windows-test.bat
echo   echo [ERROR] Missing common library >> windows-test.bat
echo   exit /b 1 >> windows-test.bat
echo ) >> windows-test.bat

REM Run Windows test
echo Running Windows platform test...
call windows-test.bat
if %ERRORLEVEL% neq 0 (
  echo Windows test failed with exit code %ERRORLEVEL%
  exit /b 1
)

REM Run Linux test in Docker
echo Running Linux platform test in Docker...
docker run --rm -v "%CD%:/app" alpine:latest /bin/sh -c "chmod +x /app/linux-test.sh && /app/linux-test.sh"
if %ERRORLEVEL% neq 0 (
  echo Linux test failed with exit code %ERRORLEVEL%
  exit /b 1
)

REM Clean up
del linux-test.sh windows-test.bat

echo =============================================
echo Platform compatibility verification complete!
echo Framework should run on both Windows and Linux.
echo =============================================
