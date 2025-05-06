@echo off
REM Direct verification script for platform-independent testing framework
echo Starting framework verification...
echo =============================================

REM Change to script directory
cd /d "%~dp0"

REM Create Docker container with Alpine to run our tests
echo Creating test container...

REM Create docker-compose-test.yml for verification
echo version: '3.8' > docker-compose-test.yml
echo services: >> docker-compose-test.yml
echo   test-runner: >> docker-compose-test.yml
echo     image: alpine:latest >> docker-compose-test.yml
echo     volumes: >> docker-compose-test.yml
echo       - ./:/app >> docker-compose-test.yml
echo     working_dir: /app >> docker-compose-test.yml
echo     command: /bin/sh -c "echo 'Running framework verification...' && chmod +x /app/lib/*.sh /app/bin/*.sh /app/tests/unit/*.sh && ls -la /app/lib /app/bin /app/tests/unit && /app/lib/common.sh && /app/tests/unit/environment_test.sh" >> docker-compose-test.yml

echo Running verification tests...
docker-compose -f docker-compose-test.yml up

echo Cleaning up...
docker-compose -f docker-compose-test.yml down
del docker-compose-test.yml

echo =============================================
echo Verification complete!
