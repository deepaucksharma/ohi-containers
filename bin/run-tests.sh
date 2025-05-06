#!/bin/sh
# Platform-independent test runner
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/.." && pwd)

# Source common utilities
. "$project_root/lib/common.sh"

# Set default variables
TEST_CATEGORIES="all"
VERBOSE=0
SKIP_SETUP=0
SKIP_CLEANUP=0
RESULTS_DIR="$project_root/tests/output/$(date +%Y%m%d%H%M%S)"

# Print usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Run New Relic Infrastructure Docker validation tests"
  echo ""
  echo "Options:"
  echo "  -c, --category CATEGORY  Run specific test category (unit, integration, security,"
  echo "                           performance, image, config, or all) [default: all]"
  echo "  -v, --verbose            Enable verbose output"
  echo "  --skip-setup             Skip environment setup"
  echo "  --skip-cleanup           Skip environment cleanup"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Example:"
  echo "  $0 --category integration --verbose"
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
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

# Setup test environment
setup_environment() {
  if [ $SKIP_SETUP -eq 1 ]; then
    log_message "INFO" "Skipping environment setup as requested"
    return 0
  fi
  
  log_message "INFO" "Setting up test environment"
  
  # Create results directory
  mkdir -p "$RESULTS_DIR"
  log_message "INFO" "Test results will be stored in: $RESULTS_DIR"
  
  # Run setup script if available
  if file_exists "$project_root/bin/setup-environment.sh"; then
    log_message "INFO" "Running environment setup script"
    sh "$project_root/bin/setup-environment.sh"
  else
    # Default setup - start Docker Compose environment
    log_message "INFO" "Starting Docker Compose environment"
    cd "$project_root" || exit 1
    "$(docker_cmd)" compose up -d
    
    # Wait a moment for services to initialize
    log_message "INFO" "Waiting for services to initialize"
    sleep 10
  fi
}

# Run tests from a specific category
run_test_category() {
  local category="$1"
  local test_dir=""
  local description=""
  
  case "$category" in
    unit)
      test_dir="$project_root/tests/unit"
      description="Unit Tests"
      ;;
    integration)
      test_dir="$project_root/tests/integration"
      description="Integration Tests"
      ;;
    security)
      test_dir="$project_root/tests/security"
      description="Security Tests"
      ;;
    performance)
      test_dir="$project_root/tests/performance"
      description="Performance Tests"
      ;;
    image)
      test_dir="$project_root/tests/image_validation"
      description="Image Validation Tests"
      ;;
    config)
      test_dir="$project_root/tests/config_validation"
      description="Configuration Validation Tests"
      ;;
    *)
      log_message "ERROR" "Unknown test category: $category"
      return 1
      ;;
  esac
  
  if ! dir_exists "$test_dir"; then
    log_message "WARN" "Test directory does not exist: $test_dir"
    return 0
  fi
  
  log_message "INFO" "Running $description"
  
  # Find all test scripts in the directory
  for test_script in "$test_dir"/*.sh; do
    if file_exists "$test_script"; then
      run_test_script "$test_script"
    fi
  done
}

# Run a single test script
run_test_script() {
  local test_script="$1"
  local test_name=$(basename "$test_script" .sh)
  local output_file="$RESULTS_DIR/${test_name}.log"
  local start_time=$(date +%s)
  
  log_message "INFO" "Running test: $test_name"
  
  # Make sure the script is executable
  chmod +x "$test_script" 2>/dev/null
  
  # Run the test script
  if [ $VERBOSE -eq 1 ]; then
    # Run with output to console in verbose mode
    sh "$test_script" | tee "$output_file"
    test_result=${PIPESTATUS[0]}
  else
    # Run with output to log file only
    sh "$test_script" > "$output_file" 2>&1
    test_result=$?
  fi
  
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Record test result
  if [ $test_result -eq 0 ]; then
    log_message "INFO" "✅ PASS: $test_name (${duration}s)"
    echo "$test_name,PASS,$duration" >> "$RESULTS_DIR/results.csv"
  else
    log_message "ERROR" "❌ FAIL: $test_name (${duration}s)"
    log_message "ERROR" "  See log: $output_file"
    echo "$test_name,FAIL,$duration" >> "$RESULTS_DIR/results.csv"
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
  
  # Run cleanup script if available
  if file_exists "$project_root/bin/cleanup-environment.sh"; then
    log_message "INFO" "Running environment cleanup script"
    sh "$project_root/bin/cleanup-environment.sh"
  else
    # Default cleanup - stop Docker Compose environment
    log_message "INFO" "Stopping Docker Compose environment"
    cd "$project_root" || exit 1
    "$(docker_cmd)" compose down
  fi
}

# Generate test summary
generate_summary() {
  local results_file="$RESULTS_DIR/results.csv"
  
  if ! file_exists "$results_file"; then
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
  cat > "$RESULTS_DIR/summary.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "total_tests": $total,
  "passed": $passed,
  "failed": $failed,
  "results_directory": "$RESULTS_DIR"
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
  log_message "INFO" "===================================================="
  log_message "INFO" "Starting New Relic Infrastructure Docker Test Suite"
  log_message "INFO" "Platform: $(detect_platform)"
  log_message "INFO" "===================================================="
  
  # Parse command line arguments
  parse_args "$@"
  
  # Create header for results file
  mkdir -p "$RESULTS_DIR"
  echo "test_name,result,duration_seconds" > "$RESULTS_DIR/results.csv"
  
  # Setup test environment
  setup_environment
  
  # Initialize result tracking
  FAILED_TESTS=0
  
  # Run tests based on category
  if [ "$TEST_CATEGORIES" = "all" ]; then
    # Run all test categories
    for category in unit integration security performance image config; do
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
  
  # Exit with failure if any tests failed
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
