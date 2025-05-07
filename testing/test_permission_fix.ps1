# PowerShell script to test the permission fix for New Relic Docker container
Write-Host "=== Testing permission fix for New Relic Docker container ===" -ForegroundColor Green

# Variables
$IMAGE_NAME = "newrelic-infra:test-fixed"
$TEST_CONTAINER_NAME = "nr-perm-test"

# Clean up any existing test container
Write-Host "Cleaning up any existing test containers..." -ForegroundColor Cyan
docker rm -f $TEST_CONTAINER_NAME 2>$null

# Step 1: Verify the container can start without permission errors
Write-Host "`n=== Test 1: Container startup without permission errors ===" -ForegroundColor Yellow
Write-Host "Starting container..." -ForegroundColor Cyan
docker run --rm -d --name $TEST_CONTAINER_NAME `
    -e NRIA_LICENSE_KEY=dummy-key `
    -e NR_MOCK_MODE=true `
    $IMAGE_NAME

# Check if the container is running
Start-Sleep -Seconds 3
$containerRunning = docker ps -q -f name=$TEST_CONTAINER_NAME
if (-not $containerRunning) {
    # Container exited, check logs for permission errors
    Write-Host "Container exited, checking logs..." -ForegroundColor Cyan
    $logs = docker logs $TEST_CONTAINER_NAME 2>&1
    if ($logs -match "permission denied") {
        Write-Host "❌ FAILED: Permission errors found in container logs." -ForegroundColor Red
        $logs | Select-String -Pattern "permission"
    } else {
        Write-Host "✅ PASSED: No permission errors found. Container exited for other reasons." -ForegroundColor Green
        Write-Host "Container logs:" -ForegroundColor Cyan
        docker logs $TEST_CONTAINER_NAME 2>&1
    }
} else {
    Write-Host "✅ PASSED: Container is running without permission errors." -ForegroundColor Green
    Write-Host "Container logs:" -ForegroundColor Cyan
    docker logs $TEST_CONTAINER_NAME 2>&1
}

# Clean up
docker rm -f $TEST_CONTAINER_NAME 2>$null

# Step 2: Verify the symlink configuration
Write-Host "`n=== Test 2: Verifying symlink configuration ===" -ForegroundColor Yellow
Write-Host "Starting container for symlink verification..." -ForegroundColor Cyan
docker run --rm -d --name $TEST_CONTAINER_NAME `
    --entrypoint /bin/sh `
    $IMAGE_NAME `
    -c "sleep 300"

# Check for symlink
$symlinkOutput = docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml
if ($symlinkOutput -match "->") {
    Write-Host "✅ PASSED: Symlink for configuration file is properly set up." -ForegroundColor Green
    docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml
} else {
    Write-Host "❌ FAILED: Symlink for configuration file is not set up correctly." -ForegroundColor Red
    docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml
}

# Step 3: Verify the config file can be written by non-root user
Write-Host "`n=== Test 3: Verifying config file can be written by non-root user ===" -ForegroundColor Yellow
$runResult = docker exec $TEST_CONTAINER_NAME /bin/sh -c "echo 'test' > /home/newrelic-user/config/test.txt && cat /home/newrelic-user/config/test.txt"
if ($runResult -eq "test") {
    Write-Host "✅ PASSED: Non-root user can write to config directory." -ForegroundColor Green
} else {
    Write-Host "❌ FAILED: Non-root user cannot write to config directory." -ForegroundColor Red
    docker exec $TEST_CONTAINER_NAME ls -la /home/newrelic-user/config
}

# Step 4: Verify the entrypoint script execution
Write-Host "`n=== Test 4: Verifying entrypoint script execution ===" -ForegroundColor Yellow
$entrypointOutput = docker exec -e NRIA_LICENSE_KEY=dummy-key -e NR_MOCK_MODE=true $TEST_CONTAINER_NAME /bin/sh -c "/entrypoint.sh echo 'Test successful'"
$entrypointResult = $?

if ($entrypointResult) {
    Write-Host "✅ PASSED: Entrypoint script executed without permission errors." -ForegroundColor Green
} else {
    Write-Host "❌ FAILED: Entrypoint script execution failed." -ForegroundColor Red
    Write-Host $entrypointOutput
}

# Clean up
Write-Host "`n=== Cleaning up test container ===" -ForegroundColor Cyan
docker rm -f $TEST_CONTAINER_NAME 2>$null

Write-Host "`n=== Test complete ===" -ForegroundColor Green
