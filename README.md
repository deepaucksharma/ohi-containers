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
D:\NewRelic\db-aws\                 # Repository root
└── docker/                         # Docker resources
    ├── .env                        # Environment variables
    ├── .github/                    # GitHub workflow configurations
    │   └── workflows/              # CI workflow definitions
    ├── configs/                    # Configuration templates
    │   ├── newrelic-infra.yml      # Main agent config
    │   ├── mysql-config.yml        # MySQL integration config
    │   └── postgresql-config.yml   # PostgreSQL integration config
    ├── docker-compose.yml          # Main Docker Compose file
    ├── Dockerfile                  # Main Dockerfile
    ├── kubernetes/                 # Kubernetes configurations
    ├── README.md                   # This documentation file
    ├── runtests.bat                # Windows test runner wrapper
    ├── runtests.sh                 # Linux test runner wrapper
    ├── scripts/                    # Operational scripts
    │   ├── entrypoint.sh           # Container entrypoint script
    │   └── healthcheck.sh          # Container health check
    └── testing/                    # All testing-related code
        ├── bin/                    # Test runner scripts
        ├── fixtures/               # Test data fixtures
        │   ├── mysql/              # MySQL test data
        │   ├── postgres/           # PostgreSQL test data
        │   └── wiremock/           # Mock backend configs
        ├── lib/                    # Testing libraries
        │   ├── assertions.sh       # Test assertions
        │   ├── common.sh           # Common utility functions
        │   └── database_utils.sh   # Database utility functions
        ├── output/                 # Test output directory
        └── tests/                  # Test scripts by category
            ├── config_validation/  # Config validation tests
            ├── image_validation/   # Image validation tests
            ├── integration/        # Integration tests
            │   ├── mysql/          # MySQL-specific tests
            │   └── postgres/       # PostgreSQL-specific tests
            ├── performance/        # Performance tests
            ├── run_all_tests.sh    # Main test runner script
            ├── security/           # Security tests
            └── unit/               # Unit tests
```

## ✨ New: Automated E2E & Integration Tests

This repo now ships a complete test matrix that validates:

| Layer | Scenario IDs | What it proves |
|-------|--------------|----------------|
| **Build** | E2E-01 | Image is reproducible (multi-arch) |
| **Config** | E2E-02 | Secrets template renders correctly or blocks start-up |
| **MySQL Monitoring** | INT-My-01 / INT-My-02 | Standard & DBPM metrics flow to New Relic |
| **PostgreSQL Monitoring** | INT-Pg-01 / INT-Pg-02 | Same for Postgres with `pg_stat_statements` |
| **Security** | SEC-01 | No secrets leak into logs |
| **Reliability** | HA-01 / N/W-01 | Agent auto-recovers from DB fail-over & proxy outage |
| **Cloud-region** | CLOUD-01 | EU/US license routing correct |
| **Kubernetes** | K8s-01 | Helm deployment boots & reports |
| **Upgrade** | UP-01 | CI guards against silent version regressions |

### Running All Tests Locally

```bash
# From repo root
export NEW_RELIC_LICENSE_KEY=dummy012345678901234567890123456789
export MYSQL_ROOT_PASSWORD=root
# …

docker compose -f docker-compose.yml up -d --build
# Wait until health-checks pass (≈30 s)
docker exec test-runner sh -c "/testing/tests/run_all_tests.sh"
docker compose down
```

All E2E cases are runnable through the **GitHub Actions workflows** out-of-the-box.
For a single test, use `--category`:

```bash
./runtests.sh --category integration --test INT-My-02
```

### Writing New Scenarios

1. Add your script under `testing/tests/<group>/<id>.sh`.
2. Return `0` for pass, non-zero for fail.
3. Use helper libs:

   * `testing/lib/assertions.sh` – `assert_equals`, `assert_not_empty`
   * `testing/lib/database_utils.sh` – `wait_for_mysql`, `run_pg_query`

Scripts run inside Alpine with `bash`, `jq`, `curl` pre-installed.

---

Happy hacking 👩‍💻👨‍💻— drop issues or PRs if you spot a gap!

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

## Platform Independence

The framework is designed to run on both Windows and Linux with the same code:

- All shell scripts use `/bin/sh` instead of `/bin/bash` for compatibility
- Path handling is normalized between platforms
- Docker commands are executed with platform-specific wrappers
- File operations use platform-independent abstractions

## Contact

For questions or issues, please contact your New Relic representative.
