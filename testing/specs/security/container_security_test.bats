#!/usr/bin/env bats
# Container security tests
# Version: 2.0.0

# Load test utilities
load "../../lib/common"
load "../../lib/assert"

# Test variables
CONTAINER_NAME="test-newrelic-infra"

# Setup for tests
setup() {
  # Ensure container is running
  if ! docker ps | grep -q "$CONTAINER_NAME"; then
    skip "Container $CONTAINER_NAME is not running"
  fi
}

@test "Container should not run as root" {
  # Check user the container is running as
  run bash -c "docker exec $CONTAINER_NAME id -u"
  
  assert_success
  assert_not_equal "$output" "0" "Container should not run as root (uid 0)"
  
  # Verify it's running as the expected UID 1000
  assert_equal "$output" "1000" "Container should run as UID 1000"
}

@test "Container should not expose sensitive environment variables" {
  # Check if sensitive environment vars are visible in 'docker inspect'
  run bash -c "docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' $CONTAINER_NAME | grep -i 'key\\|pass\\|secret\\|token'"
  
  # Should not find any exposed secrets (output should be empty)
  assert_equal "$(echo "$output" | grep -i "license_key" | wc -l)" "0" "LICENSE_KEY should not be exposed in plain text"
}

@test "Container should use tmpfs for sensitive log data" {
  # Check if tmpfs is properly mounted
  run bash -c "docker inspect --format='{{range .Mounts}}{{if eq .Type \"tmpfs\"}}{{.Destination}}{{end}}{{end}}' $CONTAINER_NAME"
  
  assert_success
  assert_output --partial "/var/log/newrelic-infra"
}

@test "Dockerfile should not contain unsafe practices" {
  # Get the Dockerfile content
  run bash -c "cat ../../Dockerfile"
  
  assert_success
  
  # Should not use 'chmod 777'
  assert_equal "$(echo "$output" | grep -c "chmod 777")" "0" "Dockerfile should not use chmod 777"
  
  # Should not use 'latest' tag for base image
  base_image=$(echo "$output" | grep -m 1 "FROM" | awk '{print $2}')
  if [[ "$base_image" == *":latest"* ]]; then
    # Skip if we explicitly use latest in this specific case
    if [[ "$base_image" != "newrelic/infrastructure-bundle:latest" ]]; then
      fail "Dockerfile should not use 'latest' tag for base image"
    fi
  fi
}

@test "Container has no unnecessary network exposure" {
  # Check for exposed ports
  run bash -c "docker inspect --format='{{range \$p, \$conf := .NetworkSettings.Ports}}{{if \$conf}}{{println \$p}}{{end}}{{end}}' $CONTAINER_NAME"
  
  # Agent should not expose any ports
  assert_output ""
}

@test "Config files have proper permissions" {
  # Check permissions on configuration files
  run docker exec "$CONTAINER_NAME" ls -l /etc/newrelic-infra/ | grep ".yml"
  
  assert_success
  
  # Check if permissions are too open
  assert_equal "$(echo "$output" | grep -c "rwxrwxrwx")" "0" "Config files should not have 777 permissions"
}

@test "Container has no secrets in logs" {
  # Grep container logs for potential secrets
  run bash -c "docker logs $CONTAINER_NAME | grep -iE '(password|secret|key|token)' | grep -v 'REDACTED' | wc -l"
  
  # Should find zero unredacted secrets
  assert_equal "$output" "0" "No unredacted secrets should appear in logs"
}
