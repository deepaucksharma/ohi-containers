#!/bin/bash
# Main test runner script for Linux
# Runs the unified test runner with all arguments passed through

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTING_DIR="$SCRIPT_DIR/testing"

# Make sure test runner is executable
chmod +x "$TESTING_DIR/bin/unified/test-runner.sh"

# Run the unified test runner with all arguments
"$TESTING_DIR/bin/unified/test-runner.sh" "$@"

# Return the exit code
exit $?
