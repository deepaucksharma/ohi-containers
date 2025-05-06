#!/bin/bash
# MySQL Query Performance Monitoring Test
# This test verifies that New Relic Infrastructure is correctly collecting 
# MySQL query performance data.

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../../../" && pwd)
testing_root=$(cd "$script_dir/../../" && pwd)

# Source test utilities
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Test variables
MYSQL_HOST=${MYSQL_HOST:-"mysql"}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-"newrelic"}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-"test_password"}
MYSQL_DATABASE=${MYSQL_DATABASE:-"test"}
NEWRELIC_API_URL=${NEWRELIC_API_URL:-"http://mockbackend:8080/v1"}

# Test MySQL connection
test_mysql_connection() {
  log_message "INFO" "Testing MySQL connection..."
  
  # Use Docker to connect to MySQL
  docker run --rm --network host \
    -e MYSQL_HOST="$MYSQL_HOST" \
    -e MYSQL_PORT="$MYSQL_PORT" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    mysql:8.0 \
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SELECT 1" > /dev/null 2>&1
  
  assert_exit_code 0 "MySQL connection test"
}

# Test New Relic Infrastructure MySQL integration installation
test_mysql_integration_installed() {
  log_message "INFO" "Verifying MySQL integration is installed..."
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/integrations.d/mysql-config.yml > /dev/null 2>&1
  assert_exit_code 0 "MySQL integration configuration exists"
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql > /dev/null 2>&1
  assert_exit_code 0 "MySQL integration binary exists"
}

# Test MySQL slow query log is enabled
test_mysql_slow_query_enabled() {
  log_message "INFO" "Verifying MySQL slow query log is enabled..."
  
  # Connect to MySQL and check if slow query log is enabled
  result=$(docker run --rm --network host \
    -e MYSQL_HOST="$MYSQL_HOST" \
    -e MYSQL_PORT="$MYSQL_PORT" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    mysql:8.0 \
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    -e "SHOW VARIABLES LIKE 'slow_query_log';" 2>/dev/null | grep -c "ON")
  
  assert_equals 1 "$result" "MySQL slow query log is enabled"
}

# Generate slow queries for testing
generate_test_queries() {
  log_message "INFO" "Generating test queries to measure performance..."
  
  # Execute some deliberately slow queries
  docker run --rm --network host \
    -e MYSQL_HOST="$MYSQL_HOST" \
    -e MYSQL_PORT="$MYSQL_PORT" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    mysql:8.0 \
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
    -e "
    -- Create a test table with random data if it doesn't exist
    CREATE TABLE IF NOT EXISTS test_data (
      id INT AUTO_INCREMENT PRIMARY KEY,
      val1 VARCHAR(255),
      val2 VARCHAR(255),
      val3 INT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert some test data if table is empty
    INSERT INTO test_data (val1, val2, val3)
    SELECT 
      CONCAT('value-', FLOOR(RAND() * 1000)), 
      CONCAT('data-', FLOOR(RAND() * 1000)),
      FLOOR(RAND() * 10000)
    FROM information_schema.tables
    LIMIT 1000;
    
    -- Execute a deliberately slow query with a JOIN and no index
    SELECT t1.val1, t1.val2, t2.val3
    FROM test_data t1
    JOIN test_data t2 ON t1.val3 = t2.val3
    WHERE t1.val1 LIKE 'value-%'
    ORDER BY t1.created_at
    LIMIT 100;
    
    -- Another slow query that forces a full table scan
    SELECT * 
    FROM test_data
    WHERE val3 BETWEEN 1000 AND 9000
    ORDER BY val1, val2, val3
    LIMIT 500;
    "
    
  assert_exit_code 0 "Generated test queries successfully"
}

# Verify that New Relic is collecting query performance metrics
test_newrelic_collecting_query_metrics() {
  log_message "INFO" "Verifying New Relic is collecting query performance metrics..."
  
  # Wait for metrics to be collected and sent
  sleep 60
  
  # Check if New Relic Infrastructure is sending MySQL query metrics
  # This uses the mock backend to verify metrics are being sent
  response=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "mysql.query")
  
  # We expect at least one MySQL query metric to be found
  if [ "$response" -gt 0 ]; then
    log_message "INFO" "New Relic is collecting MySQL query metrics"
    return 0
  else
    log_message "ERROR" "New Relic is not collecting MySQL query metrics"
    return 1
  fi
}

# Verify correct MySQL OHI configuration 
test_mysql_ohi_config() {
  log_message "INFO" "Checking MySQL OHI configuration settings..."
  
  # Extract and verify MySQL OHI configuration
  docker exec test-newrelic-infra cat /var/db/newrelic-infra/integrations.d/mysql-config.yml > /tmp/mysql-config.yml
  
  # Verify query metrics collection is enabled
  grep -q "metrics: true" /tmp/mysql-config.yml
  assert_exit_code 0 "MySQL metrics collection is enabled"
  
  # Verify slow query collection is enabled
  grep -q "slow_queries: true" /tmp/mysql-config.yml
  assert_exit_code 0 "MySQL slow query collection is enabled"
  
  # Verify extended metrics collection is enabled
  grep -q "extended_metrics: true" /tmp/mysql-config.yml
  assert_exit_code 0 "MySQL extended metrics collection is enabled"
  
  # Verify extended innodb metrics collection is enabled
  grep -q "extended_innodb_metrics: true" /tmp/mysql-config.yml
  assert_exit_code 0 "MySQL extended InnoDB metrics collection is enabled"
}

# Run all tests
run_tests() {
  log_message "INFO" "Running MySQL Query Performance Monitoring Tests"
  
  # Run test functions
  test_mysql_connection
  test_mysql_integration_installed
  test_mysql_slow_query_enabled
  test_mysql_ohi_config
  generate_test_queries
  test_newrelic_collecting_query_metrics
  
  log_message "INFO" "All MySQL Query Performance Monitoring Tests completed"
}

# Execute tests
run_tests
