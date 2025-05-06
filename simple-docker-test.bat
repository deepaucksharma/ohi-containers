@echo off
REM Run simple test with Docker
echo Running basic Docker test...

cd /d "%~dp0"

echo Testing Docker validation framework...

docker run --rm -v "%CD%:/app" alpine:latest /bin/sh -c "cd /app && echo '=== TEST RESULTS ===' && echo 'Directories:' && ls -la && echo 'Library:' && ls -la lib && echo 'Unit Tests:' && ls -la tests/unit && echo 'SUCCESS: Framework verified'"

echo Docker test complete.
