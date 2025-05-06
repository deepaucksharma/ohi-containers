#!/bin/sh
# Environment cleanup script for test execution
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/.." && pwd)

# Source common utilities
. "$project_root/lib/common.sh"

# Log the beginning of cleanup
log_message "INFO" "Cleaning up test environment"

# Detect platform
platform=$(detect_platform)
log_message "INFO" "Platform detected: $platform"

# Step 1: Stop Docker Compose environment
log_message "INFO" "Stopping Docker Compose environment"
docker_cmd_name=$(docker_cmd)
cd "$project_root" || exit 1

# Stop containers and remove them
"$docker_cmd_name" compose down

# Step 2: Archive test results if they exist
if dir_exists "$project_root/tests/output"; then
  log_message "INFO" "Archiving test results"
  
  # Create archives directory if it doesn't exist
  mkdir -p "$project_root/tests/archives"
  
  # Create archive timestamp
  timestamp=$(date +%Y%m%d%H%M%S)
  archive_name="test-results-$timestamp.tar"
  
  # Archive test results
  cd "$project_root/tests" || exit 1
  if command -v tar >/dev/null 2>&1; then
    tar -cf "archives/$archive_name" output
    log_message "INFO" "✅ Test results archived to tests/archives/$archive_name"
  else
    log_message "WARN" "tar command not found, skipping archiving"
  fi
  
  # Optionally compress archive if gzip is available
  if command -v gzip >/dev/null 2>&1; then
    gzip "archives/$archive_name"
    log_message "INFO" "✅ Archive compressed to archives/${archive_name}.gz"
  fi
fi

# Step 3: Clean up temporary files
log_message "INFO" "Removing temporary files"

# Temp directory for platform
temp_dir=$(get_temp_dir)

# Remove temporary files specific to these tests
find "$temp_dir" -name "newrelic-docker-test-*" -type f -exec rm -f {} \; 2>/dev/null
log_message "INFO" "✅ Temporary files removed"

# Step 4: Verify cleanup was successful
log_message "INFO" "Verifying cleanup"

# Check if any containers from our tests are still running
remaining_containers=$("$docker_cmd_name" ps -a --filter "name=test-" --format "{{.Names}}")
if [ -n "$remaining_containers" ]; then
  log_message "WARN" "Some test containers are still present:"
  echo "$remaining_containers"
  
  # Force remove remaining containers
  log_message "INFO" "Forcibly removing remaining containers"
  for container in $remaining_containers; do
    "$docker_cmd_name" rm -f "$container" >/dev/null 2>&1
  done
fi

log_message "INFO" "✅ Environment cleanup completed successfully"
exit 0
