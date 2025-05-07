#!/usr/bin/env bats
# Database performance test
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"
load "../../lib/db"

# Test variables
TEST_DURATION=10  # seconds
RESULTS_DIR="../../artifacts"
CSV_FILE="${RESULTS_DIR}/perf_results.csv"

# Setup for the test suite
setup_file() {
  mkdir -p "$RESULTS_DIR"
  
  # Create CSV header if it doesn't exist
  if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,test_id,db_type,operation,duration_ms,records_processed" > "$CSV_FILE"
  fi
}

# Setup for each test
setup() {
  # Make sure both databases are available
  wait_for_mysql "mysql" "3306" "root" "root" "test" 30
  wait_for_postgres "postgres" "5432" "postgres" "postgres" "postgres" 30
}

@test "MySQL performance: simple queries" {
  # Set up variables for test
  local test_id="mysql-simple-queries"
  local db_type="mysql"
  local operation="simple-queries"
  local start_time=$(date +%s%3N)  # Milliseconds
  
  # Run test
  run mysql_query "mysql" "3306" "root" "root" "test" "SELECT COUNT(*) FROM performance_test"
  assert_success
  
  # Get result count
  local count=$(echo "$output" | grep -v "COUNT" | tr -d '[:space:]')
  
  # End timing
  local end_time=$(date +%s%3N)  # Milliseconds
  local duration=$((end_time - start_time))
  
  # Log results
  echo "$(date -Iseconds),${test_id},${db_type},${operation},${duration},${count}" >> "$CSV_FILE"
  
  # Validate performance
  assert_less_than "$duration" "2000" "Simple query should complete in under 2 seconds"
}

@test "MySQL performance: complex join query" {
  # Set up variables for test
  local test_id="mysql-complex-join"
  local db_type="mysql"
  local operation="complex-join"
  local start_time=$(date +%s%3N)  # Milliseconds
  
  # Run test
  run mysql_query "mysql" "3306" "root" "root" "test" \
    "SELECT pt.*, pm.metadata_key, pm.metadata_value 
     FROM performance_test pt 
     JOIN performance_metadata pm ON pt.id = pm.test_id 
     WHERE pt.string_value LIKE 'Value-%' 
     ORDER BY pt.created_at 
     LIMIT 100"
  assert_success
  
  # Count lines in output (records processed)
  local records=$(echo "$output" | wc -l)
  
  # End timing
  local end_time=$(date +%s%3N)  # Milliseconds
  local duration=$((end_time - start_time))
  
  # Log results
  echo "$(date -Iseconds),${test_id},${db_type},${operation},${duration},${records}" >> "$CSV_FILE"
  
  # Validate performance
  assert_less_than "$duration" "5000" "Complex join query should complete in under 5 seconds"
}

@test "PostgreSQL performance: simple queries" {
  # Set up variables for test
  local test_id="postgresql-simple-queries"
  local db_type="postgresql"
  local operation="simple-queries"
  local start_time=$(date +%s%3N)  # Milliseconds
  
  # Run test
  run pg_query "postgres" "5432" "postgres" "postgres" "postgres" \
    "SELECT COUNT(*) FROM test_monitoring.performance_test"
  assert_success
  
  # Get result count
  local count=$(echo "$output" | grep -v "count" | tr -d '[:space:]')
  
  # End timing
  local end_time=$(date +%s%3N)  # Milliseconds
  local duration=$((end_time - start_time))
  
  # Log results
  echo "$(date -Iseconds),${test_id},${db_type},${operation},${duration},${count}" >> "$CSV_FILE"
  
  # Validate performance
  assert_less_than "$duration" "2000" "Simple query should complete in under 2 seconds"
}

@test "PostgreSQL performance: complex join query" {
  # Set up variables for test
  local test_id="postgresql-complex-join"
  local db_type="postgresql"
  local operation="complex-join"
  local start_time=$(date +%s%3N)  # Milliseconds
  
  # Run test
  run pg_query "postgres" "5432" "postgres" "postgres" "postgres" \
    "SELECT pt.*, pm.metadata_key, pm.metadata_value 
     FROM test_monitoring.performance_test pt 
     JOIN test_monitoring.performance_metadata pm ON pt.id = pm.test_id 
     WHERE pt.string_value LIKE 'Value-%' 
     ORDER BY pt.created_at 
     LIMIT 100"
  assert_success
  
  # Count lines in output (records processed)
  local records=$(echo "$output" | wc -l)
  
  # End timing
  local end_time=$(date +%s%3N)  # Milliseconds
  local duration=$((end_time - start_time))
  
  # Log results
  echo "$(date -Iseconds),${test_id},${db_type},${operation},${duration},${records}" >> "$CSV_FILE"
  
  # Validate performance
  assert_less_than "$duration" "5000" "Complex join query should complete in under 5 seconds"
}

@test "Generate load and monitor performance impact" {
  # Set up variables for test
  local test_id="performance-impact"
  local duration="10"  # seconds
  
  # Set up baseline
  run mysql_query "mysql" "3306" "root" "root" "test" "SELECT COUNT(*) FROM performance_test"
  local initial_mysql_count=$(echo "$output" | grep -v "COUNT" | tr -d '[:space:]')
  
  run pg_query "postgres" "5432" "postgres" "postgres" "postgres" \
    "SELECT COUNT(*) FROM test_monitoring.performance_test"
  local initial_pg_count=$(echo "$output" | grep -v "count" | tr -d '[:space:]')
  
  # Generate load
  echo "Generating database load for ${duration} seconds..."
  generate_mysql_load "mysql" "3306" "root" "root" "test" "$duration"
  generate_postgres_load "postgres" "5432" "postgres" "postgres" "postgres" "$duration"
  
  # Wait for metrics to be collected
  sleep 5
  
  # Check counts after load generation
  run mysql_query "mysql" "3306" "root" "root" "test" "SELECT COUNT(*) FROM performance_test"
  local final_mysql_count=$(echo "$output" | grep -v "COUNT" | tr -d '[:space:]')
  
  run pg_query "postgres" "5432" "postgres" "postgres" "postgres" \
    "SELECT COUNT(*) FROM test_monitoring.performance_test"
  local final_pg_count=$(echo "$output" | grep -v "count" | tr -d '[:space:]')
  
  # Log summary to CSV
  echo "$(date -Iseconds),${test_id},mysql,records,0,${initial_mysql_count}" >> "$CSV_FILE"
  echo "$(date -Iseconds),${test_id},postgresql,records,0,${initial_pg_count}" >> "$CSV_FILE"
  
  # Validate that counts haven't changed (we're not modifying data)
  assert_equal "$initial_mysql_count" "$final_mysql_count" "MySQL record count should remain the same"
  assert_equal "$initial_pg_count" "$final_pg_count" "PostgreSQL record count should remain the same"
  
  echo "Load generation completed successfully"
}
