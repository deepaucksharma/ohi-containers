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
COMPOSE_HELPER="$SCRIPT_DIR/scripts/compose-helper.sh"

# Make sure helper script is executable
chmod +x "$COMPOSE_HELPER" 2>/dev/null || true

# Set up environment variable for license key if not present
if [ -z "$NEW_RELIC_LICENSE_KEY" ]; then
  export NEW_RELIC_LICENSE_KEY="dummy012345678901234567890123456789"
  echo "WARNING: Using dummy license key for testing. Set NEW_RELIC_LICENSE_KEY for production use."
fi

# Parse command line arguments
CATEGORY=""
TEST=""
VERBOSE=0
SKIP_SETUP=0
SKIP_CLEANUP=0
BUILD_ONLY=0

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
    --skip-setup)
      SKIP_SETUP=1
      shift
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=1
      shift
      ;;
    --build-only)
      BUILD_ONLY=1
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--category CATEGORY] [--test TEST_NAME] [--verbose] [--skip-setup] [--skip-cleanup] [--build-only]"
      exit 1
      ;;
  esac
done

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check if Docker Compose is available via our helper
if ! "$COMPOSE_HELPER" version >/dev/null 2>&1; then
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

# Build Docker image first
if [ "$SKIP_SETUP" -eq 0 ] || [ "$BUILD_ONLY" -eq 1 ]; then
  echo "Building Docker image..."
  docker build -t newrelic-infra:latest "$SCRIPT_DIR"
  
  if [ "$BUILD_ONLY" -eq 1 ]; then
    echo "Build only mode - exiting."
    exit 0
  fi
fi

# Start containers if needed
if [ "$SKIP_SETUP" -eq 0 ]; then
  echo "Starting Docker containers..."
  "$COMPOSE_HELPER" -f "$SCRIPT_DIR/docker-compose.yml" up -d
  
  echo "Waiting for containers to be healthy..."
  timeout_seconds=300
  start_time=$(date +%s)
  
  while true; do
    healthy_count=$(docker ps --format "{{.Status}}" | grep -c "(healthy)" || echo "0")
    container_count=$(docker ps --format "{{.Names}}" | grep -c "test-" || echo "0")
    
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ "$healthy_count" -ge "$container_count" ] && [ "$container_count" -gt 0 ]; then
      echo "All containers are healthy! ($healthy_count/$container_count)"
      break
    fi
    
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      echo "Timeout waiting for containers to be healthy."
      docker ps
      exit 1
    fi
    
    echo "Waiting for containers to be healthy... ($healthy_count/$container_count) - $elapsed/$timeout_seconds seconds"
    sleep 5
  done
fi

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

TEST_EXIT_CODE=$?

# Clean up containers if not skipped
if [ "$SKIP_CLEANUP" -eq 0 ]; then
  echo "Cleaning up Docker containers..."
  "$COMPOSE_HELPER" -f "$SCRIPT_DIR/docker-compose.yml" down -v
fi

# Return the exit code from the tests
exit $TEST_EXIT_CODE
