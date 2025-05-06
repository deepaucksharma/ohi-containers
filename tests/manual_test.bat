@echo off
echo === Testing MySQL Database ===
echo Checking if MySQL user 'newrelic' exists...
docker exec test-mysql mysql -u root -proot -e "SELECT User, Host FROM mysql.user WHERE User='newrelic';"

echo Creating test data in MySQL...
docker exec test-mysql mysql -u root -proot -e "USE test; CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY, name VARCHAR(50)); INSERT INTO test_table VALUES (1, 'Test 1'), (2, 'Test 2'), (3, 'Test 3') ON DUPLICATE KEY UPDATE name=VALUES(name);"

echo Verifying test data in MySQL...
docker exec test-mysql mysql -u root -proot -e "USE test; SELECT * FROM test_table;"

echo.
echo === Testing PostgreSQL Database ===
echo Checking if PostgreSQL user 'newrelic' exists...
docker exec test-postgres psql -U postgres -c "SELECT usename FROM pg_user WHERE usename='newrelic';"

echo Creating test data in PostgreSQL...
docker exec test-postgres psql -U postgres -c "CREATE TABLE IF NOT EXISTS test_table (id SERIAL PRIMARY KEY, name VARCHAR(50)); INSERT INTO test_table (name) VALUES ('Test 1'), ('Test 2'), ('Test 3') ON CONFLICT DO NOTHING;"

echo Verifying test data in PostgreSQL...
docker exec test-postgres psql -U postgres -c "SELECT * FROM test_table;"

echo.
echo === Testing New Relic Mock API ===
echo Sending test metrics to mock API...
curl -s -X POST http://localhost:8080/v1/metrics -d "{\"event\":\"MySQLSample\",\"value\":100}" -H "Content-Type: application/json"
echo.

echo Test complete!
