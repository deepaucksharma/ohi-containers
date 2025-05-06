@echo off
REM Single test runner using Docker
echo Running test with Docker container...

REM Use absolute paths and create a simplified test
cd /d "%~dp0"

REM Create a simple test script
echo #!/bin/sh > simple-test.sh
echo echo "Testing Docker environment..." >> simple-test.sh
echo echo "Directory contents:" >> simple-test.sh
echo ls -la >> simple-test.sh
echo echo "Lib directory:" >> simple-test.sh
echo ls -la lib >> simple-test.sh
echo echo "Tests directory:" >> simple-test.sh
echo ls -la tests >> simple-test.sh
echo echo "Running a simple validation..." >> simple-test.sh
echo if [ -f "lib/common.sh" ]; then >> simple-test.sh
echo   echo "SUCCESS: Found common.sh library" >> simple-test.sh
echo else >> simple-test.sh
echo   echo "ERROR: Missing common.sh library" >> simple-test.sh
echo   exit 1 >> simple-test.sh
echo fi >> simple-test.sh
echo echo "SUCCESS: Test completed" >> simple-test.sh

REM Run the test in Docker
docker run --rm -v "%CD%:/app" alpine:latest sh -c "cd /app && chmod +x simple-test.sh && ./simple-test.sh"

REM Clean up
del simple-test.sh

echo Test execution complete.
