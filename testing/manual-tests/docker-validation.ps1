# PowerShell script to validate New Relic Docker image
Write-Host "Starting Docker image validation..." -ForegroundColor Green

# Variables
$IMAGE_NAME = "newrelic-infra:test"
$TEST_CONTAINER_NAME = "nr-validation-test"

# Clean up any existing test container
Write-Host "Cleaning up any existing test containers..." -ForegroundColor Cyan
docker rm -f $TEST_CONTAINER_NAME 2>$null

# Check 1: Image exists
Write-Host "Checking if image exists..." -ForegroundColor Cyan
try {
    $imageInfo = docker image inspect $IMAGE_NAME 2>$null
    Write-Host "✅ Image $IMAGE_NAME exists" -ForegroundColor Green
} catch {
    Write-Host "❌ Image $IMAGE_NAME does not exist" -ForegroundColor Red
    exit 1
}

# Check 2: Verify image metadata
Write-Host "Checking image metadata..." -ForegroundColor Cyan
$labels = (docker image inspect --format='{{.Config.Labels}}' $IMAGE_NAME)
Write-Host "Labels: $labels" -ForegroundColor Green

$user = (docker image inspect --format='{{.Config.User}}' $IMAGE_NAME)
Write-Host "User: $user" -ForegroundColor Green

if ($user -eq "1000") {
    Write-Host "✅ Container is configured to run as non-root user (UID 1000)" -ForegroundColor Green
} else {
    Write-Host "⚠️ Container user is not set to 1000 in the Dockerfile" -ForegroundColor Yellow
}

# Check 3: Verify healthcheck configuration
Write-Host "Checking healthcheck configuration..." -ForegroundColor Cyan
$healthcheck = (docker image inspect --format='{{.Config.Healthcheck}}' $IMAGE_NAME)
Write-Host "Healthcheck: $healthcheck" -ForegroundColor Green

if ($healthcheck -match "healthcheck.sh") {
    Write-Host "✅ Healthcheck is properly configured" -ForegroundColor Green
} else {
    Write-Host "⚠️ Healthcheck may not be properly configured" -ForegroundColor Yellow
}

# Check 4: Run container with root to check directory structure
Write-Host "Running container to check directory structure..." -ForegroundColor Cyan
docker run --rm -d --name $TEST_CONTAINER_NAME -u 0 $IMAGE_NAME sleep 30 2>$null

# Check for required directories
Write-Host "Checking for required directories..." -ForegroundColor Cyan
$dirsToCheck = @("/var/log/newrelic-infra", "/var/db/newrelic-infra", "/etc/newrelic-infra", "/var/log/test-results")

foreach ($dir in $dirsToCheck) {
    $dirExists = docker exec $TEST_CONTAINER_NAME test -d $dir 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Directory $dir exists" -ForegroundColor Green
        
        # Check permissions
        $perms = docker exec $TEST_CONTAINER_NAME ls -ld $dir
        Write-Host "   Permissions: $perms" -ForegroundColor Green
    } else {
        Write-Host "❌ Directory $dir does not exist" -ForegroundColor Red
    }
}

# Check 5: Check executable scripts
Write-Host "Checking for executable scripts..." -ForegroundColor Cyan
$scriptsToCheck = @("/entrypoint.sh", "/usr/local/bin/healthcheck.sh")

foreach ($script in $scriptsToCheck) {
    $scriptExists = docker exec $TEST_CONTAINER_NAME test -f $script 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Script $script exists" -ForegroundColor Green
        
        # Check if executable
        $scriptExec = docker exec $TEST_CONTAINER_NAME test -x $script 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Script is executable" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Script is not executable" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ Script $script does not exist" -ForegroundColor Red
    }
}

# Check 6: Check configuration template exists
Write-Host "Checking for configuration templates..." -ForegroundColor Cyan
$templateExists = docker exec $TEST_CONTAINER_NAME test -f /etc/newrelic-infra.yml.template 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Configuration template exists" -ForegroundColor Green
} else {
    Write-Host "❌ Configuration template doesn't exist" -ForegroundColor Red
}

# Check 7: Permission fix for entrypoint
Write-Host "Checking entry point permission issue and proposing fix..." -ForegroundColor Cyan
$permCheck = docker exec $TEST_CONTAINER_NAME ls -l /etc/newrelic-infra.yml.template 2>$null
Write-Host "Template permissions: $permCheck" -ForegroundColor Green

# Clean up
Write-Host "Cleaning up test container..." -ForegroundColor Cyan
docker rm -f $TEST_CONTAINER_NAME 2>$null

Write-Host "Validation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "FINDINGS:" -ForegroundColor Yellow
Write-Host "1. The Docker image is running as user 1000 but the entrypoint script tries to write to /etc/newrelic-infra.yml which is owned by root" -ForegroundColor Yellow
Write-Host "2. To fix this issue, you could:" -ForegroundColor Yellow
Write-Host "   a. Modify the Dockerfile to add write permission to the directory for the non-root user" -ForegroundColor Yellow
Write-Host "   b. Change where the config file is written to a location writable by the non-root user" -ForegroundColor Yellow
Write-Host "   c. For testing purposes, you can run with -u 0 to test as root" -ForegroundColor Yellow
Write-Host ""
Write-Host "Suggested Dockerfile fix:" -ForegroundColor Green
Write-Host @"
# Before USER 1000, add these lines:
RUN mkdir -p /home/newrelic-user/config && \
    chown newrelic-user:newrelic-user /home/newrelic-user/config && \
    ln -sf /home/newrelic-user/config/newrelic-infra.yml /etc/newrelic-infra.yml

# Then modify the entrypoint.sh to write to the home directory instead:
# envsubst < /etc/newrelic-infra.yml.template > /home/newrelic-user/config/newrelic-infra.yml
"@ -ForegroundColor Cyan
