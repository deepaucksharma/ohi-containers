#!/usr/bin/env bats
# INT-My-02: MySQL DBPM test
# Slow query generated → integration emits MySQLQuerySample
# Version: 2.0.0

# Load test utilities
load "../../../lib/common"
load "../../../lib/assert"
load "../../../lib/db"

# Test variables
TEST_ID="INT-My-02"
TEST_NAME="MySQL DBPM Slow Query Test"
TEST_DESCRIPTION="Verify that slow MySQL queries are captured and reported as MySQLQuerySample events"

# Setup for all tests in this file
setup() {
  # Wait for MySQL to be ready
  wait_for_mysql "mysql" "3306" "newrelic" "test_password" "30"
}

@test "All required containers should be running" {
  # Check MySQL container
  run docker ps --filter "name=test-mysql" --format "{{.ID}}"
  assert_success
  assert_output
  MYSQL_CONTAINER="$output"
  
  # Check mock backend container
  run docker ps --filter "name=mock-newrelic" --format "{{.ID}}"
  assert_success
  assert_output
  MOCK_BACKEND_CONTAINER="$output"
  
  # Check New Relic Infrastructure container
  run docker ps --filter "name=test-newrelic-infra" --format "{{.ID}}"
  assert_success
  assert_output
  INFRA_CONTAINER="$output"
}

@test "Heavy stored procedure should exist or be created" {
  # Check if stored procedure heavy_proc exists, create if not
  run bash -c "docker exec \$(docker ps -q -f name=test-mysql) mysql -unewrelic -ptest_password test -e \"SHOW PROCEDURE STATUS WHERE Name = 'heavy_proc'\" | grep -c \"heavy_proc\" || echo \"0\""
  
  # If procedure doesn't exist, create it
  if [ "$output" -eq "0" ]; then
    run bash -c "docker exec \$(docker ps -q -f name=test-mysql) mysql -unewrelic -ptest_password test -e \"
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
    \""
    assert_success
  else
    assert_success
  fi
}

@test "Reset mock backend before slow query test" {
  # Clear any existing requests in mock backend
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -X POST \"http://localhost:8080/__admin/requests/reset\""
  assert_success
}

@test "Execute heavy stored procedure to generate slow queries" {
  # Execute the slow query multiple times (reduced to 5 for faster testing)
  for i in {1..5}; do
    run bash -c "docker exec \$(docker ps -q -f name=test-mysql) mysql -unewrelic -ptest_password test -e \"CALL heavy_proc();\" >/dev/null 2>&1"
    assert_success
  done
  
  # Wait for data to be sent to mock backend (reduced to 30 seconds)
  sleep 30
}

@test "Mock backend should receive MySQLQuerySample events" {
  # Query the mock backend for MySQLQuerySample events
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -c \"MySQLQuerySample\""
  assert_success
  assert_greater_than "$output" "0" "Mock backend received MySQLQuerySample events"
}

@test "Slow queries should have duration > 0.5s" {
  # Check if query events have a duration > 0.5s
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"MySQLQuerySample\" | grep -c \"\\\"duration\\\":[0-9]\\.[5-9]\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Slow queries with duration > 0.5s detected"
}

@test "Query events should contain correct database name" {
  # Check if database name is correctly reported
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"MySQLQuerySample\" | grep -c \"\\\"database\\\":\\\"test\\\"\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Query events contain correct database name"
}

@test "Query literals should be obfuscated" {
  # Check if query literals are obfuscated
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"MySQLQuerySample\" | grep -c \"?\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Query literals are obfuscated with '?'"
}
