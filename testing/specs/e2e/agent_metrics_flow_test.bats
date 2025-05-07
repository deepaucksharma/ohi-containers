#!/usr/bin/env bats
# Test for New Relic Infrastructure agent metrics flow
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"
load "../../lib/db"

# Test variables
MOCK_BACKEND="mockbackend"
MOCK_PORT="8080"
AGENT_HOST="newrelic-infra"
METRICS_ENDPOINT="/v1/metrics"
TIMEOUT=60  # seconds

# Setup for tests
setup() {
  # Ensure the mock backend is available
  wait_for_port "$MOCK_BACKEND" "$MOCK_PORT" "$TIMEOUT"
}

# Teardown after tests
teardown() {
  # Clean up any test-specific resources if needed
  :
}

@test "Agent should be running and healthy" {
  # Check if the agent container is running and healthy
  run bash -c "docker ps --filter 'name=$AGENT_HOST' --format '{{.Status}}'"
  
  assert_success
  assert_output --partial "(healthy)"
}

@test "Agent should send metrics to mock backend" {
  # Clear any existing metrics requests
  run curl -s -X POST "http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests/reset"
  
  assert_success
  
  # Wait for metrics to be sent (up to 30 seconds)
  run poll_until 30 "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests/count' | grep -q '\"count\" *: *[1-9]'"
  
  assert_success
  
  # Check if metrics were received by the mock backend
  run bash -c "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\"))' | wc -l"
  
  assert_success
  assert_greater_than "$output" "0" "Agent should have sent at least one metrics payload"
}

@test "Agent should send system metrics" {
  # Wait for system metrics to be sent
  run poll_until 30 "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq -r '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\")) | .body' | grep -q 'system'"
  
  assert_success
  
  # Verify system metrics were sent
  run bash -c "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq -r '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\")) | .body' | grep 'system' | wc -l"
  
  assert_success
  assert_greater_than "$output" "0" "Agent should have sent system metrics"
}

@test "Agent should send database integration metrics" {
  # Generate some database load
  generate_mysql_load "mysql" "3306" "root" "root" "test" 5
  generate_postgres_load "postgres" "5432" "postgres" "postgres" "postgres" 5
  
  # Wait for metrics to include database metrics
  run poll_until 30 "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq -r '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\")) | .body' | grep -E '(mysql|postgresql)' | wc -l"
  
  assert_success
  assert_greater_than "$output" "0" "Agent should have sent database integration metrics"
  
  # Specific check for MySQL metrics
  run bash -c "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq -r '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\")) | .body' | grep -q 'mysql'"
  
  assert_success
  
  # Specific check for PostgreSQL metrics
  run bash -c "curl -s 'http://${MOCK_BACKEND}:${MOCK_PORT}/__admin/requests' | jq -r '.requests[] | select(.url | contains(\"${METRICS_ENDPOINT}\")) | .body' | grep -q 'postgresql'"
  
  assert_success
}
