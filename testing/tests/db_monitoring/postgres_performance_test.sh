#!/bin/bash
# PostgreSQL Query Performance Monitoring Test
# This test verifies that New Relic Infrastructure is correctly collecting 
# PostgreSQL query performance data.

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../../../" && pwd)
testing_root=$(cd "$script_dir/../../" && pwd)

# Source test utilities
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Test variables
POSTGRES_HOST=${POSTGRES_HOST:-"postgres"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_USER=${POSTGRES_USER:-"newrelic"}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"test_password"}
POSTGRES_DATABASE=${POSTGRES_DATABASE:-"postgres"}
NEWRELIC_API_URL=${NEWRELIC_API_URL:-"http://mockbackend:8080/v1"}

# Test PostgreSQL connection
test_postgres_connection() {
  log_message "INFO" "Testing PostgreSQL connection..."
  
  # Use Docker to connect to PostgreSQL
  docker run --rm --network host \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    postgres:14 \
    psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" \
    -c "SELECT 1" > /dev/null 2>&1
  
  assert_exit_code 0 "PostgreSQL connection test"
}

# Test New Relic Infrastructure PostgreSQL integration installation
test_postgres_integration_installed() {
  log_message "INFO" "Verifying PostgreSQL integration is installed..."
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/integrations.d/postgres-config.yml > /dev/null 2>&1
  assert_exit_code 0 "PostgreSQL integration configuration exists"
  
  docker exec test-newrelic-infra ls -la /var/db/newrelic-infra/newrelic-integrations/bin/nri-postgresql > /dev/null 2>&1
  assert_exit_code 0 "PostgreSQL integration binary exists"
}

# Test PostgreSQL query monitoring is enabled
test_postgres_monitoring_enabled() {
  log_message "INFO" "Verifying PostgreSQL query monitoring is enabled..."
  
  # Connect to PostgreSQL and check if pg_stat_statements is enabled
  result=$(docker run --rm --network host \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    postgres:14 \
    psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" \
    -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'pg_stat_statements';" -t 2>/dev/null | xargs)
  
  assert_equals "1" "$result" "PostgreSQL pg_stat_statements extension is enabled"
}

# Generate test queries for monitoring
generate_test_queries() {
  log_message "INFO" "Generating test queries to measure performance..."
  
  # Execute some deliberately slow queries
  docker run --rm --network host \
    -e PGPASSWORD="$POSTGRES_PASSWORD" \
    postgres:14 \
    psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" \
    -c "
    -- Create a test table with random data if it doesn't exist
    CREATE TABLE IF NOT EXISTS test_data (
      id SERIAL PRIMARY KEY,
      val1 VARCHAR(255),
      val2 VARCHAR(255),
      val3 INTEGER,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insert some test data if table is empty
    INSERT INTO test_data (val1, val2, val3)
    SELECT 
      'value-' || floor(random() * 1000)::text, 
      'data-' || floor(random() * 1000)::text,
      floor(random() * 10000)::int
    FROM generate_series(1, 1000)
    WHERE NOT EXISTS (SELECT 1 FROM test_data LIMIT 1);
    
    -- Execute a deliberately slow query with a JOIN and no index
    SELECT t1.val1, t1.val2, t2.val3
    FROM test_data t1
    JOIN test_data t2 ON t1.val3 = t2.val3
    WHERE t1.val1 LIKE 'value-%'
    ORDER BY t1.created_at
    LIMIT 100;
    
    -- Another slow query that forces a sequential scan
    EXPLAIN ANALYZE
    SELECT * 
    FROM test_data
    WHERE val3 BETWEEN 1000 AND 9000
    ORDER BY val1, val2, val3
    LIMIT 500;
    
    -- Force some statistics collection
    ANALYZE test_data;
    "
    
  assert_exit_code 0 "Generated test queries successfully"
}

# Verify that New Relic is collecting query performance metrics
test_newrelic_collecting_query_metrics() {
  log_message "INFO" "Verifying New Relic is collecting query performance metrics..."
  
  # Wait for metrics to be collected and sent
  sleep 60
  
  # Check if New Relic Infrastructure is sending PostgreSQL query metrics
  # This uses the mock backend to verify metrics are being sent
  response=$(curl -s "$NEWRELIC_API_URL/metrics" | grep -c "postgresql.query")
  
  # We expect at least one PostgreSQL query metric to be found
  if [ "$response" -gt 0 ]; then
    log_message "INFO" "New Relic is collecting PostgreSQL query metrics"
    return 0
  else
    log_message "ERROR" "New Relic is not collecting PostgreSQL query metrics"
    return 1
  fi
}

# Verify correct PostgreSQL OHI configuration 
test_postgres_ohi_config() {
  log_message "INFO" "Checking PostgreSQL OHI configuration settings..."
  
  # Extract and verify PostgreSQL OHI configuration
  docker exec test-newrelic-infra cat /var/db/newrelic-infra/integrations.d/postgres-config.yml > /tmp/postgres-config.yml
  
  # Verify query metrics collection is enabled
  grep -q "metrics: true" /tmp/postgres-config.yml
  assert_exit_code 0 "PostgreSQL metrics collection is enabled"
  
  # Verify pg_stat_statements collection is enabled
  grep -q "collect_statements: true" /tmp/postgres-config.yml
  assert_exit_code 0 "PostgreSQL statement collection is enabled"
  
  # Verify extended metrics collection is enabled
  grep -q "extended_metrics: true" /tmp/postgres-config.yml
  assert_exit_code 0 "PostgreSQL extended metrics collection is enabled"
}

# Run all tests
run_tests() {
  log_message "INFO" "Running PostgreSQL Query Performance Monitoring Tests"
  
  # Run test functions
  test_postgres_connection
  test_postgres_integration_installed
  test_postgres_monitoring_enabled
  test_postgres_ohi_config
  generate_test_queries
  test_newrelic_collecting_query_metrics
  
  log_message "INFO" "All PostgreSQL Query Performance Monitoring Tests completed"
}

# Execute tests
run_tests
