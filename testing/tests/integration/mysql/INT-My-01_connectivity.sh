#!/bin/sh
# INT-My-01: MySQL connectivity test
# Agent reaches MySQL fixture and reports MySQLSample
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"
. "$testing_root/lib/database_utils.sh"

# Test variables
TEST_ID="INT-My-01"
TEST_NAME="MySQL Connectivity Test"
TEST_DESCRIPTION="Verify that New Relic agent reaches MySQL fixture and reports MySQLSample"

echo "======================================================="
echo "Running Test: $TEST_ID - $TEST_NAME"
echo "======================================================="
echo "$TEST_DESCRIPTION"
echo

# Get docker command
DOCKER_CMD=$(docker_cmd)

# Container names
MYSQL_CONTAINER=$($DOCKER_CMD ps --filter "name=test-mysql" --format "{{.ID}}")
MOCK_BACKEND_CONTAINER=$($DOCKER_CMD ps --filter "name=mock-newrelic" --format "{{.ID}}")
INFRA_CONTAINER=$($DOCKER_CMD ps --filter "name=test-newrelic-infra" --format "{{.ID}}")

# Validate containers are running
if [ -z "$MYSQL_CONTAINER" ]; then
  echo "ERROR: MySQL container not found"
  exit 1
fi

if [ -z "$MOCK_BACKEND_CONTAINER" ]; then
  echo "ERROR: Mock backend container not found"
  exit 1
fi

if [ -z "$INFRA_CONTAINER" ]; then
  echo "ERROR: New Relic Infrastructure container not found"
  exit 1
fi

echo "Testing with containers:"
echo "- MySQL: $MYSQL_CONTAINER"
echo "- Mock backend: $MOCK_BACKEND_CONTAINER"
echo "- New Relic Infrastructure: $INFRA_CONTAINER"

# Wait for MySQL to be ready
echo "Verifying MySQL is ready..."
wait_for_mysql "mysql" "3306" "newrelic" "test_password" "30" "$INFRA_CONTAINER"

# Wait for data to be sent to mock backend (30 seconds)
echo "Waiting for data to be sent to mock backend (30 seconds)..."
sleep 30

# Query the mock backend for MySQLSample events
echo "Querying mock backend for MySQLSample events..."
REQUEST_COUNT=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -c "MySQLSample")

assert_greater_than "$REQUEST_COUNT" "0" "Mock backend received MySQLSample events"

# Get a more detailed view of the received events
echo "Detailed view of received events:"
EVENT_DETAILS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -A 10 "MySQLSample" | head -n 20)
echo "$EVENT_DETAILS"

# Verify database name in the samples
echo "Checking if database name is correctly reported..."
DB_NAME_MATCH=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -c "\"database\":\"test\"")
assert_greater_than "$DB_NAME_MATCH" "0" "Events contain correct database name"

# Verify agent logs for connection success
echo "Checking agent logs for successful MySQL connection..."
MYSQL_SUCCESS_COUNT=$($DOCKER_CMD exec "$INFRA_CONTAINER" grep -c "Successfully connected to MySQL" /var/log/newrelic-infra/newrelic-infra.log || echo "0")

if [ "$MYSQL_SUCCESS_COUNT" -gt 0 ]; then
  echo "Found MySQL connection success messages in logs"
else
  echo "No explicit MySQL connection success message found in logs, checking for errors instead"
  
  # Check for MySQL connection errors
  MYSQL_ERROR_COUNT=$($DOCKER_CMD exec "$INFRA_CONTAINER" grep -c "Error connecting to MySQL" /var/log/newrelic-infra/newrelic-infra.log || echo "0")
  assert_equals "0" "$MYSQL_ERROR_COUNT" "No MySQL connection errors in agent logs"
fi

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
