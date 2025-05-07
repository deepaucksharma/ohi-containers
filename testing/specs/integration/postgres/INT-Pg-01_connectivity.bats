#!/usr/bin/env bats
# INT-Pg-01: PostgreSQL connectivity test
# Agent reaches PostgreSQL fixture and reports PostgreSQLSample
# Version: 2.0.0

# Load test utilities
load "../../../lib/common"
load "../../../lib/assert"
load "../../../lib/db"

# Test variables
TEST_ID="INT-Pg-01"
TEST_NAME="PostgreSQL Connectivity Test"
TEST_DESCRIPTION="Verify that New Relic agent reaches PostgreSQL fixture and reports PostgreSQLSample"

# Setup for all tests in this file
setup() {
  # Wait for PostgreSQL to be ready
  wait_for_postgres "postgres" "5432" "postgres" "postgres" "postgres" "30"
  
  # Sleep to allow initial metrics to be collected
  sleep 5
}

@test "PostgreSQL container should be running" {
  run docker ps --filter "name=test-postgres" --format "{{.ID}}"
  assert_success
  assert_output
  POSTGRES_CONTAINER="$output"
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

@test "New Relic agent should connect to PostgreSQL" {
  # Wait for data to be sent to mock backend (up to 20 seconds)
  run poll_until 20 "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -q 'PostgreSQLSample'"
  assert_success
}

@test "Mock backend should receive PostgreSQLSample events" {
  # Query the mock backend for PostgreSQLSample events
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -c 'PostgreSQLSample'"
  assert_success
  assert_greater_than "$output" "0" "Mock backend received PostgreSQLSample events"
}

@test "Events should contain correct database name" {
  # Verify database name in the samples
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -c '\"database\":\"postgres\"'"
  assert_success
  assert_greater_than "$output" "0" "Events contain correct database name"
}

@test "Agent logs should not contain PostgreSQL connection errors" {
  # Check for PostgreSQL connection errors
  run bash -c "docker exec \$(docker ps -q -f name=test-newrelic-infra) grep -c 'Error connecting to PostgreSQL' /var/log/newrelic-infra/newrelic-infra.log || echo '0'"
  assert_success
  assert_equal "$output" "0" "No PostgreSQL connection errors in agent logs"
}

@test "Agent should collect metrics about pg_stat_statements" {
  # Check if pg_stat_statements metrics are collected
  run bash -c "docker exec \$(docker ps -q -f name=mock-newrelic) curl -s 'http://localhost:8080/__admin/requests' | grep -c 'pg_stat_statements'"
  assert_success
  assert_greater_than "$output" "0" "pg_stat_statements metrics are collected"
}
