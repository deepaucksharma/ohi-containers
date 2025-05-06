@echo off
echo Starting database integration tests
echo -----------------------------------

echo Checking MySQL Database Performance Monitoring capabilities:
docker exec test-mysql mysql -u root -proot -e "SHOW VARIABLES LIKE 'performance_schema';"
docker exec test-mysql mysql -u root -proot -e "SELECT * FROM performance_schema.setup_consumers WHERE name LIKE 'events_statements%' AND enabled='YES';"

echo.
echo Checking PostgreSQL stats collection capabilities:
docker exec test-postgres psql -U postgres -c "SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_statements';"
docker exec test-postgres psql -U postgres -c "SELECT * FROM pg_extension WHERE extname = 'pg_stat_statements';"

echo.
echo Simulating slow queries in MySQL for testing:
docker exec test-mysql mysql -u root -proot -e "SELECT SLEEP(1); SELECT * FROM test.test_table WHERE SLEEP(0.2) = 0;"

echo.
echo Simulating slow queries in PostgreSQL for testing:
docker exec test-postgres psql -U postgres -c "SELECT pg_sleep(1); SELECT * FROM test_table WHERE pg_sleep(0.2) = 0;"

echo.
echo Testing New Relic API integration:
echo Sending MySQL metrics...
curl -s -X POST http://localhost:8080/v1/metrics -d "{\"eventType\":\"MySQLSample\",\"hostname\":\"test-mysql\",\"database\":\"test\",\"connections\":10}" -H "Content-Type: application/json"
echo.

echo Sending PostgreSQL metrics...
curl -s -X POST http://localhost:8080/v1/metrics -d "{\"eventType\":\"PostgresSample\",\"hostname\":\"test-postgres\",\"database\":\"postgres\",\"connections\":5}" -H "Content-Type: application/json"
echo.

echo Sending MySQL query metrics...
curl -s -X POST http://localhost:8080/v1/metrics -d "{\"eventType\":\"MySQLQuerySample\",\"hostname\":\"test-mysql\",\"database\":\"test\",\"query\":\"SELECT * FROM test_table\",\"duration_ms\":200}" -H "Content-Type: application/json"
echo.

echo Sending PostgreSQL query metrics...
curl -s -X POST http://localhost:8080/v1/metrics -d "{\"eventType\":\"PostgresQuerySample\",\"hostname\":\"test-postgres\",\"database\":\"postgres\",\"query\":\"SELECT * FROM test_table\",\"duration_ms\":200}" -H "Content-Type: application/json"
echo.

echo -----------------------------------
echo Database integration test completed!
