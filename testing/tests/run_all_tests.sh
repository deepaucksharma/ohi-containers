#!/bin/sh
# Main test runner script
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
testing_root=$(cd "$script_dir/.." && pwd)

# Source test utilities
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test run ID
TEST_RUN_ID=$(date +%Y%m%d%H%M%S)
START_TIME=$(date +%s)

echo "======================================================"
echo "🚀 Starting New Relic Infrastructure Image Test Suite"
echo "======================================================"
echo "Test Run ID: $TEST_RUN_ID"
echo "Timestamp: $(date)"
echo "Platform: $(detect_platform)"
echo

# Create results directory
RESULTS_DIR="/output/${TEST_RUN_ID}"
mkdir -p "$RESULTS_DIR"

# Track test results
PASSED=0
FAILED=0
SKIPPED=0

# Execute a test and track its result
run_test() {
    test_file=$1
    test_name=$(basename "$test_file" .sh)
    echo -e "${YELLOW}► Running test: $test_name${NC}"
    
    if [ -x "$test_file" ] || [ -f "$test_file" ]; then
        # Make test file executable if it isn't already
        chmod +x "$test_file" 2>/dev/null
        
        output_file="${RESULTS_DIR}/${test_name}.log"
        if "$test_file" > "$output_file" 2>&1; then
            echo -e "${GREEN}✓ PASSED: $test_name${NC}"
            PASSED=$((PASSED+1))
        else
            echo -e "${RED}✗ FAILED: $test_name (Exit code: $?)${NC}"
            echo -e "${RED}  See log: $output_file${NC}"
            FAILED=$((FAILED+1))
            
            # Print last few lines of output on failure for convenience
            echo -e "${RED}Last 5 lines of output:${NC}"
            tail -n 5 "$output_file" | sed 's/^/  /'
            echo
        fi
    else
        echo -e "${YELLOW}⚠ SKIPPED: $test_name (Not found or not executable)${NC}"
        SKIPPED=$((SKIPPED+1))
    fi
    echo
}

# Run tests for a specific category
run_test_category() {
    category=$1
    category_dir=$2
    
    echo "📋 Running $category tests..."
    
    if [ -d "$category_dir" ]; then
        for test in "$category_dir"/*.sh; do
            if [ -f "$test" ]; then
                run_test "$test"
            fi
        done
    else
        echo -e "${YELLOW}⚠ No tests found in directory: $category_dir${NC}"
    fi
    
    echo
}

# 1. Run unit tests
run_test_category "Unit" "$script_dir/unit"

# 2. Run image validation tests
run_test_category "Image Validation" "$script_dir/image_validation"

# 3. Run configuration validation tests
run_test_category "Configuration Validation" "$script_dir/config_validation"

# 4. Run integration tests
run_test_category "Integration" "$script_dir/integration"

# 5. Run security tests
run_test_category "Security" "$script_dir/security"

# 6. Run performance tests
run_test_category "Performance" "$script_dir/performance"

# Calculate execution time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Generate summary report
echo "======================================================"
echo "📊 Test Summary"
echo "======================================================"
echo "Total tests: $((PASSED + FAILED + SKIPPED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo "Duration: $DURATION seconds"
echo

# Generate summary report file
cat > "${RESULTS_DIR}/summary.json" << EOF
{
  "test_run_id": "$TEST_RUN_ID",
  "timestamp": "$(date -Iseconds)",
  "platform": "$(detect_platform)",
  "duration_seconds": $DURATION,
  "total_tests": $((PASSED + FAILED + SKIPPED)),
  "passed": $PASSED,
  "failed": $FAILED,
  "skipped": $SKIPPED
}
EOF

# Exit with failure if any tests failed
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Some tests failed. Check logs for details.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All tests passed successfully!${NC}"
    exit 0
fi
