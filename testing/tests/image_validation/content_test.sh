#!/bin/sh
# Image content validation tests
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Get Docker command
docker_command=$(docker_cmd)

# Get image name from docker-compose.yml
get_image_name() {
  # Extract image name from Dockerfile context in docker-compose.yml
  # For this test, we'll use a simple approach - just test the image built by docker-compose
  echo "newrelic-infra:latest"
}

# Test required files exist in image
test_required_files() {
  log_message "INFO" "Testing required files in image"
  
  local image_name=$(get_image_name)
  local container_name="test-image-content-$$"
  
  # Start a container from the image
  "$docker_command" run --name "$container_name" -d "$image_name" sleep 60
  
  # Check required files
  log_message "INFO" "Checking for required files"
  
  # Check for newrelic-infra binary
  "$docker_command" exec "$container_name" test -f /usr/bin/newrelic-infra
  assert_equals 0 $? "Missing required file: /usr/bin/newrelic-infra"
  
  # Check for config directory
  "$docker_command" exec "$container_name" test -d /etc/newrelic-infra
  assert_equals 0 $? "Missing required directory: /etc/newrelic-infra"
  
  # Check for integrations directory
  "$docker_command" exec "$container_name" test -d /etc/newrelic-infra/integrations.d
  assert_equals 0 $? "Missing required directory: /etc/newrelic-infra/integrations.d"
  
  # Check for healthcheck script
  "$docker_command" exec "$container_name" test -f /usr/local/bin/healthcheck.sh
  assert_equals 0 $? "Missing required file: /usr/local/bin/healthcheck.sh"
  
  # Clean up container
  "$docker_command" rm -f "$container_name" >/dev/null 2>&1
  
  log_message "INFO" "✅ All required files exist in image"
}

# Test file permissions
test_file_permissions() {
  log_message "INFO" "Testing file permissions in image"
  
  local image_name=$(get_image_name)
  local container_name="test-image-perms-$$"
  
  # Start a container from the image
  "$docker_command" run --name "$container_name" -d "$image_name" sleep 60
  
  # Check permissions for important files
  log_message "INFO" "Checking permissions for important files"
  
  # Check executable permission for newrelic-infra binary
  "$docker_command" exec "$container_name" test -x /usr/bin/newrelic-infra
  assert_equals 0 $? "Incorrect permissions for /usr/bin/newrelic-infra (should be executable)"
  
  # Check executable permission for healthcheck script
  "$docker_command" exec "$container_name" test -x /usr/local/bin/healthcheck.sh
  assert_equals 0 $? "Incorrect permissions for /usr/local/bin/healthcheck.sh (should be executable)"
  
  # Check write permission for log directory
  "$docker_command" exec "$container_name" test -w /var/log/newrelic-infra
  assert_equals 0 $? "Incorrect permissions for /var/log/newrelic-infra (should be writable)"
  
  # Clean up container
  "$docker_command" rm -f "$container_name" >/dev/null 2>&1
  
  log_message "INFO" "✅ All file permissions are correct"
}

# Test environment variables
test_environment_variables() {
  log_message "INFO" "Testing environment variables in image"
  
  local image_name=$(get_image_name)
  local container_name="test-image-env-$$"
  
  # Start a container from the image with test environment variables
  "$docker_command" run --name "$container_name" -d \
    -e "NRIA_LICENSE_KEY=test_license" \
    -e "NEW_RELIC_API_URL=http://test.newrelic.com" \
    "$image_name" sleep 60
  
  # Check environment variables are properly set
  log_message "INFO" "Checking environment variables"
  
  # Check license key
  local license_key=$("$docker_command" exec "$container_name" sh -c 'echo $NRIA_LICENSE_KEY')
  assert_equals "test_license" "$license_key" "Incorrect environment variable: NRIA_LICENSE_KEY"
  
  # Check API URL
  local api_url=$("$docker_command" exec "$container_name" sh -c 'echo $NEW_RELIC_API_URL')
  assert_equals "http://test.newrelic.com" "$api_url" "Incorrect environment variable: NEW_RELIC_API_URL"
  
  # Clean up container
  "$docker_command" rm -f "$container_name" >/dev/null 2>&1
  
  log_message "INFO" "✅ All environment variables are correctly set"
}

# Run all tests
run_tests() {
  log_message "INFO" "Running image content validation tests"
  
  # Run tests
  test_required_files
  test_file_permissions
  test_environment_variables
  
  # Print test summary
  print_test_summary
}

# Run tests
run_tests
