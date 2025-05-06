#!/bin/sh
# INT-My-02: MySQL DBPM test
# Slow query generated → integration emits MySQLQuerySample
# Version: 1.0.0

# Source utility scripts
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../../.." && pwd)
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"
. "$testing_root/lib/database_utils.sh"

# Test variables
TEST_ID="INT-My-02"
TEST_NAME="MySQL DBPM Slow Query Test"
TEST_DESCRIPTION="Verify that slow MySQL queries are captured and reported as MySQLQuerySample events"

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

# Check if stored procedure heavy_proc exists, create if not
PROC_EXISTS=$($DOCKER_CMD exec "$MYSQL_CONTAINER" mysql -unewrelic -ptest_password test -e "SHOW PROCEDURE STATUS WHERE Name = 'heavy_proc'" | grep -c "heavy_proc" || echo "0")

if [ "$PROC_EXISTS" -eq "0" ]; then
  echo "Creating heavy_proc stored procedure..."
  $DOCKER_CMD exec "$MYSQL_CONTAINER" mysql -unewrelic -ptest_password test -e "
  CREATE PROCEDURE heavy_proc()
  BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE j INT DEFAULT 0;
    
    -- Create a temporary table
    CREATE TEMPORARY TABLE temp_table (id INT, value INT);
    
    -- Insert a lot of data (will be slow)
    WHILE i < 10000 DO
      SET j = 0;
      WHILE j < 100 DO
        INSERT INTO temp_table VALUES (i, j);
        SET j = j + 1;
      END WHILE;
      SET i = i + 1;
    END WHILE;
    
    -- Run a complex query
    SELECT COUNT(*), AVG(value), MAX(value), MIN(value)
    FROM temp_table
    GROUP BY id % 100;
    
    -- Clean up
    DROP TEMPORARY TABLE temp_table;
  END;
  "
fi

# Clear any existing requests in mock backend
echo "Clearing previous requests from mock backend..."
$DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -X POST "http://localhost:8080/__admin/requests/reset"

# Execute the slow query multiple times
echo "Executing heavy_proc stored procedure 30 times..."
for i in $(seq 1 30); do
  echo "Executing heavy_proc: $i/30"
  $DOCKER_CMD exec "$MYSQL_CONTAINER" mysql -unewrelic -ptest_password test -e "CALL heavy_proc();" >/dev/null 2>&1
done

# Wait for data to be sent to mock backend (60 seconds)
echo "Waiting for data to be sent to mock backend (60 seconds)..."
sleep 60

# Query the mock backend for MySQLQuerySample events
echo "Querying mock backend for MySQLQuerySample events..."
REQUEST_COUNT=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -c "MySQLQuerySample")

assert_greater_than "$REQUEST_COUNT" "0" "Mock backend received MySQLQuerySample events"

# Get a detailed view of the received events
echo "Detailed view of received events:"
EVENT_DETAILS=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -A 20 "MySQLQuerySample" | head -n 40)
echo "$EVENT_DETAILS"

# Check if query events have a duration > 0.5s
echo "Checking if slow queries have duration > 0.5s..."
SLOW_QUERIES=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
              grep -A 20 "MySQLQuerySample" | grep -c "\"duration\":[0-9]\.[5-9]" || echo "0")
assert_greater_than "$SLOW_QUERIES" "0" "Slow queries with duration > 0.5s detected"

# Check if database name is correctly reported
echo "Checking if database name is correctly reported..."
DB_NAME_MATCH=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                grep -A 20 "MySQLQuerySample" | grep -c "\"database\":\"test\"" || echo "0")
assert_greater_than "$DB_NAME_MATCH" "0" "Query events contain correct database name"

# Check if query literals are obfuscated
echo "Checking if query literals are obfuscated..."
OBFUSCATED_QUERIES=$($DOCKER_CMD exec "$MOCK_BACKEND_CONTAINER" curl -s "http://localhost:8080/__admin/requests" | \
                    grep -A 20 "MySQLQuerySample" | grep -c "?" || echo "0")
assert_greater_than "$OBFUSCATED_QUERIES" "0" "Query literals are obfuscated with '?'"

echo
echo "Test $TEST_ID completed."
print_test_summary
exit $?
