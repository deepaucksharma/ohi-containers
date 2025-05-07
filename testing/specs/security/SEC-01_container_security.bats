#!/usr/bin/env bats
# SEC-01: Container Security Test
# Verify that the New Relic container follows security best practices
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"

# Test variables
TEST_ID="SEC-01"
TEST_NAME="Container Security Test"
TEST_DESCRIPTION="Verify that the New Relic container follows security best practices"
CONTAINER_NAME="test-newrelic-infra"

# Setup for all tests in this file
setup() {
  # Ensure container is running
  if ! docker ps | grep -q "$CONTAINER_NAME"; then
    skip "Container $CONTAINER_NAME is not running"
  fi
}

@test "Container should not run as root user (UID 0)" {
  # Check user the container is running as
  run docker exec "$CONTAINER_NAME" id -u
  assert_success
  assert_not_equal "$output" "0" "Container should not run as root (UID 0)"
  
  # Verify it's running as the expected UID 1000 (newrelic-user)
  assert_equal "$output" "1000" "Container should run as UID 1000 (newrelic-user)"
}

@test "Sensitive environment variables should not be exposed" {
  # Check if license key is visible in plain text in 'docker inspect'
  run bash -c "docker inspect $CONTAINER_NAME --format='{{range .Config.Env}}{{println .}}{{end}}' | grep -i license_key"
  
  assert_success  # Should find the variable
  
  # But it should be obscured in the Docker inspect output
  refute_output --partial "dummy012345678901234567890123456789"
}

@test "Tmpfs should be used for log data" {
  # Check if tmpfs is properly mounted
  run bash -c "docker inspect --format='{{range .Mounts}}{{if eq .Type \"tmpfs\"}}{{.Destination}}{{end}}{{end}}' $CONTAINER_NAME"
  assert_success
  assert_output --partial "/var/log/newrelic-infra"
}

@test "Tmpfs should have correct permissions (uid=1000, gid=1000)" {
  # Check tmpfs mount options
  run bash -c "docker inspect --format='{{range .Mounts}}{{if eq .Type \"tmpfs\"}}{{.Options}}{{end}}{{end}}' $CONTAINER_NAME"
  assert_success
  assert_output --partial "uid=1000"
  assert_output --partial "gid=1000"
}

@test "Container should not have any exposed ports" {
  # Check for exposed ports
  run bash -c "docker inspect --format='{{range \$p, \$conf := .NetworkSettings.Ports}}{{if \$conf}}{{println \$p}}{{end}}{{end}}' $CONTAINER_NAME"
  assert_success
  assert_output ""  # Should be empty if no ports are exposed
}

@test "Container should not use privileged mode" {
  # Check if container is running in privileged mode
  run bash -c "docker inspect --format='{{.HostConfig.Privileged}}' $CONTAINER_NAME"
  assert_success
  assert_output "false"  # Should not be privileged
}

@test "Configuration files should have proper permissions" {
  # Check permissions on configuration directory
  run docker exec "$CONTAINER_NAME" ls -ld /etc/newrelic-infra
  assert_success
  refute_output --partial "rwxrwxrwx"  # Should not have 777 permissions
}

@test "Integration configurations should be read-only" {
  # Check if integrations.d directory is mounted read-only
  run bash -c "docker inspect --format='{{range .Mounts}}{{if eq .Destination \"/etc/newrelic-infra/integrations.d\"}}{{.RW}}{{end}}{{end}}' $CONTAINER_NAME"
  assert_success
  assert_output "false"  # Should be read-only (false means RW is disabled)
}

@test "Container logs should not contain sensitive information" {
  # Check for sensitive information in logs
  run bash -c "docker logs $CONTAINER_NAME | grep -E '(password|secret|license|key|token)' | grep -v 'license_key=\\*\\*\\*' | grep -v 'REDACTED' | wc -l"
  assert_success
  assert_equal "$output" "0" "Logs should not contain sensitive information"
}

@test "Database credentials should be obfuscated in agent output" {
  # Check if MySQL credentials are obfuscated
  run bash -c "docker exec $CONTAINER_NAME cat /var/log/newrelic-infra/newrelic-infra.log | grep -i mysql | grep -i password | grep -v '\\*\\*\\*' | wc -l"
  assert_success
  assert_equal "$output" "0" "MySQL credentials should be obfuscated"
  
  # Check if PostgreSQL credentials are obfuscated
  run bash -c "docker exec $CONTAINER_NAME cat /var/log/newrelic-infra/newrelic-infra.log | grep -i postgres | grep -i password | grep -v '\\*\\*\\*' | wc -l"
  assert_success
  assert_equal "$output" "0" "PostgreSQL credentials should be obfuscated"
}

@test "Internal backend network should be isolated" {
  # Backend network should be marked as internal
  run bash -c "docker network inspect backend --format='{{.Internal}}'"
  assert_success
  assert_output "true"  # Should be internal (true means isolated)
}
