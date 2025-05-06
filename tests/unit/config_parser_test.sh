#!/bin/sh
# Unit tests for configuration parsing
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
if [ -f "$project_root/lib/common.sh" ]; then
  . "$project_root/lib/common.sh"
else
  echo "ERROR: Cannot find common.sh at $project_root/lib/common.sh"
  # Try alternative path for Docker environment
  if [ -f "/workspace/lib/common.sh" ]; then
    . "/workspace/lib/common.sh"
  else
    echo "ERROR: Cannot find common.sh at /workspace/lib/common.sh either"
    exit 1
  fi
fi

if [ -f "$project_root/lib/assertions.sh" ]; then
  . "$project_root/lib/assertions.sh"
else
  echo "ERROR: Cannot find assertions.sh at $project_root/lib/assertions.sh"
  # Try alternative path for Docker environment
  if [ -f "/workspace/lib/assertions.sh" ]; then
    . "/workspace/lib/assertions.sh"
  else
    echo "ERROR: Cannot find assertions.sh at /workspace/lib/assertions.sh either"
    exit 1
  fi
fi

# Setup: Create a temporary config file for testing
setup() {
  temp_dir=$(get_temp_dir)
  test_config_file="$temp_dir/newrelic-test-config.yml"
  
  cat > "$test_config_file" << EOF
# Test configuration file
license_key: test_license_key
log_level: info

# Integration settings
integration:
  name: mysql
  host: localhost
  port: 3306
  user: newrelic
  password: test_password

# Advanced settings
advanced:
  metrics:
    enabled: true
    interval: 15
  security:
    ssl: true
    verify_hostname: false
EOF
}

# Helper function to parse config files (simulating the actual implementation)
parse_config() {
  local config_file="$1"
  local key="$2"
  
  # Simple YAML parser using grep and sed
  # In a real implementation, you'd use a proper YAML parser
  case "$key" in
    *"."*)
      # Handle nested keys with . separator
      local parent_key="${key%%.*}"
      local child_key="${key#*.}"
      local section_content
      
      # Extract section between parent_key and next section
      section_content=$(sed -n "/^$parent_key:/,/^[a-z]/{/^[a-z]/!p}" "$config_file")
      
      # Extract value for child key from section
      echo "$section_content" | grep "^\s*$child_key:" | sed 's/[^:]*:\s*//' | sed 's/\s*#.*//'
      ;;
    *)
      # Handle top-level keys
      grep "^$key:" "$config_file" | sed 's/[^:]*:\s*//' | sed 's/\s*#.*//'
      ;;
  esac
}

# Test parsing top-level configuration values
test_parse_top_level_config() {
  log_message "INFO" "Testing parsing of top-level configuration values"
  
  # Test license_key
  local result=$(parse_config "$test_config_file" "license_key")
  assert_equals "test_license_key" "$result" "Failed to parse license_key"
  
  # Test log_level
  local result=$(parse_config "$test_config_file" "log_level")
  assert_equals "info" "$result" "Failed to parse log_level"
}

# Test parsing nested configuration values
test_parse_nested_config() {
  log_message "INFO" "Testing parsing of nested configuration values"
  
  # Test integration.name
  local result=$(parse_config "$test_config_file" "integration.name")
  assert_equals "mysql" "$result" "Failed to parse integration.name"
  
  # Test integration.port
  local result=$(parse_config "$test_config_file" "integration.port")
  assert_equals "3306" "$result" "Failed to parse integration.port"
  
  # Test advanced.metrics.interval
  local result=$(parse_config "$test_config_file" "advanced.metrics.interval")
  assert_equals "15" "$result" "Failed to parse advanced.metrics.interval"
}

# Test handling of missing configuration values
test_parse_missing_config() {
  log_message "INFO" "Testing handling of missing configuration values"
  
  # Test non-existent key
  local result=$(parse_config "$test_config_file" "nonexistent_key")
  assert_equals "" "$result" "Failed to handle missing key"
  
  # Test non-existent nested key
  local result=$(parse_config "$test_config_file" "integration.nonexistent")
  assert_equals "" "$result" "Failed to handle missing nested key"
}

# Cleanup function
cleanup() {
  log_message "INFO" "Cleaning up test resources"
  rm -f "$test_config_file"
}

# Run all tests
run_tests() {
  # Setup test environment
  setup
  
  # Run tests
  test_parse_top_level_config
  test_parse_nested_config
  test_parse_missing_config
  
  # Cleanup
  cleanup
  
  # Print test summary
  print_test_summary
}

# Run tests
run_tests
