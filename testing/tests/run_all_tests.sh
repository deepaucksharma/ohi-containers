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
TEST_RUN_ID=$(date +%Y%m%d%H%M%S 2>/dev/null || echo "$(date)")
START_TIME=$(date +%s 2>/dev/null || echo "0")

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

echo "======================================================"
echo "🚀 Starting New Relic Infrastructure Image Test Suite"
echo "======================================================"
echo "Test Run ID: $TEST_RUN_ID"
echo "Timestamp: $(date)"
echo "Platform: $(detect_platform)"
if [ -n "$CATEGORY" ]; then
  echo "Category Filter: $CATEGORY"
fi
if [ -n "$TEST" ]; then
  echo "Test Filter: $TEST"
fi
echo

# Create results directory
RESULTS_DIR="/output/${TEST_RUN_ID}"
mkdir -p "$RESULTS_DIR" 2>/dev/null || {
  RESULTS_DIR="/tmp/${TEST_RUN_ID}"
  mkdir -p "$RESULTS_DIR"
  echo "NOTE: Using temporary directory for results: $RESULTS_DIR"
}

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
        chmod +x "$test_file" 2>/dev/null || true
        
        output_file="${RESULTS_DIR}/${test_name}.log"
        if sh "$test_file" > "$output_file" 2>&1; then
            echo -e "${GREEN}✓ PASSED: $test_name${NC}"
            PASSED=$((PASSED+1))
        else
            echo -e "${RED}✗ FAILED: $test_name (Exit code: $?)${NC}"
            echo -e "${RED}  See log: $output_file${NC}"
            FAILED=$((FAILED+1))
            
            # Print last few lines of output on failure for convenience
            echo -e "${RED}Last 5 lines of output:${NC}"
            tail -n 5 "$output_file" 2>/dev/null | sed 's/^/  /' || cat "$output_file" | sed 's/^/  /'
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
    
    # Skip if a specific category filter is set and doesn't match
    if [ -n "$CATEGORY" ] && [ "$CATEGORY" != "$category" ] && [ "$CATEGORY" != "$(echo "$category" | tr '[:upper:]' '[:lower:]')" ]; then
        if [ "$VERBOSE" -eq 1 ]; then
            echo "Skipping category: $category (filter: $CATEGORY)"
        fi
        return 0
    fi
    
    echo "📋 Running $category tests..."
    
    if [ -d "$category_dir" ]; then
        if [ -n "$TEST" ]; then
            # Run only the specific test if TEST is specified
            test_file="${category_dir}/${TEST}.sh"
            if [ -f "$test_file" ]; then
                run_test "$test_file"
            else
                echo -e "${YELLOW}⚠ Test not found: $TEST in category $category${NC}"
            fi
        else
            # Run all tests in the category
            for test in "$category_dir"/*.sh; do
                if [ -f "$test" ]; then
                    run_test "$test"
                fi
            done
        fi
    else
        echo -e "${YELLOW}⚠ No tests found in directory: $category_dir${NC}"
    fi
    
    echo
}

# Run all test categories
if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "unit" ]; then
    run_test_category "Unit" "$script_dir/unit"
fi

if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "image_validation" ]; then
    run_test_category "Image Validation" "$script_dir/image_validation"
fi

if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "config_validation" ]; then
    run_test_category "Configuration Validation" "$script_dir/config_validation"
fi

if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "integration" ]; then
    run_test_category "Integration" "$script_dir/integration"
    # Also run sub-categories of integration
    if [ -d "$script_dir/integration/mysql" ]; then
        run_test_category "Integration - MySQL" "$script_dir/integration/mysql"
    fi
    if [ -d "$script_dir/integration/postgres" ]; then
        run_test_category "Integration - PostgreSQL" "$script_dir/integration/postgres"
    fi
fi

if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "security" ]; then
    run_test_category "Security" "$script_dir/security"
fi

if [ -z "$CATEGORY" ] || [ "$CATEGORY" = "performance" ]; then
    run_test_category "Performance" "$script_dir/performance"
fi

# Calculate execution time
if [ "$START_TIME" != "0" ]; then
    END_TIME=$(date +%s 2>/dev/null || echo "$START_TIME")
    DURATION=$((END_TIME - START_TIME))
else
    DURATION=0
fi

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
  "timestamp": "$(date -Iseconds 2>/dev/null || echo "$(date)")",
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
