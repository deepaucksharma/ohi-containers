#!/bin/bash
# Simple validation script for New Relic Infrastructure Docker image

set -e
echo "Starting Docker image validation..."

# Variables
IMAGE_NAME="newrelic-infra:test"
TEST_CONTAINER_NAME="nr-validation-test"

# Clean up any existing test container
echo "Cleaning up any existing test containers..."
docker rm -f $TEST_CONTAINER_NAME 2>/dev/null || true

# Check 1: Image exists
echo "Checking if image exists..."
if docker image inspect $IMAGE_NAME >/dev/null 2>&1; then
  echo "✅ Image $IMAGE_NAME exists"
else
  echo "❌ Image $IMAGE_NAME does not exist"
  exit 1
fi

# Check 2: Verify image metadata
echo "Checking image metadata..."
MAINTAINER=$(docker image inspect --format='{{index .Config.Labels "maintainer"}}' $IMAGE_NAME)
if [[ -n "$MAINTAINER" ]]; then
  echo "✅ Maintainer label exists: $MAINTAINER"
else
  echo "⚠️ No maintainer label found"
fi

# Check 3: Run container to verify entrypoint and non-root user
echo "Running container as root to verify entrypoint..."
docker run --rm -d --name $TEST_CONTAINER_NAME -u 0 \
  -e NRIA_LICENSE_KEY=test-key \
  -e NR_MOCK_MODE=true \
  $IMAGE_NAME

# Let it start up
sleep 3

# Check user configuration
echo "Verifying user configuration in Dockerfile..."
USER_ID=$(docker inspect --format='{{.Config.User}}' $IMAGE_NAME)
if [[ "$USER_ID" == "1000" ]]; then
  echo "✅ Container is configured to run as non-root user (UID 1000)"
else
  echo "⚠️ Container user is not set to 1000 in the Dockerfile"
fi

# Clean up the test container
docker rm -f $TEST_CONTAINER_NAME 2>/dev/null || true

# Check 4: Verify directory structure and permissions
echo "Running container to verify directory structure and permissions..."
docker run --rm -d --name $TEST_CONTAINER_NAME \
  -u 0 \
  $IMAGE_NAME \
  sh -c "sleep 30"

# Check for required directories
echo "Checking for required directories and permissions..."
DIRS_TO_CHECK=("/var/log/newrelic-infra" "/var/db/newrelic-infra" "/etc/newrelic-infra")

for DIR in "${DIRS_TO_CHECK[@]}"; do
  if docker exec $TEST_CONTAINER_NAME test -d "$DIR"; then
    echo "✅ Directory $DIR exists"
    
    # Check permissions
    PERMS=$(docker exec $TEST_CONTAINER_NAME ls -ld "$DIR" | awk '{print $1}')
    echo "   Permissions: $PERMS"
  else
    echo "❌ Directory $DIR does not exist"
  fi
done

# Check 5: Verify script permissions
echo "Checking for executable scripts..."
SCRIPTS_TO_CHECK=("/entrypoint.sh" "/usr/local/bin/healthcheck.sh")

for SCRIPT in "${SCRIPTS_TO_CHECK[@]}"; do
  if docker exec $TEST_CONTAINER_NAME test -f "$SCRIPT"; then
    echo "✅ Script $SCRIPT exists"
    
    # Check if executable
    if docker exec $TEST_CONTAINER_NAME test -x "$SCRIPT"; then
      echo "   Script is executable"
    else
      echo "❌ Script is not executable"
    fi
  else
    echo "❌ Script $SCRIPT does not exist"
  fi
done

# Clean up
echo "Cleaning up test container..."
docker rm -f $TEST_CONTAINER_NAME

echo "Validation complete!"
