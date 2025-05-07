#!/usr/bin/env bats
# INT-Pg-02: PostgreSQL DBPM test
# Slow query generated → integration emits PostgreSQLQuerySample
# Version: 2.0.0

# Load test utilities
load "../../../lib/common"
load "../../../lib/assert"
load "../../../lib/db"

# Test variables
TEST_ID="INT-Pg-02"
TEST_NAME="PostgreSQL DBPM Slow Query Test"
TEST_DESCRIPTION="Verify that slow PostgreSQL queries are captured and reported as PostgreSQLQuerySample events"

# Setup for all tests in this file
setup() {
  # Wait for PostgreSQL to be ready
  wait_for_postgres "postgres" "5432" "postgres" "postgres" "postgres" "30"
}

@test "All required containers should be running" {
  # Check PostgreSQL container
  run docker ps --filter "name=test-postgres" --format "{{.ID}}"
  assert_success
  assert_output
  POSTGRES_CONTAINER="$output"
  
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

@test "Heavy function should exist or be created" {
  # Check if the function heavy_query exists, create if not
  run bash -c "docker exec \$(docker ps -q -f name=test-postgres) psql -U postgres -c \"SELECT proname FROM pg_proc WHERE proname = 'heavy_query'\" | grep -c \"heavy_query\" || echo \"0\""
  
  # If function doesn't exist, create it
  if [ "$output" -eq "0" ]; then
    run bash -c "docker exec \$(docker ps -q -f name=test-postgres) psql -U postgres -c \"
    CREATE OR REPLACE FUNCTION test_monitoring.heavy_query()
    RETURNS TABLE(cnt bigint, avg_val numeric, max_val integer, min_val integer) AS
    $$
    BEGIN
      -- Create a temp table
      CREATE TEMP TABLE temp_data AS
      SELECT generate_series(1, 10000) AS id, 
             generate_series(1, 10000) % 100 AS value;
      
      -- Create an index to make sure it's using it
      CREATE INDEX idx_temp_data ON temp_data(id);
      
      -- Run a query with large result set but still using the index
      RETURN QUERY
      SELECT COUNT(*) AS cnt, 
             AVG(value)::numeric AS avg_val, 
             MAX(value) AS max_val, 
             MIN(value) AS min_val
      FROM temp_data
      WHERE id BETWEEN 1 AND 9999
      GROUP BY id % 100
      ORDER BY id % 100;
      
      -- Clean up
      DROP TABLE temp_data;
    END;
    $$ LANGUAGE plpgsql;
    
    -- Grant execute permissions
    GRANT EXECUTE ON FUNCTION test_monitoring.heavy_query() TO postgres;
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

@test "Execute heavy function to generate slow queries" {
  # Execute the slow query multiple times (reduced to 5 for faster testing)
  for i in {1..5}; do
    run bash -c "docker exec \$(docker ps -q -f name=test-postgres) psql -U postgres -c \"SELECT * FROM test_monitoring.heavy_query();\" >/dev/null 2>&1"
    assert_success
  done
  
  # Wait for data to be sent to mock backend (reduced to 30 seconds)
  sleep 30
}

@test "Mock backend should receive PostgreSQLQuerySample events" {
  # Query the mock backend for PostgreSQLQuerySample events
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -c \"PostgreSQLQuerySample\""
  assert_success
  assert_greater_than "$output" "0" "Mock backend received PostgreSQLQuerySample events"
}

@test "Slow queries should have duration > 0.5s" {
  # Check if query events have a duration > 0.5s
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"PostgreSQLQuerySample\" | grep -c \"\\\"duration\\\":[0-9]\\.[5-9]\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Slow queries with duration > 0.5s detected"
}

@test "Query events should contain correct database name" {
  # Check if database name is correctly reported
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"PostgreSQLQuerySample\" | grep -c \"\\\"database\\\":\\\"postgres\\\"\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Query events contain correct database name"
}

@test "Query literals should be obfuscated" {
  # Check if query literals are obfuscated
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -A 20 \"PostgreSQLQuerySample\" | grep -c \"?\" || echo \"0\""
  assert_success
  assert_greater_than "$output" "0" "Query literals are obfuscated with '?'"
}

@test "pg_stat_statements should be enabled and used" {
  # Check if pg_stat_statements extension is enabled
  run bash -c "docker exec \$(docker ps -q -f name=test-postgres) psql -U postgres -c \"SELECT count(*) FROM pg_extension WHERE extname = 'pg_stat_statements';\" | grep -c \"1\""
  assert_success
  assert_greater_than "$output" "0" "pg_stat_statements extension is enabled"
  
  # Check if New Relic is collecting pg_stat_statements data
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s \"http://localhost:8080/__admin/requests\" | grep -c \"pg_stat_statements\""
  assert_success
  assert_greater_than "$output" "0" "New Relic is collecting pg_stat_statements data"
}
