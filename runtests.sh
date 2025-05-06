#!/bin/sh
# Cross-platform test runner script
# Runs the unified test runner with all arguments passed through

# Determine script directory in a platform-independent way
if [ -n "$BASH_SOURCE" ]; then
  # For Bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # For other shells
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

TESTING_DIR="$SCRIPT_DIR/testing"
TEST_RUNNER="$TESTING_DIR/tests/run_all_tests.sh"

# Set up environment variable for license key if not present
if [ -z "$NEW_RELIC_LICENSE_KEY" ]; then
  export NEW_RELIC_LICENSE_KEY="dummy012345678901234567890123456789"
  echo "WARNING: Using dummy license key for testing. Set NEW_RELIC_LICENSE_KEY for production use."
fi

# Parse command line arguments
CATEGORY=""
TEST=""
VERBOSE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    --test)
      TEST="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--category CATEGORY] [--test TEST_NAME] [--verbose]"
      exit 1
      ;;
  esac
done

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if Docker Compose is available
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose is not available. Please install Docker Compose and try again."
  exit 1
fi

# Make sure test directory exists
if [ ! -d "$TESTING_DIR" ]; then
  echo "ERROR: Testing directory not found at $TESTING_DIR"
  exit 1
fi

# Make sure test runner is executable
chmod +x "$TEST_RUNNER" 2>/dev/null || true

# If specific category is requested, create a filter
if [ -n "$CATEGORY" ]; then
  if [ -n "$TEST" ]; then
    echo "Running specific test: $CATEGORY/$TEST"
    docker exec test-runner sh -c "/testing/tests/$CATEGORY/$TEST.sh"
  else
    echo "Running category: $CATEGORY"
    docker exec test-runner sh -c "cd /testing && /testing/tests/run_all_tests.sh --category $CATEGORY"
  fi
else
  echo "Running all tests..."
  docker exec test-runner sh -c "cd /testing && /testing/tests/run_all_tests.sh"
fi

# Return the exit code
exit $?
