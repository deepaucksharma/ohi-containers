#!/usr/bin/env bash
# Assert functions for testing
# Version: 2.0.0

# Load the bats-assert library if available, otherwise define our own
if [ -n "$BATS_LIB_PATH" ]; then
    load "bats-assert/load"
else
    # Compatibility layer for non-Bats runs
    assert_equal() {
        if [ "$1" != "$2" ]; then
            echo "Assertion failed: '$1' is not equal to '$2'"
            return 1
        fi
        return 0
    }
    
    assert_not_equal() {
        if [ "$1" = "$2" ]; then
            echo "Assertion failed: '$1' should not be equal to '$2'"
            return 1
        fi
        return 0
    }
    
    assert_success() {
        if [ "$status" -ne 0 ]; then
            echo "Assertion failed: Command did not exit with success (got exit code $status)"
            return 1
        fi
        return 0
    }
    
    assert_failure() {
        if [ "$status" -eq 0 ]; then
            echo "Assertion failed: Command did not exit with failure"
            return 1
        fi
        return 0
    }
    
    assert_output() {
        if [ "$1" != "$output" ]; then
            echo "Assertion failed: Output '$output' does not match expected '$1'"
            return 1
        fi
        return 0
    }
    
    assert_contains() {
        if [[ "$2" != *"$1"* ]]; then
            echo "Assertion failed: '$2' does not contain '$1'"
            return 1
        fi
        return 0
    }
    
    refute_output() {
        if [ -n "$output" ]; then
            echo "Assertion failed: Output was not empty: '$output'"
            return 1
        fi
        return 0
    }
fi

# Additional assertions beyond bats-assert

# Assert that a value is less than another
assert_less_than() {
    local actual="$1"
    local expected="$2"
    local message="${3:-"$actual should be less than $expected"}"
    
    if [ "$actual" -ge "$expected" ]; then
        echo "Assertion failed: $message"
        return 1
    fi
    return 0
}

# Assert that a value is greater than another
assert_greater_than() {
    local actual="$1"
    local expected="$2"
    local message="${3:-"$actual should be greater than $expected"}"
    
    if [ "$actual" -le "$expected" ]; then
        echo "Assertion failed: $message"
        return 1
    fi
    return 0
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-"File $file should exist"}"
    
    if [ ! -f "$file" ]; then
        echo "Assertion failed: $message"
        return 1
    fi
    return 0
}

# Assert that a directory exists
assert_dir_exists() {
    local dir="$1"
    local message="${2:-"Directory $dir should exist"}"
    
    if [ ! -d "$dir" ]; then
        echo "Assertion failed: $message"
        return 1
    fi
    return 0
}

# Assert that a string matches a regex pattern
assert_matches() {
    local pattern="$1"
    local string="$2"
    local message="${3:-"$string should match pattern $pattern"}"
    
    if [[ ! "$string" =~ $pattern ]]; then
        echo "Assertion failed: $message"
        return 1
    fi
    return 0
}

# Assert that a command completes within a given timeout
assert_completes_within() {
    local timeout="$1"
    shift
    local cmd="$@"
    local message="Command should complete within $timeout seconds"
    
    local start_time=$(date +%s)
    "$@"
    local status=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $duration -gt $timeout ]; then
        echo "Assertion failed: $message (took $duration seconds)"
        return 1
    fi
    
    return $status
}
