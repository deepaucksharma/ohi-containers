#!/usr/bin/env bats
# Image layer validation test for Bats
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"

# Test variables
IMAGE_NAME="newrelic-infra:latest"
MAX_LAYERS=20
MAX_SIZE_MB=500

# Setup function runs before each test
setup() {
  # Check if image exists and build if it doesn't
  if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    log_message "INFO" "Image does not exist: $IMAGE_NAME. Building now..."
    
    # Move to directory containing Dockerfile (repo root)
    cd "$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/.." || return 1
    
    # Build the image
    docker build -t "$IMAGE_NAME" .
    
    log_message "INFO" "Successfully built image: $IMAGE_NAME"
  fi
}

@test "Image should have an acceptable number of layers" {
  # Get number of layers
  run bash -c "docker image history $IMAGE_NAME | grep -v 'IMAGE' | wc -l | tr -d ' '"
  
  # Check layer count
  assert_success
  assert_less_than "$output" "$MAX_LAYERS" "Image has too many layers: $output"
  
  echo "✅ Image has $output layers (under the $MAX_LAYERS layer limit)"
}

@test "Image should have an acceptable size" {
  # Get image size in MB
  run bash -c "docker image inspect $IMAGE_NAME --format='{{.Size}}' | awk '{print \$1/(1024*1024)}' | cut -d '.' -f 1"
  
  # Check image size
  assert_success
  assert_less_than "$output" "$MAX_SIZE_MB" "Image size exceeds ${MAX_SIZE_MB}MB: ${output}MB"
  
  echo "✅ Image size is ${output}MB (under the ${MAX_SIZE_MB}MB limit)"
}

@test "Image should have required maintainer label" {
  # Check for maintainer label
  run bash -c "docker image inspect $IMAGE_NAME --format='{{index .Config.Labels \"maintainer\"}}' 2>/dev/null || echo ''"
  
  # Verify label exists
  assert_success
  [ -n "$output" ]
  
  echo "✅ Found maintainer label: $output"
}

@test "Image should have required version label" {
  # Check for version label
  run bash -c "docker image inspect $IMAGE_NAME --format='{{index .Config.Labels \"version\"}}' 2>/dev/null || echo ''"
  
  # Verify label exists
  assert_success
  [ -n "$output" ]
  
  echo "✅ Found version label: $output"
}
