#!/bin/sh
# E2E-02: Config render test
# Verify `entrypoint.sh` renders `newrelic-infra.yml` with secrets
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Test variables
TEST_ID="E2E-02"
TEST_NAME="Config Render Test"
TEST_DESCRIPTION="Verify that entrypoint.sh correctly renders newrelic-infra.yml with secrets from environment"

echo "======================================================="
echo "Running Test: $TEST_ID - $TEST_NAME"
echo "======================================================="
echo "$TEST_DESCRIPTION"
echo

# Get docker command and running newrelic-infra container ID
DOCKER_CMD=$(docker_cmd)
INFRA_CONTAINER=$($DOCKER_CMD ps --filter "name=test-newrelic-infra" --format "{{.ID}}")

if [ -z "$INFRA_CONTAINER" ]; then
  echo "ERROR: New Relic Infrastructure container not found"
  exit 1
fi

echo "Testing newrelic-infra container: $INFRA_CONTAINER"

# 1. Check if the file exists
echo "Checking if rendered config file exists..."
FILE_EXISTS=$($DOCKER_CMD exec "$INFRA_CONTAINER" test -f /etc/newrelic-infra.yml && echo "yes" || echo "no")
assert_equals "yes" "$FILE_EXISTS" "Rendered config file /etc/newrelic-infra.yml exists"

# 2. Check if the file contains the license key
echo "Checking if rendered config contains license key..."
LICENSE_CHECK=$($DOCKER_CMD exec "$INFRA_CONTAINER" cat /etc/newrelic-infra.yml | grep -c "license_key:")
assert_greater_than "$LICENSE_CHECK" "0" "Config contains license_key entry"

# 3. Check if environment variables were expanded
echo "Checking if environment variables were expanded properly..."
ORIGINAL_TEMPLATE=$($DOCKER_CMD exec "$INFRA_CONTAINER" cat /etc/newrelic-infra.yml.template)
RENDERED_CONFIG=$($DOCKER_CMD exec "$INFRA_CONTAINER" cat /etc/newrelic-infra.yml)

# Verify no unexpanded ${VARIABLE} placeholders remain in the rendered file
UNEXPANDED_VARS=$($DOCKER_CMD exec "$INFRA_CONTAINER" grep -c "\${.*}" /etc/newrelic-infra.yml || echo "0")
assert_equals "0" "$UNEXPANDED_VARS" "No unexpanded variables in rendered config"

# 4. Test that container fails to start if license key is missing
echo "Testing container behavior with missing license key..."

# Create a test container with missing license key
TEMP_CONTAINER_NAME="temp-nri-test-$$"
TEMP_CONTAINER=$($DOCKER_CMD run -d --name "$TEMP_CONTAINER_NAME" \
  --env NRIA_LICENSE_KEY="" \
  --entrypoint "/bin/sh" \
  "$($DOCKER_CMD inspect --format='{{.Config.Image}}' "$INFRA_CONTAINER")" \
  -c "sleep 1 && /entrypoint.sh && echo 'Should not reach here'")

# Wait a moment for the container to run
sleep 2

# Check if the container is still running
CONTAINER_STATUS=$($DOCKER_CMD ps --filter "name=$TEMP_CONTAINER_NAME" --filter "status=running" --format "{{.ID}}" | wc -l)
EXIT_CODE=$($DOCKER_CMD inspect "$TEMP_CONTAINER_NAME" --format='{{.State.ExitCode}}')

# The container should have exited with non-zero status
assert_equals "0" "$CONTAINER_STATUS" "Container with missing license key should not be running"
assert_not_equals "0" "$EXIT_CODE" "Container should exit with non-zero code when license key is missing"

# Clean up
$DOCKER_CMD rm -f "$TEMP_CONTAINER_NAME" >/dev/null 2>&1

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
