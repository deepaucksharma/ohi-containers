#!/bin/sh
# Image layer validation test
# Version: 1.0.0

# Source test utilities
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Test variables
TEST_ID="LAYER-01"
TEST_NAME="Image Layer Test"
TEST_DESCRIPTION="Verify Docker image layer count and size"
IMAGE_NAME="newrelic-infra:latest"
MAX_LAYERS=20
MAX_SIZE_MB=500

log_message "INFO" "Running image layer validation tests"

# Check if image exists and build if it doesn't
log_message "INFO" "Testing number of layers in image"
log_message "INFO" "Checking layers for image: $IMAGE_NAME"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  log_message "INFO" "Image does not exist: $IMAGE_NAME. Building now..."
  
  # Move to directory containing Dockerfile (repo root)
  cd "$(dirname "$testing_root")" || exit 1
  
  # Build the image
  if ! docker build -t "$IMAGE_NAME" .; then
    log_message "ERROR" "Failed to build image: $IMAGE_NAME"
    exit 1
  fi
  
  log_message "INFO" "Successfully built image: $IMAGE_NAME"
fi

# Get number of layers
LAYER_COUNT=$(docker image history "$IMAGE_NAME" | grep -v "IMAGE" | wc -l | tr -d ' ')

# Check layer count
assert_less_than "$LAYER_COUNT" "$MAX_LAYERS" "Image has too many layers: $LAYER_COUNT"
log_message "INFO" "✅ Image has $LAYER_COUNT layers (under the $MAX_LAYERS layer limit)"

# Test image size
log_message "INFO" "Testing image size"
log_message "INFO" "Checking size for image: $IMAGE_NAME"

# Get image size in MB
IMAGE_SIZE=$(docker image inspect "$IMAGE_NAME" --format='{{.Size}}' | awk '{print $1/(1024*1024)}' | cut -d '.' -f 1)

# Check image size
assert_less_than "$IMAGE_SIZE" "$MAX_SIZE_MB" "Image size exceeds ${MAX_SIZE_MB}MB: ${IMAGE_SIZE}MB"
log_message "INFO" "✅ Image size is ${IMAGE_SIZE}MB (under the ${MAX_SIZE_MB}MB limit)"

# Test image labels
log_message "INFO" "Testing image labels"
log_message "INFO" "Checking labels for image: $IMAGE_NAME"

# Check for required labels using a more robust approach
MAINTAINER_LABEL=$(docker image inspect "$IMAGE_NAME" --format='{{index .Config.Labels "maintainer"}}' 2>/dev/null || echo "")
VERSION_LABEL=$(docker image inspect "$IMAGE_NAME" --format='{{index .Config.Labels "version"}}' 2>/dev/null || echo "")

# Check if labels exist
if [ -z "$MAINTAINER_LABEL" ]; then
  log_message "ERROR" "Image missing required label: maintainer"
  assert_equals "1" "0" "Image missing required label: maintainer"
else
  log_message "INFO" "Found maintainer label: $MAINTAINER_LABEL"
  assert_equals "1" "1" "Image has maintainer label: $MAINTAINER_LABEL"
fi

if [ -z "$VERSION_LABEL" ]; then
  log_message "ERROR" "Image missing required label: version"
  assert_equals "1" "0" "Image missing required label: version"
else
  log_message "INFO" "Found version label: $VERSION_LABEL"
  assert_equals "1" "1" "Image has version label: $VERSION_LABEL"
fi

log_message "INFO" "✅ Image has all required labels"

# Print test summary
print_test_summary
exit $?
