#!/usr/bin/env bats
# MySQL connectivity test
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"
load "../../lib/db"

# Test variables
MYSQL_HOST="mysql"
MYSQL_PORT="3306"
MYSQL_USER="newrelic"
MYSQL_PASSWORD="test_password"
MYSQL_DATABASE="test"

# Setup - runs before each test
setup() {
  # Wait for MySQL to be available
  wait_for_mysql "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" 30
}

@test "MySQL should be accessible with New Relic user" {
  # Try to connect to MySQL
  run mysql_query "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_DATABASE" "SELECT 1 AS test_value"
  
  assert_success
  assert_output --partial "test_value"
  assert_output --partial "1"
}

@test "MySQL should have performance_test table" {
  # Check if the test table exists
  run mysql_query "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'test' AND table_name = 'performance_test'"
  
  assert_success
  assert_output --partial "1"
}

@test "MySQL performance_test table should have data" {
  # Verify that the test table has some data
  run mysql_query "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    "SELECT COUNT(*) FROM performance_test"
  
  assert_success
  
  # Extract count number from output
  count=$(echo "$output" | grep -v "COUNT" | tr -d '[:space:]')
  
  # Assert table has records
  assert_greater_than "$count" "0" "performance_test table should have records"
}

@test "MySQL monitoring user should have required permissions" {
  # Check if the monitoring user has the required permissions
  run mysql_query "$MYSQL_HOST" "$MYSQL_PORT" "$MYSQL_USER" "$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    "SHOW GRANTS FOR '$MYSQL_USER'@'%'"
  
  assert_success
  assert_output --partial "PROCESS"
  assert_output --partial "REPLICATION CLIENT"
  assert_output --partial "SELECT"
}
