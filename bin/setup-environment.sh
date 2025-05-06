#!/bin/sh
# Environment setup script for test execution
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/.." && pwd)

# Source common utilities
. "$project_root/lib/common.sh"

# Log the beginning of setup
log_message "INFO" "Setting up test environment"

# Detect platform
platform=$(detect_platform)
log_message "INFO" "Platform detected: $platform"

# Step 1: Ensure Docker is running
log_message "INFO" "Checking Docker status"
docker_cmd_name=$(docker_cmd)

if ! "$docker_cmd_name" info >/dev/null 2>&1; then
  log_message "ERROR" "Docker is not running. Please start Docker and try again."
  exit 1
fi
log_message "INFO" "✅ Docker is running"

# Step 2: Create necessary directories
log_message "INFO" "Creating output directory"
mkdir -p "$project_root/tests/output"

# Step 3: Check if environment file exists, create if not
if ! file_exists "$project_root/.env"; then
  log_message "INFO" "Creating default .env file"
  cat > "$project_root/.env" << EOF
# Environment variables for New Relic Infrastructure Docker tests
MYSQL_ROOT_PASSWORD=root
MYSQL_USER=newrelic
MYSQL_PASSWORD=test_password
MYSQL_DATABASE=test

POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres

NEW_RELIC_LICENSE_KEY=0123456789012345678901234567890123456789
NEW_RELIC_API_URL=http://mockbackend:8080/v1
EOF
fi

# Step 4: Prepare Docker Compose environment
log_message "INFO" "Starting Docker Compose environment"
cd "$project_root" || exit 1

# Build images if needed
log_message "INFO" "Building Docker images"
"$docker_cmd_name" compose build

# Start containers
log_message "INFO" "Starting containers"
"$docker_cmd_name" compose up -d

# Step 5: Wait for containers to be healthy
log_message "INFO" "Waiting for containers to be ready"
timeout=60
elapsed=0
interval=5

while [ $elapsed -lt $timeout ]; do
  if "$docker_cmd_name" compose ps | grep -q "health: starting"; then
    log_message "INFO" "Containers still initializing... ($elapsed/$timeout seconds)"
    sleep $interval
    elapsed=$((elapsed + interval))
  else
    log_message "INFO" "✅ All containers are ready"
    break
  fi
done

if [ $elapsed -ge $timeout ]; then
  log_message "WARN" "Timed out waiting for containers to be healthy"
  log_message "INFO" "Container status:"
  "$docker_cmd_name" compose ps
fi

# Step 6: Final setup verification
log_message "INFO" "Verifying setup"
if "$docker_cmd_name" compose ps | grep -q "Exit"; then
  log_message "ERROR" "Some containers have exited unexpectedly"
  "$docker_cmd_name" compose ps
  exit 1
fi

log_message "INFO" "✅ Environment setup completed successfully"
exit 0
