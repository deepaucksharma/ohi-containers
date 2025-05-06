#!/bin/sh
# Image layer validation tests
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
. "$project_root/lib/common.sh"
. "$project_root/lib/assertions.sh"

# Get Docker command
docker_command=$(docker_cmd)

# Get image name from docker-compose.yml
get_image_name() {
  # Extract image name from Dockerfile context in docker-compose.yml
  # For this test, we'll use a simple approach - just test the image built by docker-compose
  echo "newrelic-infra:latest"
}

# Test number of layers in image
test_image_layers() {
  log_message "INFO" "Testing number of layers in image"
  
  local image_name=$(get_image_name)
  log_message "INFO" "Checking layers for image: $image_name"
  
  # Check if image exists
  if ! "$docker_command" image inspect "$image_name" >/dev/null 2>&1; then
    log_message "ERROR" "Image does not exist: $image_name"
    log_message "INFO" "Building image"
    cd "$project_root" || exit 1
    "$docker_command" compose build
  fi
  
  # Count number of layers
  local layer_count=$("$docker_command" image inspect "$image_name" --format '{{len .RootFS.Layers}}' 2>/dev/null)
  
  # Check if layer count is reasonable
  # Too many layers can indicate inefficient build
  assert_less_than "$layer_count" 20 "Image has too many layers: $layer_count"
  
  log_message "INFO" "✅ Image has $layer_count layers (under the 20 layer limit)"
}

# Test image size
test_image_size() {
  log_message "INFO" "Testing image size"
  
  local image_name=$(get_image_name)
  log_message "INFO" "Checking size for image: $image_name"
  
  # Get image size in bytes
  local image_size=$("$docker_command" image inspect "$image_name" --format '{{.Size}}' 2>/dev/null)
  
  # Convert to MB for readability
  local size_mb=$((image_size / 1024 / 1024))
  
  # Check if size is reasonable
  # Size limit depends on your requirements
  assert_less_than "$size_mb" 500 "Image size exceeds 500MB: ${size_mb}MB"
  
  log_message "INFO" "✅ Image size is ${size_mb}MB (under the 500MB limit)"
}

# Test image labels
test_image_labels() {
  log_message "INFO" "Testing image labels"
  
  local image_name=$(get_image_name)
  log_message "INFO" "Checking labels for image: $image_name"
  
  # Get image labels
  local labels=$("$docker_command" image inspect "$image_name" --format '{{json .Config.Labels}}' 2>/dev/null)
  
  # Check for required labels
  echo "$labels" | grep -q "maintainer"
  assert_equals 0 $? "Image missing required label: maintainer"
  
  echo "$labels" | grep -q "version"
  assert_equals 0 $? "Image missing required label: version"
  
  log_message "INFO" "✅ Image has all required labels"
}

# Run all tests
run_tests() {
  log_message "INFO" "Running image layer validation tests"
  
  # Run tests
  test_image_layers
  test_image_size
  test_image_labels
  
  # Print test summary
  print_test_summary
}

# Run tests
run_tests
