# New Relic Infrastructure Docker Validation Framework

A platform-independent testing framework for validating Docker images with New Relic Infrastructure.

## Overview

This framework provides a comprehensive set of tests to validate Docker images containing New Relic Infrastructure and database integrations. Tests run on both Windows and Linux environments with the same code base.

## Recent Improvements

The codebase has been streamlined and improved in the following ways:

1. **Unified Test Runner**: All test functionality is now consolidated in a single unified test runner script (`bin/unified/test-runner.sh`).
2. **Improved Docker Configurations**: Docker Compose files now use healthchecks and environment variables for better reliability.
3. **Enhanced Dockerfile**: Optimized Dockerfile with proper healthchecks and best practices.
4. **Consolidated Scripts**: Reduced script duplication and simplified the test execution process.
5. **Environment Variables**: All configuration now uses environment variables from `.env` file.

## Directory Structure

```
docker-validation/
├── bin/                              # Platform-independent executable scripts
│   ├── run-tests.sh                  # Main test runner (POSIX-compliant)
│   ├── setup-environment.sh          # Environment setup script
│   └── cleanup-environment.sh        # Cleanup script
├── configs/                          # Configuration templates
│   ├── newrelic-infra.yml            # Main agent config
│   ├── mysql-config.yml              # MySQL integration config
│   └── postgresql-config.yml         # PostgreSQL integration config
├── docker/                           # Docker-related files
│   ├── Dockerfile                    # Base Dockerfile
│   ├── docker-compose.yml            # Test environment setup
│   └── Dockerfile.alpine             # Alternative lightweight image
├── lib/                              # Shared libraries and utilities
│   ├── common.sh                     # Common utility functions
│   ├── assertions.sh                 # Test assertions
│   └── database_utils.sh             # Database utility functions
├── tests/                            # Test scripts organized by category
│   ├── unit/                         # Unit tests for individual components
│   │   ├── config_parser_test.sh     # Test config file parsing
│   │   └── environment_test.sh       # Test environment variables
│   ├── integration/                  # Integration tests
│   │   ├── db_integration_test.sh    # Database integration test
│   │   └── api_integration_test.sh   # New Relic API integration test
│   ├── security/                     # Security tests
│   │   ├── user_permission_test.sh   # Database user permission tests
│   │   └── network_security_test.sh  # Network security tests
│   ├── performance/                  # Performance tests
│   │   ├── resource_usage_test.sh    # Resource usage tests
│   │   └── load_test.sh              # Load testing
│   ├── image_validation/             # Image validation tests
│   │   ├── layer_test.sh             # Image layer tests
│   │   └── content_test.sh           # Image content tests
│   ├── config_validation/            # Configuration validation tests
│   │   ├── mysql_config_test.sh      # MySQL config validation
│   │   └── pg_config_test.sh         # PostgreSQL config validation
│   ├── run_all_tests.sh              # Test runner for container environment
│   └── output/                       # Test results and logs
├── fixtures/                         # Test fixtures and data
│   ├── mysql/                        # MySQL test data
│   │   └── init.sql                  # MySQL initialization script
│   ├── postgres/                     # PostgreSQL test data
│   │   └── init.sql                  # PostgreSQL initialization script
│   └── wiremock/                     # WireMock fixtures
│       └── mappings/                 # API response mappings
│           └── metrics.json          # Metrics API mapping
├── run-tests.bat                     # Windows test runner wrapper
├── docker-compose.yml                # Main Docker Compose file
└── README.md                         # This documentation file
```

## Getting Started

### Prerequisites

- Docker Engine (Windows or Linux)
- Docker Compose
- Bash-compatible shell (Linux or Git Bash/WSL for Windows)

### Running Tests

#### Unified Test Runner (Recommended)

We've simplified the testing process with a unified test runner that works across platforms:

```bash
# Run all tests (Windows)
test.bat

# Run all tests (Linux/macOS)
./bin/unified/test-runner.sh

# Run specific test category
test.bat --category integration
./bin/unified/test-runner.sh --category integration

# Run with verbose output
test.bat --verbose
./bin/unified/test-runner.sh --verbose

# Skip environment setup/cleanup
test.bat --skip-setup --skip-cleanup
./bin/unified/test-runner.sh --skip-setup --skip-cleanup

# Specify custom output directory
test.bat --output ./custom/path
./bin/unified/test-runner.sh --output ./custom/path
```

#### Legacy Runners (For Backward Compatibility)

```bash
# Linux/macOS
./bin/run-tests.sh [options]

# Windows
run-tests.bat [options]
```

### Test Categories

- **unit**: Basic component tests
- **integration**: Integration tests for databases and APIs
- **security**: Security validation tests
- **performance**: Resource usage and load tests
- **image**: Docker image validation tests
- **config**: Configuration validation tests

## Writing New Tests

To add a new test:

1. Create a new test script in the appropriate category directory
2. Use common utility functions from `lib/common.sh`
3. Use assertion functions from `lib/assertions.sh`
4. Make sure your test script returns 0 on success and non-zero on failure

Example test structure:

```bash
#!/bin/sh
# Test description
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
. "$project_root/lib/common.sh"
. "$project_root/lib/assertions.sh"

# Test functions
test_something() {
  # Test logic
  assert_equals "expected" "actual" "Test message"
}

# Run all tests
run_tests() {
  # Run tests
  test_something
  
  # Print test summary
  print_test_summary
}

# Run tests
run_tests
```

## Platform Independence

The framework is designed to run on both Windows and Linux with the same code:

- All shell scripts use `/bin/sh` instead of `/bin/bash` for compatibility
- Path handling is normalized between platforms
- Docker commands are executed with platform-specific wrappers
- File operations use platform-independent abstractions
- Windows users can run tests via `run-tests.bat` which delegates to shell scripts

## Contact

For questions or issues, please contact your New Relic representative.
