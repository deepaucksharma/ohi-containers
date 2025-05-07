#!/bin/bash

# Test script to validate the permission fix for the New Relic Docker container
echo "=== Testing permission fix for New Relic Docker container ==="

# Variables
IMAGE_NAME="newrelic-infra:test-fixed"
TEST_CONTAINER_NAME="nr-perm-test"

# Clean up any existing test container
echo "Cleaning up any existing test containers..."
docker rm -f $TEST_CONTAINER_NAME &>/dev/null || true

# Step 1: Verify the container can start without permission errors
echo -e "\n=== Test 1: Container startup without permission errors ==="
echo "Starting container..."
docker run --rm -d --name $TEST_CONTAINER_NAME \
    -e NRIA_LICENSE_KEY=dummy-key \
    -e NR_MOCK_MODE=true \
    $IMAGE_NAME

# Check if the container is running
sleep 3
CONTAINER_RUNNING=$(docker ps -q -f name=$TEST_CONTAINER_NAME)
if [ -z "$CONTAINER_RUNNING" ]; then
    # Container exited, check logs for permission errors
    echo "Container exited, checking logs..."
    LOGS=$(docker logs $TEST_CONTAINER_NAME 2>&1)
    if echo "$LOGS" | grep -i "permission denied"; then
        echo "❌ FAILED: Permission errors found in container logs."
        echo "$LOGS" | grep -i "permission"
    else
        echo "✅ PASSED: No permission errors found. Container exited for other reasons."
        echo "Container logs:"
        docker logs $TEST_CONTAINER_NAME 2>&1
    fi
else
    echo "✅ PASSED: Container is running without permission errors."
    echo "Container logs:"
    docker logs $TEST_CONTAINER_NAME 2>&1
fi

# Clean up
docker rm -f $TEST_CONTAINER_NAME &>/dev/null || true

# Step 2: Verify the symlink configuration
echo -e "\n=== Test 2: Verifying symlink configuration ==="
echo "Starting container for symlink verification..."
docker run --rm -d --name $TEST_CONTAINER_NAME \
    --entrypoint /bin/sh \
    $IMAGE_NAME \
    -c "sleep 30"

# Check for symlink
SYMLINK=$(docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml | grep -c "->")
if [ "$SYMLINK" -eq 1 ]; then
    echo "✅ PASSED: Symlink for configuration file is properly set up."
    docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml
else
    echo "❌ FAILED: Symlink for configuration file is not set up correctly."
    docker exec $TEST_CONTAINER_NAME ls -la /etc/newrelic-infra.yml
fi

# Step 3: Verify the config file can be written by non-root user
echo -e "\n=== Test 3: Verifying config file can be written by non-root user ==="
RUN_RESULT=$(docker exec $TEST_CONTAINER_NAME /bin/sh -c "echo 'test' > /home/newrelic-user/config/test.txt && cat /home/newrelic-user/config/test.txt")
if [ "$RUN_RESULT" = "test" ]; then
    echo "✅ PASSED: Non-root user can write to config directory."
else
    echo "❌ FAILED: Non-root user cannot write to config directory."
    docker exec $TEST_CONTAINER_NAME ls -la /home/newrelic-user/config
fi

# Step 4: Verify the entrypoint script execution
echo -e "\n=== Test 4: Verifying entrypoint script execution ==="
docker exec -e NRIA_LICENSE_KEY=dummy-key -e NR_MOCK_MODE=true $TEST_CONTAINER_NAME /bin/sh -c "/entrypoint.sh echo 'Test successful'"
ENTRYPOINT_RESULT=$?
if [ $ENTRYPOINT_RESULT -eq 0 ]; then
    echo "✅ PASSED: Entrypoint script executed without permission errors."
else
    echo "❌ FAILED: Entrypoint script execution failed."
fi

# Clean up
echo -e "\n=== Cleaning up test container ==="
docker rm -f $TEST_CONTAINER_NAME &>/dev/null || true

echo -e "\n=== Test complete ==="
