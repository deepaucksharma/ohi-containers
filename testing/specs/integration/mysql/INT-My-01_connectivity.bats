#!/usr/bin/env bats
# INT-My-01: MySQL connectivity test
# Agent reaches MySQL fixture and reports MySQLSample
# Version: 2.0.0

# Load test utilities
load "../../../lib/common"
load "../../../lib/assert"
load "../../../lib/db"

# Test variables
TEST_ID="INT-My-01"
TEST_NAME="MySQL Connectivity Test"
TEST_DESCRIPTION="Verify that New Relic agent reaches MySQL fixture and reports MySQLSample"

# Setup for all tests in this file
setup() {
  # Wait for MySQL to be ready
  wait_for_mysql "mysql" "3306" "newrelic" "test_password" "30"
  
  # Sleep to allow initial metrics to be collected
  sleep 5
}

@test "MySQL container should be running" {
  run docker ps --filter "name=test-mysql" --format "{{.ID}}"
  assert_success
  assert_output
  MYSQL_CONTAINER="$output"
}

@test "Mock backend container should be running" {
  run docker ps --filter "name=mock-newrelic" --format "{{.ID}}"
  assert_success
  assert_output
  MOCK_BACKEND_CONTAINER="$output"
}

@test "New Relic Infrastructure container should be running" {
  run docker ps --filter "name=test-newrelic-infra" --format "{{.ID}}"
  assert_success
  assert_output
  INFRA_CONTAINER="$output"
}

@test "New Relic agent should connect to MySQL" {
  # Wait for data to be sent to mock backend (up to 20 seconds)
  run poll_until 20 "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -q 'MySQLSample'"
  assert_success
}

@test "Mock backend should receive MySQLSample events" {
  # Query the mock backend for MySQLSample events
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -c 'MySQLSample'"
  assert_success
  assert_greater_than "$output" "0" "Mock backend received MySQLSample events"
}

@test "Events should contain correct database name" {
  # Verify database name in the samples
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -c '\"database\":\"test\"'"
  assert_success
  assert_greater_than "$output" "0" "Events contain correct database name"
}

@test "Agent logs should not contain MySQL connection errors" {
  # Check for MySQL connection errors
  run bash -c "docker exec \$(docker ps -q -f name=test-newrelic-infra) grep -c 'Error connecting to MySQL' /var/log/newrelic-infra/newrelic-infra.log || echo '0'"
  assert_success
  assert_equal "$output" "0" "No MySQL connection errors in agent logs"
}
