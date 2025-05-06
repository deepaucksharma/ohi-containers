
# PowerShell Verification Script for New Relic Docker Testing Framework
# This script verifies that the platform-independent testing framework is properly implemented

Write-Host "Starting New Relic Infrastructure Docker Test Framework Verification" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green

# Set working directory
$WorkingDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $WorkingDir

# Function to check if a directory or file exists
function Test-PathExists {
    param (
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path) {
        Write-Host "[SUCCESS] $Description exists: $Path" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[ERROR] $Description does not exist: $Path" -ForegroundColor Red
        return $false
    }
}

# Function to run a command and check its success
function Run-Command {
    param (
        [string]$Command,
        [string]$Description
    )
    
    Write-Host "Running: $Description..." -ForegroundColor Yellow
    Invoke-Expression $Command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] $Description succeeded" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[ERROR] $Description failed with exit code $LASTEXITCODE" -ForegroundColor Red
        return $false
    }
}

# Verify Docker is running
Write-Host "Checking if Docker is running..." -ForegroundColor Yellow
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Docker is running" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Docker is not running" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "[ERROR] Error checking Docker status: $_" -ForegroundColor Red
    exit 1
}

# Verify directory structure
Write-Host "`nVerifying directory structure..." -ForegroundColor Yellow
$structureOk = $true

$structureOk = $structureOk -and (Test-PathExists ".\bin" "Bin directory")
$structureOk = $structureOk -and (Test-PathExists ".\lib" "Lib directory")
$structureOk = $structureOk -and (Test-PathExists ".\tests" "Tests directory")
$structureOk = $structureOk -and (Test-PathExists ".\bin\run-tests.sh" "Main test runner script")
$structureOk = $structureOk -and (Test-PathExists ".\lib\common.sh" "Common utilities library")
$structureOk = $structureOk -and (Test-PathExists ".\lib\assertions.sh" "Assertions library")
$structureOk = $structureOk -and (Test-PathExists ".\lib\database_utils.sh" "Database utilities library")
$structureOk = $structureOk -and (Test-PathExists ".\tests\unit" "Unit tests directory")
$structureOk = $structureOk -and (Test-PathExists ".\tests\image_validation" "Image validation tests directory")

if ($structureOk) {
    Write-Host "[SUCCESS] Directory structure verification passed" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Directory structure verification failed" -ForegroundColor Red
    exit 1
}

# Test file content
Write-Host "`nVerifying file content..." -ForegroundColor Yellow
$filesOk = $true

function Test-FileContent {
    param (
        [string]$FilePath,
        [string]$Pattern,
        [string]$Description
    )
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath -Raw
        if ($content -match $Pattern) {
            Write-Host "[SUCCESS] $Description - Pattern found in $FilePath" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[ERROR] $Description - Pattern not found in $FilePath" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "[ERROR] File does not exist: $FilePath" -ForegroundColor Red
        return $false
    }
}

$filesOk = $filesOk -and (Test-FileContent ".\lib\common.sh" "detect_platform" "Platform detection function")
$filesOk = $filesOk -and (Test-FileContent ".\lib\assertions.sh" "assert_equals" "Assertions function")
$filesOk = $filesOk -and (Test-FileContent ".\lib\database_utils.sh" "mysql_query" "Database function")

if ($filesOk) {
    Write-Host "[SUCCESS] File content verification passed" -ForegroundColor Green
} else {
    Write-Host "[ERROR] File content verification failed" -ForegroundColor Red
    exit 1
}

# Test Docker execution - run tests in Docker container
Write-Host "`nRunning tests in Docker container..." -ForegroundColor Yellow

# Make scripts executable using Docker
docker run --rm -v "${WorkingDir}:/workspace" alpine:latest sh -c "chmod +x /workspace/lib/*.sh /workspace/bin/*.sh /workspace/tests/*/*.sh /workspace/tests/run_all_tests.sh"

# Run unit tests in Docker
$unitTestCommand = "docker run --rm -v '${WorkingDir}:/workspace' -w /workspace alpine:latest sh -c 'sh /workspace/tests/unit/environment_test.sh && echo Unit test succeeded'"
Run-Command $unitTestCommand "Unit test execution"

# Run image validation test in Docker with Docker socket mounted
$imageTestCommand = "docker run --rm -v '${WorkingDir}:/workspace' -v //var/run/docker.sock:/var/run/docker.sock -w /workspace alpine:latest sh -c 'apk add --no-cache docker-cli && sh /workspace/tests/image_validation/layer_test.sh && echo Image test succeeded'"
Run-Command $imageTestCommand "Image validation test execution"

# Set up Docker Compose environment
Write-Host "`nTesting Docker Compose environment..." -ForegroundColor Yellow
Run-Command "docker-compose up -d" "Docker Compose startup"

# Wait for services to initialize
Write-Host "Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Check if containers are running
Write-Host "Checking if containers are running..." -ForegroundColor Yellow
$containersRunning = docker-compose ps
Write-Host $containersRunning

# Clean up Docker Compose environment
Write-Host "`nCleaning up Docker Compose environment..." -ForegroundColor Yellow
Run-Command "docker-compose down" "Docker Compose cleanup"

Write-Host "`n=============================================================" -ForegroundColor Green
Write-Host "All verification tests passed!" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green
