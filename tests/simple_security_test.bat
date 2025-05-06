@echo off
echo Starting security tests
echo ---------------------

echo Testing MySQL user permissions:
docker exec test-mysql mysql -u newrelic -ptest_password -e "SHOW GRANTS FOR 'newrelic'@'%';"

echo.
echo Testing PostgreSQL user permissions:
docker exec test-postgres psql -U postgres -c "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb FROM pg_roles WHERE rolname = 'newrelic';"
docker exec test-postgres psql -U postgres -c "SELECT m.rolname as member, r.rolname as role FROM pg_auth_members am JOIN pg_roles m ON am.member = m.oid JOIN pg_roles r ON am.roleid = r.oid WHERE m.rolname = 'newrelic';"

echo.
echo Testing TLS connection to New Relic:
curl -sI https://metric-api.newrelic.com/status

echo.
echo ---------------------
echo Security tests completed!
