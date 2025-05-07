#!/usr/bin/env bats
# CONF-01: Configuration Template Rendering Test
# Verify that environment variables are correctly rendered in the configuration templates
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"

# Test variables
TEST_ID="CONF-01"
TEST_NAME="Configuration Template Rendering"
TEST_DESCRIPTION="Verify that environment variables are correctly rendered in the configuration templates"
CONTAINER_NAME="test-newrelic-infra"

# Setup for all tests in this file
setup() {
  # Ensure container is running
  if ! docker ps | grep -q "$CONTAINER_NAME"; then
    skip "Container $CONTAINER_NAME is not running"
  fi
}

@test "newrelic-infra.yml file should be created from template" {
  # Check if the newrelic-infra.yml file exists
  run docker exec "$CONTAINER_NAME" test -f /etc/newrelic-infra.yml
  assert_success
}

@test "newrelic-infra.yml should not contain any unexpanded ${VAR} placeholders" {
  # Check for any unexpanded ${VAR} placeholders
  run docker exec "$CONTAINER_NAME" grep -c '\${' /etc/newrelic-infra.yml || echo "0"
  assert_success
  assert_equal "$output" "0" "newrelic-infra.yml should not contain any unexpanded \${VAR} placeholders"
}

@test "LICENSE_KEY should be correctly set in the configuration" {
  # Check if license key is set
  run docker exec "$CONTAINER_NAME" grep -c "license_key" /etc/newrelic-infra.yml
  assert_success
  assert_greater_than "$output" "0" "LICENSE_KEY should be set in the configuration"
  
  # Check if license key is properly expanded
  run docker exec "$CONTAINER_NAME" grep -c "\${" /etc/newrelic-infra.yml
  assert_success
  assert_equal "$output" "0" "No unexpanded variables should be in the configuration"
}

@test "Display name should be correctly set in the configuration" {
  # Check if display name is set from environment variable
  run docker exec "$CONTAINER_NAME" grep -c "display_name" /etc/newrelic-infra.yml
  assert_success
  assert_greater_than "$output" "0" "Display name should be set in the configuration"
  
  # Verify the actual display name value
  run docker exec "$CONTAINER_NAME" grep "display_name" /etc/newrelic-infra.yml
  assert_success
  assert_output --partial "Test Infrastructure"
}

@test "Integration configs should exist for MySQL and PostgreSQL" {
  # Check MySQL integration config
  run docker exec "$CONTAINER_NAME" test -f /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  
  # Check PostgreSQL integration config
  run docker exec "$CONTAINER_NAME" test -f /etc/newrelic-infra/integrations.d/postgresql-config.yml
  assert_success
}

@test "MySQL integration config should have correct connection details" {
  # Check MySQL host setting
  run docker exec "$CONTAINER_NAME" grep -c "HOSTNAME: mysql" /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  assert_greater_than "$output" "0" "MySQL host should be correctly set"
  
  # Check MySQL port setting
  run docker exec "$CONTAINER_NAME" grep -c "PORT: 3306" /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  assert_greater_than "$output" "0" "MySQL port should be correctly set"
}

@test "PostgreSQL integration config should have correct connection details" {
  # Check PostgreSQL host setting
  run docker exec "$CONTAINER_NAME" grep -c "HOSTNAME: postgres" /etc/newrelic-infra/integrations.d/postgresql-config.yml
  assert_success
  assert_greater_than "$output" "0" "PostgreSQL host should be correctly set"
  
  # Check PostgreSQL port setting
  run docker exec "$CONTAINER_NAME" grep -c "PORT: 5432" /etc/newrelic-infra/integrations.d/postgresql-config.yml
  assert_success
  assert_greater_than "$output" "0" "PostgreSQL port should be correctly set"
}

@test "MySQL integration should use the correct variable names" {
  # MySQL integration should use SLAVE_METRICS (not COLLECT_SLAVE_METRICS)
  run docker exec "$CONTAINER_NAME" grep -c "SLAVE_METRICS:" /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  assert_greater_than "$output" "0" "MySQL integration should use SLAVE_METRICS"
  
  # MySQL integration should not use METRICS or GLOBAL_STATS
  run docker exec "$CONTAINER_NAME" grep -c "METRICS:" /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  assert_equal "$output" "0" "MySQL integration should not use METRICS"
  
  run docker exec "$CONTAINER_NAME" grep -c "GLOBAL_STATS:" /etc/newrelic-infra/integrations.d/mysql-config.yml
  assert_success
  assert_equal "$output" "0" "MySQL integration should not use GLOBAL_STATS"
}

@test "PostgreSQL integration should use the correct variable names" {
  # PostgreSQL integration should use COLLECT_DB_LOCK_METRICS (not DB_LOCK_METRICS)
  run docker exec "$CONTAINER_NAME" grep -c "COLLECT_DB_LOCK_METRICS:" /etc/newrelic-infra/integrations.d/postgresql-config.yml
  assert_success
  assert_greater_than "$output" "0" "PostgreSQL integration should use COLLECT_DB_LOCK_METRICS"
  
  # PostgreSQL integration should not use METRICS
  run docker exec "$CONTAINER_NAME" grep -c "METRICS:" /etc/newrelic-infra/integrations.d/postgresql-config.yml
  assert_success
  assert_equal "$output" "0" "PostgreSQL integration should not use METRICS"
}
