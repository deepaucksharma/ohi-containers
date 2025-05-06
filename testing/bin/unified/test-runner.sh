#!/bin/bash
# Unified test runner for New Relic Infrastructure Docker Tests
# This script consolidates functionality from multiple test scripts

# Set default values
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TESTING_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$TESTING_ROOT/lib"
TEST_DIR="$TESTING_ROOT/tests"
OUTPUT_DIR="${TEST_OUTPUT_DIR:-$TESTING_ROOT/output}"
TEST_CATEGORIES="all"
VERBOSE=0
SKIP_SETUP=0
SKIP_CLEANUP=0
RUN_ID=$(date +%Y%m%d%H%M%S)

# Load common libraries
source "$LIB_DIR/common.sh"

# Print banner
print_banner() {
  echo "======================================================"
  echo "   New Relic Infrastructure Docker Test Suite"
  echo "   Date: $(date)"
  echo "   Run ID: $RUN_ID"
  echo "======================================================"
}

# Print usage information
show_usage() {
  echo "Usage: $(basename $0) [OPTIONS]"
  echo "Run New Relic Infrastructure Docker test suite"
  echo ""
  echo "Options:"
  echo "  -c, --category CATEGORY  Test category to run (unit, integration, security,"
  echo "                           performance, image, config, db_monitoring, or all) [default: all]"
  echo "  -v, --verbose            Enable verbose output"
  echo "  --skip-setup             Skip environment setup"
  echo "  --skip-cleanup           Skip environment cleanup"
  echo "  -o, --output DIR         Custom output directory"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Example:"
  echo "  $(basename $0) --category integration --verbose"
}

# Parse command line arguments
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -c|--category)
        TEST_CATEGORIES="$2"
        shift 2
        ;;
      -v|--verbose)
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
      -o|--output)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      -h|--help)
        show_usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        show_usage
        exit 1
        ;;
    esac
  done
}

# Setup the environment
setup_environment() {
  if [ $SKIP_SETUP -eq 1 ]; then
    log_message "INFO" "Skipping environment setup as requested"
    return 0
  fi
  
  log_message "INFO" "Setting up test environment"
  
  # Create output directory
  mkdir -p "$OUTPUT_DIR"
  log_message "INFO" "Test results will be stored in: $OUTPUT_DIR"
  
  # Start Docker Compose environment
  if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    log_message "INFO" "Starting Docker Compose environment"
    cd "$PROJECT_ROOT" || exit 1
    docker compose up -d
    
    # Wait for services to initialize
    log_message "INFO" "Waiting for services to initialize..."
    sleep 10
  else
    log_message "ERROR" "Docker Compose file not found"
    exit 1
  fi
}

# Run tests for a specific category
run_test_category() {
  local category="$1"
  local test_dir=""
  local description=""
  
  case "$category" in
    unit)
      test_dir="$TEST_DIR/unit"
      description="Unit Tests"
      ;;
    integration)
      test_dir="$TEST_DIR/integration"
      description="Integration Tests"
      ;;
    security)
      test_dir="$TEST_DIR/security"
      description="Security Tests"
      ;;
    performance)
      test_dir="$TEST_DIR/performance"
      description="Performance Tests"
      ;;
    image)
      test_dir="$TEST_DIR/image_validation"
      description="Image Validation Tests"
      ;;
    config)
      test_dir="$TEST_DIR/config_validation"
      description="Configuration Validation Tests"
      ;;
    db_monitoring)
      test_dir="$TEST_DIR/db_monitoring"
      description="Database Monitoring Tests"
      ;;
    *)
      log_message "ERROR" "Unknown test category: $category"
      return 1
      ;;
  esac
  
  if [ ! -d "$test_dir" ]; then
    log_message "WARN" "Test directory does not exist: $test_dir"
    return 0
  fi
  
  log_message "INFO" "Running $description"
  
  # Find and run test scripts
  for test_script in "$test_dir"/*.sh; do
    if [ -f "$test_script" ]; then
      run_test_script "$test_script"
    fi
  done
}

# Run a single test script
run_test_script() {
  local test_script="$1"
  local test_name=$(basename "$test_script" .sh)
  local output_file="$OUTPUT_DIR/${test_name}_${RUN_ID}.log"
  local start_time=$(date +%s)
  
  log_message "INFO" "Running test: $test_name"
  
  # Make sure the script is executable
  chmod +x "$test_script" 2>/dev/null
  
  # Run the test script
  if [ $VERBOSE -eq 1 ]; then
    # Run with output to console in verbose mode
    bash "$test_script" | tee "$output_file"
    test_result=${PIPESTATUS[0]}
  else
    # Run with output to log file only
    bash "$test_script" > "$output_file" 2>&1
    test_result=$?
  fi
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Record test result
  if [ $test_result -eq 0 ]; then
    log_message "INFO" "✅ PASS: $test_name (${duration}s)"
    echo "$test_name,PASS,$duration" >> "$OUTPUT_DIR/results_${RUN_ID}.csv"
  else
    log_message "ERROR" "❌ FAIL: $test_name (${duration}s)"
    log_message "ERROR" "  See log: $output_file"
    echo "$test_name,FAIL,$duration" >> "$OUTPUT_DIR/results_${RUN_ID}.csv"
  fi
  
  return $test_result
}

# Cleanup test environment
cleanup_environment() {
  if [ $SKIP_CLEANUP -eq 1 ]; then
    log_message "INFO" "Skipping environment cleanup as requested"
    return 0
  fi
  
  log_message "INFO" "Cleaning up test environment"
  
  # Stop Docker Compose environment
  if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    log_message "INFO" "Stopping Docker Compose environment"
    cd "$PROJECT_ROOT" || exit 1
    docker compose down
  fi
}

# Generate test summary
generate_summary() {
  local results_file="$OUTPUT_DIR/results_${RUN_ID}.csv"
  
  if [ ! -f "$results_file" ]; then
    log_message "ERROR" "No test results found"
    return 1
  fi
  
  local total=$(wc -l < "$results_file")
  local passed=$(grep ",PASS," "$results_file" | wc -l)
  local failed=$(grep ",FAIL," "$results_file" | wc -l)
  
  log_message "INFO" "--------------------------------------------"
  log_message "INFO" "Test Summary"
  log_message "INFO" "--------------------------------------------"
  log_message "INFO" "Total tests: $total"
  log_message "INFO" "Passed: $passed"
  log_message "INFO" "Failed: $failed"
  log_message "INFO" "--------------------------------------------"
  
  # Generate JSON summary
  cat > "$OUTPUT_DIR/summary_${RUN_ID}.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "run_id": "$RUN_ID",
  "total_tests": $total,
  "passed": $passed,
  "failed": $failed,
  "results_directory": "$OUTPUT_DIR"
}
EOF
  
  # Return 1 if any tests failed
  if [ $failed -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# Main function
main() {
  print_banner
  
  # Parse command line arguments
  parse_args "$@"
  
  # Create header for results file
  mkdir -p "$OUTPUT_DIR"
  echo "test_name,result,duration_seconds" > "$OUTPUT_DIR/results_${RUN_ID}.csv"
  
  # Setup test environment
  setup_environment
  
  # Initialize result tracking
  FAILED_TESTS=0
  
  # Run tests based on category
  if [ "$TEST_CATEGORIES" = "all" ]; then
    # Run all test categories
    for category in unit integration security performance image config db_monitoring; do
      run_test_category "$category"
      FAILED_TESTS=$((FAILED_TESTS + $?))
    done
  else
    # Run specific test category
    run_test_category "$TEST_CATEGORIES"
    FAILED_TESTS=$?
  fi
  
  # Generate summary
  generate_summary
  
  # Cleanup test environment
  cleanup_environment
  
  # Print result message
  if [ $FAILED_TESTS -gt 0 ]; then
    log_message "ERROR" "❌ Some tests failed. Check logs for details."
    exit 1
  else
    log_message "INFO" "✅ All tests passed successfully!"
    exit 0
  fi
}

# Run main function
main "$@"
