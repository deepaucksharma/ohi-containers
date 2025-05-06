#!/bin/sh
# Test assertion functions for platform-independent testing
# Version: 1.0.0

# Source common utilities
script_dir=$(dirname "$0")
. "$script_dir/common.sh"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test result tracking
TEST_PASS_COUNT=0
TEST_FAIL_COUNT=0

# Assert equality
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected' but got '$actual'}"
  
  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Expected: '$expected'"
    echo -e "  Actual:   '$actual'"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert inequality
assert_not_equals() {
  local unexpected="$1"
  local actual="$2"
  local message="${3:-Expected a value different from '$unexpected'}"
  
  if [ "$unexpected" != "$actual" ]; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Expected anything but: '$unexpected'"
    echo -e "  Actual:               '$actual'"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert string contains substring
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Expected string to contain '$needle'}"
  
  if echo "$haystack" | grep -q "$needle"; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  String:    '$haystack'"
    echo -e "  Should contain: '$needle'"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert file contains substring
assert_file_contains() {
  local file_path="$1"
  local needle="$2"
  local message="${3:-Expected file to contain '$needle'}"
  
  if [ ! -f "$file_path" ]; then
    echo -e "${RED}✗ FAIL: File does not exist: $file_path${NC}"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
  
  if grep -q "$needle" "$file_path"; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  File: $file_path"
    echo -e "  Should contain: '$needle'"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert numeric comparison (less than)
assert_less_than() {
  local value="$1"
  local max="$2"
  local message="${3:-Expected value less than $max, got $value}"
  
  if [ "$value" -lt "$max" ]; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Expected value less than: $max"
    echo -e "  Actual value:            $value"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert numeric comparison (greater than)
assert_greater_than() {
  local value="$1"
  local min="$2"
  local message="${3:-Expected value greater than $min, got $value}"
  
  if [ "$value" -gt "$min" ]; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Expected value greater than: $min"
    echo -e "  Actual value:                $value"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert command succeeds
assert_command_succeeds() {
  local command="$1"
  local message="${2:-Expected command to succeed: '$command'}"
  
  if eval "$command" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  else
    local exit_code=$?
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Command failed with exit code: $exit_code"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  fi
}

# Assert command fails
assert_command_fails() {
  local command="$1"
  local message="${2:-Expected command to fail: '$command'}"
  
  if eval "$command" > /dev/null 2>&1; then
    echo -e "${RED}✗ FAIL: $message${NC}"
    echo -e "  Command unexpectedly succeeded"
    TEST_FAIL_COUNT=$((TEST_FAIL_COUNT+1))
    return 1
  else
    echo -e "${GREEN}✓ PASS: $message${NC}"
    TEST_PASS_COUNT=$((TEST_PASS_COUNT+1))
    return 0
  fi
}

# Print test summary
print_test_summary() {
  local total=$((TEST_PASS_COUNT + TEST_FAIL_COUNT))
  echo "-----------------------------------"
  echo "Test Summary:"
  echo "  Total:  $total"
  echo -e "  ${GREEN}Passed: $TEST_PASS_COUNT${NC}"
  echo -e "  ${RED}Failed: $TEST_FAIL_COUNT${NC}"
  echo "-----------------------------------"
  
  if [ $TEST_FAIL_COUNT -eq 0 ]; then
    return 0
  else
    return 1
  fi
}
