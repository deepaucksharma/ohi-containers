@echo off
echo Starting performance tests
echo -----------------------

echo Measuring database container resource usage (MySQL):
docker stats test-mysql --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo.
echo Measuring database container resource usage (PostgreSQL):
docker stats test-postgres --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo.
echo Measuring mock API container resource usage:
docker stats mock-newrelic --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo.
echo Simulating load on MySQL:
docker exec test-mysql mysql -u root -proot -e "SELECT BENCHMARK(1000000, AES_ENCRYPT('hello', RAND()));"

echo.
echo Simulating load on PostgreSQL:
docker exec test-postgres psql -U postgres -c "SELECT COUNT(*) FROM generate_series(1, 1000000);"

echo.
echo Measuring database container resource usage after load (MySQL):
docker stats test-mysql --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo.
echo Measuring database container resource usage after load (PostgreSQL):
docker stats test-postgres --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo.
echo -----------------------
echo Performance tests completed!
