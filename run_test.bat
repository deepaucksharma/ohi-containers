@echo off
REM Windows batch script to fix permissions and run tests

echo Fixing directory paths in test scripts...

REM Create a Docker container to run the tests
echo Running tests in Docker container...
docker run --rm ^
  -v %CD%:/app ^
  -v %CD%/testing:/testing ^
  -w /app ^
  alpine:3.18 sh -c "chmod +x testing/tests/image_validation/layer_test.sh && chmod +x testing/lib/*.sh && /app/testing/tests/image_validation/layer_test.sh"

echo Done.
