SHELL:=bash
.DEFAULT_GOAL := test

# Paths
BATS=./bats
TEST_DIR=specs
DOCKER_COMPOSE=docker compose -f docker-compose.test.yml

.PHONY: deps
deps:          # install bats & plugins once
	./scripts/bootstrap_bats.sh

.PHONY: build
build:         # build local images needed by tests
	$(DOCKER_COMPOSE) build

.PHONY: up
up: build      # spin up test stack
	$(DOCKER_COMPOSE) up -d

.PHONY: down
down:          # tear down & clean volumes
	$(DOCKER_COMPOSE) down -v --remove-orphans

.PHONY: test
test: deps up  # run full test suite
	$(BATS) -r $(TEST_DIR)
	@echo "💚 All Bats specs done"
	$(MAKE) down

.PHONY: test-unit
test-unit: deps  # run unit tests only
	$(BATS) $(TEST_DIR)/unit

.PHONY: test-integration
test-integration: deps up  # run integration tests only
	$(BATS) $(TEST_DIR)/integration
	$(MAKE) down

.PHONY: test-e2e
test-e2e: deps up  # run e2e tests only
	$(BATS) $(TEST_DIR)/e2e
	$(MAKE) down

.PHONY: test-security
test-security: deps  # run security tests only
	$(BATS) $(TEST_DIR)/security

.PHONY: lint
lint:  # lint shell scripts
	if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -type f -print0 | xargs -0 shellcheck; \
	else \
		echo "shellcheck not found. Please install shellcheck to run linting."; \
		exit 1; \
	fi

.PHONY: clean
clean: down  # clean up all artifacts
	rm -rf .bats .cache
	find . -name "*.log" -type f -delete
	find . -name "*.tmp" -type f -delete
	rm -rf artifacts/*
