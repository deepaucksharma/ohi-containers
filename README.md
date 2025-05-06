# New Relic Infrastructure Docker Validation Framework

A platform-independent testing framework for validating Docker images with New Relic Infrastructure.

## Overview

This framework provides a comprehensive set of tests to validate Docker images containing New Relic Infrastructure and database integrations. Tests run on both Windows and Linux environments with the same code base.

## Recent Improvements

The codebase has been streamlined and improved in the following ways:

1. **Unified Test Runner**: All test functionality is now consolidated in a single unified test runner script.
2. **Improved Docker Configurations**: Docker Compose files now use healthchecks and environment variables for better reliability.
3. **Enhanced Dockerfile**: Optimized Dockerfile with proper healthchecks and best practices.
4. **Consolidated Scripts**: Reduced script duplication and simplified the test execution process.
5. **Environment Variables**: All configuration now uses environment variables from `.env` file.
6. **Organized Project Structure**: Cleaner separation between Docker setup and testing infrastructure.

## Project Structure

```
docker/                              # Root directory
├── .env                             # Environment variables
├── .github/                         # GitHub workflow configurations
├── configs/                         # Configuration templates
│   ├── newrelic-infra.yml           # Main agent config
│   ├── mysql-config.yml             # MySQL integration config
│   └── postgresql-config.yml        # PostgreSQL integration config
├── docker-compose.yml               # Main Docker Compose file
├── Dockerfile                       # Main Dockerfile
├── kubernetes/                      # Kubernetes configurations
├── README.md                        # This documentation file
├── runtests.bat                     # Windows test runner wrapper
├── runtests.sh                      # Linux test runner wrapper
├── scripts/                         # Operational scripts
│   └── healthcheck.sh               # Container health check
└── testing/                         # All testing-related code
    ├── bin/                         # Test runner scripts
    │   ├── cleanup-environment.sh   # Environment cleanup script
    │   ├── setup-environment.sh     # Environment setup script
    │   └── unified/                 # Unified test runner
    │       └── test-runner.sh       # Core test runner implementation
    ├── docker-compose-test.yml      # Testing-specific Docker Compose
    ├── fixtures/                    # Test data fixtures
    ├── lib/                         # Testing libraries
    │   ├── assertions.sh            # Test assertions
    │   ├── common.sh                # Common utility functions
    │   └── database_utils.sh        # Database utility functions
    ├── output/                      # Test output directory
    ├── runners/                     # Test runner entry points
    │   ├── test.bat                 # Windows test runner
    │   └── test.sh                  # Linux test runner
    └── tests/                       # Test scripts by category
        ├── fixtures/                # Test fixtures
        ├── image_validation/        # Image validation tests
        ├── integration/             # Integration tests
        ├── performance/             # Performance tests
        ├── security/                # Security tests
        └── unit/                    # Unit tests
```

## Getting Started

### Prerequisites

- Docker Engine (Windows or Linux)
- Docker Compose
- Bash-compatible shell (Linux or Git Bash/WSL for Windows)

### Running Tests

Use the simplified test runners from the root directory:

```bash
# Run all tests (Windows)
runtests.bat

# Run all tests (Linux/macOS)
./runtests.sh

# Run specific test category
runtests.bat --category integration
./runtests.sh --category integration

# Run with verbose output
runtests.bat --verbose
./runtests.sh --verbose

# Skip environment setup/cleanup
runtests.bat --skip-setup --skip-cleanup
./runtests.sh --skip-setup --skip-cleanup

# Specify custom output directory
runtests.bat --output ./custom/path
./runtests.sh --output ./custom/path
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

1. Create a new test script in the appropriate category directory under `testing/tests/`
2. Use common utility functions from `testing/lib/common.sh`
3. Use assertion functions from `testing/lib/assertions.sh`
4. Make sure your test script returns 0 on success and non-zero on failure

Example test structure:

```bash
#!/bin/sh
# Test description
# Version: 1.0.0

# Determine script location regardless of platform
script_dir=$(dirname "$0")
project_root=$(cd "$script_dir/../../.." && pwd)
testing_root=$(cd "$script_dir/../.." && pwd)

# Source test utilities
. "$testing_root/lib/common.sh"
. "$testing_root/lib/assertions.sh"

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

## Contact

For questions or issues, please contact your New Relic representative.
