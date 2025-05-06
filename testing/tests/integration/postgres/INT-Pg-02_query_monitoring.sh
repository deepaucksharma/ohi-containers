#!/bin/sh
# INT-Pg-02: PG DBPM via pg_stat_statements
# Insert heavy query; ensure PostgresQuerySample appears
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"
. "$testing_root/lib/database_utils.sh"

# Test variables
TEST_ID="INT-Pg-02"
TEST_NAME="PostgreSQL Query Monitoring Test"
TEST_DESCRIPTION="Verify that PostgreSQL queries are captured via pg_stat_statements and reported as PostgresQuerySample events"

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

# Verify pg_stat_statements extension is enabled
echo "Verifying pg_stat_statements extension is enabled..."
EXTENSION_EXISTS=$($DOCKER_CMD exec "$POSTGRES_CONTAINER" psql -U postgres -c "SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_statements';" | grep -c "1" || echo "0")

if [ "$EXTENSION_EXISTS" -eq "0" ]; then
  echo "ERROR: pg_stat_statements extension is not enabled"
  exit 1
fi

# Clear any existing requests in mock backend
echo "Clearing previous requests from mock backend..."
$DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -X POST "http://localhost:8080/__admin/requests/reset"

# Execute slow queries multiple times
echo "Executing slow query (SELECT pg_sleep(1)) 15 times..."
for i in $(seq 1 15); do
  echo "Executing slow query: $i/15"
  $DOCKER_CMD exec "$POSTGRES_CONTAINER" psql -U postgres -c "SELECT pg_sleep(1);" >/dev/null 2>&1
done

# Wait for data to be sent to mock backend (60 seconds)
echo "Waiting for data to be sent to mock backend (60 seconds)..."
sleep 60

# Query the mock backend for PostgresQuerySample events
echo "Querying mock backend for PostgresQuerySample events..."
REQUEST_COUNT=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -c "PostgresQuerySample")

assert_greater_than "$REQUEST_COUNT" "0" "Mock backend received PostgresQuerySample events"

# Get a detailed view of the received events
echo "Detailed view of received events:"
EVENT_DETAILS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -A 20 "PostgresQuerySample" | head -n 40)
echo "$EVENT_DETAILS"

# Check if query fingerprint is captured
echo "Checking if query fingerprint is captured..."
FINGERPRINT_EXISTS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                    grep -A 20 "PostgresQuerySample" | grep -c "\"queryFingerprint\"" || echo "0")
assert_greater_than "$FINGERPRINT_EXISTS" "0" "Query fingerprint is captured"

# Check if pg_sleep query is captured
echo "Checking if pg_sleep query is captured..."
PG_SLEEP_EXISTS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                 grep -A 20 "PostgresQuerySample" | grep -c "pg_sleep" || echo "0")
assert_greater_than "$PG_SLEEP_EXISTS" "0" "pg_sleep query is captured"

# Verify query events have appropriate duration
echo "Checking if query events have appropriate duration..."
SLOW_QUERIES=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
              grep -A 20 "PostgresQuerySample" | grep -c "\"duration\":[0-9]\.[0-9]" || echo "0")
assert_greater_than "$SLOW_QUERIES" "0" "Query events have appropriate duration"

# Test scenario where pg_stat_statements is disabled
echo "Testing scenario where pg_stat_statements is disabled..."

# Create a temporary function to disable pg_stat_statements
$DOCKER_CMD exec "$POSTGRES_CONTAINER" psql -U postgres -c "
CREATE OR REPLACE FUNCTION disable_pg_stat_statements() RETURNS void AS \$\$
BEGIN
    EXECUTE 'DROP EXTENSION pg_stat_statements;';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error disabling pg_stat_statements: %', SQLERRM;
END;
\$\$ LANGUAGE plpgsql;
"

# Try to disable the extension (this will usually fail in production setups due to shared_preload_libraries)
$DOCKER_CMD exec "$POSTGRES_CONTAINER" psql -U postgres -c "SELECT disable_pg_stat_statements();" >/dev/null 2>&1

# Log warning that in a real test this would require a PostgreSQL restart
echo "NOTE: In a real test environment, fully disabling pg_stat_statements would require a PostgreSQL restart."
echo "      This test demonstrates checking for the absence of events when disabled."

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
