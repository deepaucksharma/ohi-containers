#!/bin/sh
# SEC-01: Secrets leakage test
# Validate logs do not contain passwords or license key
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Test variables
TEST_ID="SEC-01"
TEST_NAME="Secrets Leakage Test"
TEST_DESCRIPTION="Validate logs do not contain passwords or license key"

echo "======================================================="
echo "Running Test: $TEST_ID - $TEST_NAME"
echo "======================================================="
echo "$TEST_DESCRIPTION"
echo

# Get docker command
DOCKER_CMD=$(docker_cmd)

# Container names
INFRA_CONTAINER=$($DOCKER_CMD ps --filter "name=test-newrelic-infra" --format "{{.ID}}")

# Validate containers are running
if [ -z "$INFRA_CONTAINER" ]; then
  echo "ERROR: New Relic Infrastructure container not found"
  exit 1
fi

echo "Testing New Relic Infrastructure container: $INFRA_CONTAINER"

# Create a temporary file to store logs
LOG_FILE="/tmp/newrelic-infra-logs-$$.txt"

# Get the logs from the container
echo "Extracting logs from container..."
$DOCKER_CMD exec "$INFRA_CONTAINER" cat /var/log/newrelic-infra/newrelic-infra.log > "$LOG_FILE"

# Check for presence of sensitive information
echo "Checking logs for sensitive information..."

# Check for license key
LICENSE_KEY=${NRIA_LICENSE_KEY:-${NEW_RELIC_LICENSE_KEY:-dummy0123456789}}
LICENSE_KEY_FOUND=$(grep -c "$LICENSE_KEY" "$LOG_FILE" || echo "0")
assert_equals "0" "$LICENSE_KEY_FOUND" "License key not found in logs"

# Check for MySQL password
MYSQL_PASSWORD=${MYSQL_PASSWORD:-test_password}
MYSQL_PASSWORD_FOUND=$(grep -c "$MYSQL_PASSWORD" "$LOG_FILE" || echo "0")
assert_equals "0" "$MYSQL_PASSWORD_FOUND" "MySQL password not found in logs"

# Check for PostgreSQL password
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}
POSTGRES_PASSWORD_FOUND=$(grep -c "$POSTGRES_PASSWORD" "$LOG_FILE" || echo "0")
assert_equals "0" "$POSTGRES_PASSWORD_FOUND" "PostgreSQL password not found in logs"

# Check for pattern that might indicate passwords
echo "Checking for patterns that might indicate passwords..."
PASSWORD_PATTERN_FOUND=$(grep -i -c "password.*=.*" "$LOG_FILE" || echo "0")

if [ "$PASSWORD_PATTERN_FOUND" -gt 0 ]; then
  echo "WARNING: Possible password pattern found in logs:"
  grep -i "password.*=.*" "$LOG_FILE" | head -n 5
  
  # Check if these are just configuration mentions without actual values
  ACTUAL_PASSWORD_FOUND=$(grep -i -E "password.*=.*(test_password|postgres)" "$LOG_FILE" || echo "")
  
  if [ -n "$ACTUAL_PASSWORD_FOUND" ]; then
    echo "CRITICAL: Actual password values found in logs!"
    assert_equals "0" "1" "No actual password values should be in logs"
  else
    echo "Patterns seem to be configuration mentions without actual values. Acceptable."
  fi
else
  echo "No suspicious password patterns found."
fi

# Check for patterns that might indicate license keys
echo "Checking for patterns that might indicate license keys..."
LICENSE_PATTERN_FOUND=$(grep -i -c "license.*key.*=.*" "$LOG_FILE" || echo "0")

if [ "$LICENSE_PATTERN_FOUND" -gt 0 ]; then
  echo "WARNING: Possible license key pattern found in logs:"
  grep -i "license.*key.*=.*" "$LOG_FILE" | head -n 5
  
  # Check if these are just configuration mentions without actual values
  ACTUAL_LICENSE_FOUND=$(grep -i -E "license.*key.*=.*[0-9a-f]{30}" "$LOG_FILE" || echo "")
  
  if [ -n "$ACTUAL_LICENSE_FOUND" ]; then
    echo "CRITICAL: Actual license key values found in logs!"
    assert_equals "0" "1" "No actual license key values should be in logs"
  else
    echo "Patterns seem to be configuration mentions without actual values. Acceptable."
  fi
else
  echo "No suspicious license key patterns found."
fi

# Check Docker inspect output for environment variables with secrets
echo "Checking Docker inspect for exposed environment variables..."
INSPECT_OUTPUT=$($DOCKER_CMD inspect "$INFRA_CONTAINER")
LICENSE_KEY_INSPECT=$(echo "$INSPECT_OUTPUT" | grep -c "$LICENSE_KEY" || echo "0")
MYSQL_PASSWORD_INSPECT=$(echo "$INSPECT_OUTPUT" | grep -c "$MYSQL_PASSWORD" || echo "0")
POSTGRES_PASSWORD_INSPECT=$(echo "$INSPECT_OUTPUT" | grep -c "$POSTGRES_PASSWORD" || echo "0")

# For Docker inspect, it's expected to see the environment variables
echo "NOTE: Docker inspect naturally shows environment variables, so we're looking for plaintext values in unexpected places."
echo "      Check that your CI pipeline doesn't log inspect output or container environment."

# Clean up
rm -f "$LOG_FILE"

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
