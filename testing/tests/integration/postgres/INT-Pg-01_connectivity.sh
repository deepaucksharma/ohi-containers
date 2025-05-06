#!/bin/sh
# INT-Pg-01: PostgreSQL connectivity test
# Agent reaches PostgreSQL fixture and reports PostgresSample
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"
. "$testing_root/lib/database_utils.sh"

# Test variables
TEST_ID="INT-Pg-01"
TEST_NAME="PostgreSQL Connectivity Test"
TEST_DESCRIPTION="Verify that New Relic agent reaches PostgreSQL fixture and reports PostgresSample"

echo "======================================================="
echo "Running Test: $TEST_ID - $TEST_NAME"
echo "======================================================="
echo "$TEST_DESCRIPTION"
echo

# Get docker command
DOCKER_CMD=$(docker_cmd)

# Container names
POSTGRES_CONTAINER=$($DOCKER_CMD ps --filter "name=test-postgres" --format "{{.ID}}")
MOCK_BACKEND_CONTAINER=$($DOCKER_CMD ps --filter "name=mock-newrelic" --format "{{.ID}}")
INFRA_CONTAINER=$($DOCKER_CMD ps --filter "name=test-newrelic-infra" --format "{{.ID}}")

# Validate containers are running
if [ -z "$POSTGRES_CONTAINER" ]; then
  echo "ERROR: PostgreSQL container not found"
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
echo "- PostgreSQL: $POSTGRES_CONTAINER"
echo "- Mock backend: $MOCK_BACKEND_CONTAINER"
echo "- New Relic Infrastructure: $INFRA_CONTAINER"

# Wait for PostgreSQL to be ready
echo "Verifying PostgreSQL is ready..."
wait_for_postgres "postgres" "5432" "postgres" "postgres" "postgres" "30" "$INFRA_CONTAINER"

# Wait for data to be sent to mock backend (30 seconds)
echo "Waiting for data to be sent to mock backend (30 seconds)..."
sleep 30

# Query the mock backend for PostgresSample events
echo "Querying mock backend for PostgresSample events..."
REQUEST_COUNT=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -c "PostgresSample")

assert_greater_than "$REQUEST_COUNT" "0" "Mock backend received PostgresSample events"

# Get a more detailed view of the received events
echo "Detailed view of received events:"
EVENT_DETAILS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -A 10 "PostgresSample" | head -n 20)
echo "$EVENT_DETAILS"

# Verify entity name in the samples
echo "Checking if entity name is correctly reported..."
ENTITY_NAME_MATCH=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                   grep -c "\"entityName\":\"postgres\"")
assert_greater_than "$ENTITY_NAME_MATCH" "0" "Events contain correct entity name"

# Check for authentication errors (401)
echo "Checking agent logs for authentication errors..."
AUTH_ERROR_COUNT=$($DOCKER_CMD exec "$INFRA_CONTAINER" grep -c "401" /var/log/newrelic-infra/newrelic-infra.log || echo "0")
assert_equals "0" "$AUTH_ERROR_COUNT" "No PostgreSQL authentication errors in agent logs"

# Check for connection errors
echo "Checking agent logs for connection errors..."
CONNECTION_ERROR_COUNT=$($DOCKER_CMD exec "$INFRA_CONTAINER" grep -c "Error connecting to PostgreSQL" /var/log/newrelic-infra/newrelic-infra.log || echo "0")
assert_equals "0" "$CONNECTION_ERROR_COUNT" "No PostgreSQL connection errors in agent logs"

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
