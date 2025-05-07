# Contributing Guide

This document describes how to contribute to the New Relic Infrastructure Docker project, focusing on the testing infrastructure.

## Testing Infrastructure

We use a Bats-based testing framework to ensure quality and reliability of our Docker images and integrations. The testing infrastructure is designed to be modular, maintainable, and efficient.

### Directory Structure

```
testing/
├── Makefile                # One-stop entry point for all tests
├── scripts/                # Helper scripts (bootstrap_bats.sh, plot_perf.py)
├── lib/                    # Reusable libraries
│   ├── common.bash         # Common utilities
│   ├── assert.bash         # Test assertions
│   └── db.bash             # Database utilities
├── specs/                  # Test specifications in Bats format
│   ├── unit/               # Unit tests for helpers
│   ├── integration/        # Integration tests (MySQL, PostgreSQL)
│   ├── e2e/                # End-to-end tests
│   ├── perf/               # Performance tests
│   └── security/           # Security tests
├── fixtures/               # Test fixtures (SQL, configs)
└── docker-compose.test.yml # Testing environment setup
```

### Prerequisites

- Docker Engine
- Docker Compose
- Bash or compatible shell
- Python 3.x (for performance report generation)

### Running Tests

The `Makefile` provides a single entry point for all testing operations:

```bash
# Install test dependencies (Bats and plugins)
make deps

# Run all tests
make test

# Run specific test categories
make test-unit
make test-integration
make test-e2e
make test-security

# Start/stop the test environment
make up
make down

# Clean up artifacts
make clean
```

### Writing Tests

Tests are written using the [Bats](https://github.com/bats-core/bats-core) framework, which provides a TAP-compatible output format and rich testing features.

#### Test Structure

```bash
#!/usr/bin/env bats
# Test description
# Version: X.Y.Z

# Load dependencies
load "../../lib/common"
load "../../lib/assert"
load "../../lib/db"

# Setup function (runs before each test)
setup() {
  # Prepare test environment
}

# Teardown function (runs after each test)
teardown() {
  # Clean up after test
}

# Test cases
@test "Description of what the test should verify" {
  # Run command
  run some_command arg1 arg2
  
  # Assert expectations
  assert_success             # Command should exit with 0
  assert_output --partial "expected output"
}
```

#### Best Practices

1. **Isolation**: Each test should be independent and not rely on the state from previous tests.
2. **Descriptive Names**: Use clear, descriptive names for test files and test cases.
3. **Setup/Teardown**: Use setup and teardown functions to avoid duplication.
4. **Assertions**: Use the provided assertion functions for consistent error handling.
5. **Documentation**: Document the purpose of each test file and test case.

### Test Categories

- **Unit Tests**: Test shell script functions and utilities in isolation.
- **Integration Tests**: Test the interaction between the agent and databases.
- **End-to-End Tests**: Test the full stack, including metrics flow to the backend.
- **Performance Tests**: Measure resource usage and response times.
- **Security Tests**: Verify security best practices and configurations.

### Continuous Integration

All tests run in GitHub Actions on pull requests and pushes to the main branch. The workflow includes:

1. **Linting**: ShellCheck and YAML validation
2. **Unit Tests**: Fast tests that run without Docker
3. **Integration & E2E Tests**: Full stack tests with Docker Compose
4. **Security Tests**: Container security and vulnerability scanning
5. **Performance Tests**: Resource usage and metrics throughput

### Definition of Done

When submitting a pull request, ensure:

- [ ] All tests pass (`make test`)
- [ ] New features have corresponding tests
- [ ] Code is properly linted (`shellcheck`)
- [ ] Documentation is updated

## Contact

For questions or issues about the testing framework, please contact the Platform Engineering team.
