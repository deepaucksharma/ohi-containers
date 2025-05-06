#!/bin/bash
# Test script to validate database integration functionality

set -e

# Configuration
MYSQL_CONTAINER="test-mysql"
POSTGRES_CONTAINER="test-postgres"
NR_CONTAINER="test-newrelic-infra"
MOCK_NR_CONTAINER="mock-newrelic"
TIMEOUT=120  # Seconds to wait for metrics to appear

echo "Starting database integration tests"
echo "-----------------------------------"

# Function to check if container is running
check_container() {
    echo "Checking if container $1 is running..."
    if docker inspect "$1" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"; then
        echo "✅ Container $1 is running"
        return 0
    else
        echo "❌ Container $1 is not running"
        return 1
    fi
}

# Step 1: Verify all containers are running
echo "Verifying containers..."
check_container "$MYSQL_CONTAINER" || exit 1
check_container "$POSTGRES_CONTAINER" || exit 1
check_container "$NR_CONTAINER" || exit 1
check_container "$MOCK_NR_CONTAINER" || exit 1

# Step 2: Create test data in MySQL
echo "Creating test data in MySQL..."
docker exec -i "$MYSQL_CONTAINER" mysql -unewrelic -ptest_password test << EOF
DROP TABLE IF EXISTS test_table;
CREATE TABLE test_table (id INT PRIMARY KEY, name VARCHAR(50));
INSERT INTO test_table VALUES (1, 'Test 1'), (2, 'Test 2'), (3, 'Test 3');

-- Create a slow query for testing
SELECT SLEEP(1);
SELECT * FROM test_table WHERE SLEEP(0.7) = 0;
EOF
echo "✅ MySQL test data created"

# Step 3: Create test data in PostgreSQL
echo "Creating test data in PostgreSQL..."
docker exec -i "$POSTGRES_CONTAINER" psql -U newrelic -d postgres << EOF
CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO test_table (name) VALUES ('Test 1'), ('Test 2'), ('Test 3');

-- Create extension if it doesn't exist
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a slow query for testing
SELECT pg_sleep(1);
SELECT * FROM test_table WHERE pg_sleep(0.7) = 0;
EOF
echo "✅ PostgreSQL test data created"

# Step 4: Verify New Relic agent is collecting MySQL metrics
echo "Checking MySQL metrics collection..."
timeout $TIMEOUT bash -c '
  until docker exec $NR_CONTAINER grep -q "MySQLSample" /var/log/newrelic-infra/newrelic-infra.log; do
    echo "Waiting for MySQL metrics..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ MySQL metrics are being collected"
else
    echo "❌ MySQL metrics collection failed"
    exit 1
fi

# Step 5: Verify New Relic agent is collecting PostgreSQL metrics
echo "Checking PostgreSQL metrics collection..."
timeout $TIMEOUT bash -c '
  until docker exec $NR_CONTAINER grep -q "PostgresSample" /var/log/newrelic-infra/newrelic-infra.log; do
    echo "Waiting for PostgreSQL metrics..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL metrics are being collected"
else
    echo "❌ PostgreSQL metrics collection failed"
    exit 1
fi

# Step 6: Verify Query Metrics are being collected
echo "Checking query metrics collection..."
timeout $TIMEOUT bash -c '
  until docker exec $NR_CONTAINER grep -q "MySQLQuerySample" /var/log/newrelic-infra/newrelic-infra.log; do
    echo "Waiting for MySQL query metrics..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ MySQL query metrics are being collected"
else
    echo "❌ MySQL query metrics collection failed"
    exit 1
fi

timeout $TIMEOUT bash -c '
  until docker exec $NR_CONTAINER grep -q "PostgresQuerySample" /var/log/newrelic-infra/newrelic-infra.log; do
    echo "Waiting for PostgreSQL query metrics..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL query metrics are being collected"
else
    echo "❌ PostgreSQL query metrics collection failed"
    exit 1
fi

# Step 7: Verify metrics are being sent to mock New Relic backend
echo "Checking metrics delivery to New Relic..."
timeout $TIMEOUT bash -c '
  until docker exec $MOCK_NR_CONTAINER grep -q "MySQLSample" /home/wiremock/requests.log; do
    echo "Waiting for MySQL data in mock backend..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ MySQL data successfully delivered to New Relic"
else
    echo "❌ MySQL data delivery to New Relic failed"
    exit 1
fi

timeout $TIMEOUT bash -c '
  until docker exec $MOCK_NR_CONTAINER grep -q "PostgresSample" /home/wiremock/requests.log; do
    echo "Waiting for PostgreSQL data in mock backend..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL data successfully delivered to New Relic"
else
    echo "❌ PostgreSQL data delivery to New Relic failed"
    exit 1
fi

# Step 8: Verify query metrics are being sent to mock New Relic backend
echo "Checking query metrics delivery to New Relic..."
timeout $TIMEOUT bash -c '
  until docker exec $MOCK_NR_CONTAINER grep -q "MySQLQuerySample" /home/wiremock/requests.log; do
    echo "Waiting for MySQL query data in mock backend..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ MySQL query data successfully delivered to New Relic"
else
    echo "❌ MySQL query data delivery to New Relic failed"
    exit 1
fi

timeout $TIMEOUT bash -c '
  until docker exec $MOCK_NR_CONTAINER grep -q "PostgresQuerySample" /home/wiremock/requests.log; do
    echo "Waiting for PostgreSQL query data in mock backend..."
    sleep 5
  done
'
if [ $? -eq 0 ]; then
    echo "✅ PostgreSQL query data successfully delivered to New Relic"
else
    echo "❌ PostgreSQL query data delivery to New Relic failed"
    exit 1
fi

echo "-----------------------------------"
echo "✅ All database integration tests passed!"
exit 0