#!/bin/bash
# Unified Test Runner for Linux/macOS
# This calls the platform-independent test runner script

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Forward all arguments to the unified test runner
echo "Running test runner with arguments: $@"
cd "$PROJECT_ROOT"
"$PROJECT_ROOT/testing/bin/unified/test-runner.sh" "$@"

# Return the exit code from the test runner
exit $?
