#!/bin/sh
# Unit tests for environment variable handling
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
if [ -f "$testing_root/lib/common.sh" ]; then
  . "$testing_root/lib/common.sh"
elif [ -f "/app/testing/lib/common.sh" ]; then
  . "/app/testing/lib/common.sh"
else
  echo "ERROR: Cannot find common.sh at $testing_root/lib/common.sh"
  # Try alternative path for Docker environment
  if [ -f "/workspace/testing/lib/common.sh" ]; then
    . "/workspace/testing/lib/common.sh"
  else
    echo "ERROR: Cannot find common.sh at /workspace/testing/lib/common.sh either"
    exit 1
  fi
fi

if [ -f "$testing_root/lib/assertions.sh" ]; then
  . "$testing_root/lib/assertions.sh"
elif [ -f "/app/testing/lib/assertions.sh" ]; then
  . "/app/testing/lib/assertions.sh"
else
  echo "ERROR: Cannot find assertions.sh at $testing_root/lib/assertions.sh"
  # Try alternative path for Docker environment
  if [ -f "/workspace/testing/lib/assertions.sh" ]; then
    . "/workspace/testing/lib/assertions.sh"
  else
    echo "ERROR: Cannot find assertions.sh at /workspace/testing/lib/assertions.sh either"
    exit 1
  fi
fi

# Helper function to get environment variables with defaults
get_env() {
  local var_name="$1"
  local default_value="$2"
  local value
  
  # Get environment variable value
  eval value=\$$var_name
  
  # Return default if environment variable is not set
  if [ -z "$value" ]; then
    echo "$default_value"
  else
    echo "$value"
  fi
}

# Helper function to validate environment variables
validate_env() {
  local var_name="$1"
  local pattern="$2"
  local value
  
  # Get environment variable value
  eval value=\$$var_name
  
  # Check if value matches pattern
  echo "$value" | grep -E "$pattern" >/dev/null 2>&1
}

# Test getting environment variables with defaults
test_get_env_with_defaults() {
  log_message "INFO" "Testing getting environment variables with defaults"
  
  # Set test environment variables
  export TEST_VAR1="test_value"
  export TEST_VAR2=""
  
  # Test existing variable
  local result=$(get_env "TEST_VAR1" "default_value")
  assert_equals "test_value" "$result" "Failed to get existing environment variable"
  
  # Test empty variable
  local result=$(get_env "TEST_VAR2" "default_value")
  assert_equals "default_value" "$result" "Failed to get default for empty environment variable"
  
  # Test non-existent variable
  local result=$(get_env "TEST_NONEXISTENT" "default_value")
  assert_equals "default_value" "$result" "Failed to get default for non-existent environment variable"
  
  # Clean up test environment variables
  unset TEST_VAR1
  unset TEST_VAR2
}

# Test validating environment variables
test_validate_env() {
  log_message "INFO" "Testing validating environment variables"
  
  # Set test environment variables
  export TEST_LICENSE="0123456789012345678901234567890123456789"
  export TEST_PORT="3306"
  export TEST_HOST="localhost"
  export TEST_INVALID="not-a-number"
  
  # Test license key format (40 character alphanumeric)
  validate_env "TEST_LICENSE" "^[a-zA-Z0-9]{40}$"
  assert_equals 0 $? "Failed to validate license key format"
  
  # Test port number format (numeric)
  validate_env "TEST_PORT" "^[0-9]+$"
  assert_equals 0 $? "Failed to validate port number format"
  
  # Test hostname format (alphanumeric with periods and hyphens)
  validate_env "TEST_HOST" "^[a-zA-Z0-9.-]+$"
  assert_equals 0 $? "Failed to validate hostname format"
  
  # Test invalid format (should not be numeric)
  validate_env "TEST_INVALID" "^[0-9]+$"
  assert_equals 1 $? "Failed to reject invalid format"
  
  # Clean up test environment variables
  unset TEST_LICENSE
  unset TEST_PORT
  unset TEST_HOST
  unset TEST_INVALID
}

# Test platform-independent environment variables
test_platform_environment() {
  log_message "INFO" "Testing platform-independent environment variables"
  
  # Detect platform
  local platform=$(detect_platform)
  
  # Test temporary directory
  local temp_dir=$(get_temp_dir)
  assert_command_succeeds "[ -d \"$temp_dir\" ]" "Temporary directory does not exist: $temp_dir"
  
  # Test platform-specific command execution
  if [ "$platform" = "windows" ]; then
    # Windows-specific test
    assert_command_succeeds "cmd.exe /c echo Test > NUL" "Command execution failed on Windows"
  else
    # Unix-specific test
    assert_command_succeeds "sh -c 'echo Test > /dev/null'" "Command execution failed on Unix"
  fi
}

# Run all tests
run_tests() {
  # Run tests
  test_get_env_with_defaults
  test_validate_env
  test_platform_environment
  
  # Print test summary
  print_test_summary
}

# Run tests
run_tests
