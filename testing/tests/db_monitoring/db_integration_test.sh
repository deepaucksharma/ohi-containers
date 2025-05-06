#!/bin/bash
# Database Integration Test
# This test verifies that New Relic Infrastructure can monitor both MySQL
# and PostgreSQL simultaneously with proper collection of metrics.

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

POSTGRES_HOST=${POSTGRES_HOST:-"postgres"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-"newrelic"}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"test_password"}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-"postgres"}

NEWRELIC_API_URL=${NEWRELIC_API_URL:-"http://mockbackend:8080/v1"}

# Verify New Relic agent is running
test_newrelic_agent_running() {
  log_message "INFO" "Verifying New Relic Infrastructure agent is running..."
  
  docker ps | grep -q "test-newrelic-infra"
  assert_exit_code 0 "New Relic Infrastructure container is running"
  
  docker exec test-newrelic-infra pgrep -f "newrelic-infra" > /dev/null 2>&1
  assert_exit_code 0 "New Relic Infrastructure process is running"
}

# Verify both database integrations are installed
test_database_integrations_installed() {
  log_message "INFO" "Verifying both database integrations are installed..."
  
  # Check MySQL integration
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/integrations.d/mysql-config.yml > /dev/null 2>&1
  assert_exit_code 0 "MySQL integration configuration exists"
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql > /dev/null 2>&1
  assert_exit_code 0 "MySQL integration binary exists"
  
  # Check PostgreSQL integration
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/integrations.d/postgres-config.yml > /dev/null 2>&1
  assert_exit_code 0 "PostgreSQL integration configuration exists"
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/newrelic-integrations/bin/nri-postgresql > /dev/null 2>&1
  assert_exit_code 0 "PostgreSQL integration binary exists"
}

# Generate load on both databases
generate_database_load() {
  log_message "INFO" "Generating load on both databases..."
  
  # Generate MySQL load
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
    CREATE TABLE IF NOT EXISTS load_test (
      id INT AUTO_INCREMENT PRIMARY KEY,
      data VARCHAR(255),
      num INT,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert a batch of test data
    INSERT INTO load_test (data, num)
    SELECT 
      CONCAT('data-', FLOOR(RAND() * 10000)), 
      FLOOR(RAND() * 1000)
    FROM information_schema.tables
    LIMIT 500;
    
    -- Run a few queries to generate load
    SELECT COUNT(*) FROM load_test;
    SELECT AVG(num) FROM load_test;
    SELECT data, COUNT(*) FROM load_test GROUP BY data ORDER BY COUNT(*) DESC LIMIT 10;
    SELECT DATE(created_at) as day, COUNT(*) FROM load_test GROUP BY day;
    "
  
  # Generate PostgreSQL load
  docker run --rm --network host \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    postgres:14 \
    psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" \
    -c "
    -- Create a test table with random data if it doesn't exist
    CREATE TABLE IF NOT EXISTS load_test (
      id SERIAL PRIMARY KEY,
      data VARCHAR(255),
      num INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert a batch of test data
    INSERT INTO load_test (data, num)
    SELECT 
      'data-' || floor(random() * 10000)::text, 
      floor(random() * 1000)::int
    FROM generate_series(1, 500);
    
    -- Run a few queries to generate load
    SELECT COUNT(*) FROM load_test;
    SELECT AVG(num) FROM load_test;
    SELECT data, COUNT(*) FROM load_test GROUP BY data ORDER BY COUNT(*) DESC LIMIT 10;
    SELECT DATE(created_at) as day, COUNT(*) FROM load_test GROUP BY day;
    "
  
  log_message "INFO" "Successfully generated load on both databases"
}

# Verify metrics are being collected from both databases
test_metrics_collection() {
  log_message "INFO" "Verifying metrics collection from both databases..."
  
  # Wait for metrics to be collected
  log_message "INFO" "Waiting for metrics to be collected (60 seconds)..."
  sleep 60
  
  # Check for MySQL metrics
  mysql_metrics=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "mysql")
  log_message "INFO" "MySQL metrics count: $mysql_metrics"
  
  if [ "$mysql_metrics" -gt 0 ]; then
    log_message "INFO" "✅ MySQL metrics are being collected"
  else
    log_message "ERROR" "❌ No MySQL metrics found"
    return 1
  fi
  
  # Check for PostgreSQL metrics
  postgres_metrics=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "postgresql")
  log_message "INFO" "PostgreSQL metrics count: $postgres_metrics"
  
  if [ "$postgres_metrics" -gt 0 ]; then
    log_message "INFO" "✅ PostgreSQL metrics are being collected"
  else
    log_message "ERROR" "❌ No PostgreSQL metrics found"
    return 1
  fi
  
  # Test passed if we have metrics from both databases
  return 0
}

# Verify New Relic infrastructure logs for database monitoring
test_newrelic_logs() {
  log_message "INFO" "Checking New Relic Infrastructure logs for database monitoring..."
  
  # Check logs for MySQL integration
  mysql_logs=$(docker exec test-newrelic-infra grep -c "mysql" /var/log/newrelic-infra/newrelic-infra.log)
  log_message "INFO" "MySQL log entries: $mysql_logs"
  
  if [ "$mysql_logs" -gt 0 ]; then
    log_message "INFO" "✅ Found MySQL entries in New Relic logs"
  else
    log_message "WARN" "⚠️ No MySQL entries found in New Relic logs"
  fi
  
  # Check logs for PostgreSQL integration
  postgres_logs=$(docker exec test-newrelic-infra grep -c "postgre" /var/log/newrelic-infra/newrelic-infra.log)
  log_message "INFO" "PostgreSQL log entries: $postgres_logs"
  
  if [ "$postgres_logs" -gt 0 ]; then
    log_message "INFO" "✅ Found PostgreSQL entries in New Relic logs"
  else
    log_message "WARN" "⚠️ No PostgreSQL entries found in New Relic logs"
  fi
}

# Test for query metrics collection capabilities
test_query_metrics_collection() {
  log_message "INFO" "Testing query metrics collection capabilities..."
  
  # Check MySQL query metrics
  mysql_query_metrics=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "mysql.query")
  log_message "INFO" "MySQL query metrics count: $mysql_query_metrics"
  
  # Check PostgreSQL query metrics
  postgres_query_metrics=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "postgresql.query")
  log_message "INFO" "PostgreSQL query metrics count: $postgres_query_metrics"
  
  # At least one of the databases should have query metrics
  total_query_metrics=$((mysql_query_metrics + postgres_query_metrics))
  if [ "$total_query_metrics" -gt 0 ]; then
    log_message "INFO" "✅ Query performance metrics are being collected"
    return 0
  else
    log_message "ERROR" "❌ No query performance metrics found"
    return 1
  fi
}

# Run all tests
run_tests() {
  log_message "INFO" "Running Database Integration Tests"
  
  # Run test functions
  test_newrelic_agent_running
  test_database_integrations_installed
  generate_database_load
  test_metrics_collection
  test_newrelic_logs
  test_query_metrics_collection
  
  log_message "INFO" "All Database Integration Tests completed"
}

# Execute tests
run_tests
