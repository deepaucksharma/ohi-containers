#!/bin/bash
# Security validation test script

set -e

# Configuration
NR_CONTAINER="test-newrelic-infra"
LOG_FILE="security_test.log"

echo "Starting security validation tests"
echo "----------------------------------"
echo

# Check user context
echo "Checking container user context..."
CONTAINER_USER=$(docker exec "$NR_CONTAINER" id -u)
if [[ "$CONTAINER_USER" != "0" ]]; then
    echo "✅ Container is running as non-root user (UID: $CONTAINER_USER)"
else
    echo "❌ Container is running as root user. This is not recommended for production."
    exit 1
fi

# Check if secrets are properly stored and not exposed in environment
echo "Checking secret handling..."
DB_PASS_IN_ENV=$(docker exec "$NR_CONTAINER" env | grep -E 'PASSWORD|LICENSE' | wc -l)
if [[ "$DB_PASS_IN_ENV" -eq 0 ]]; then
    echo "✅ Database credentials are not exposed in environment variables"
else
    echo "❌ Sensitive information found in environment variables:"
    docker exec "$NR_CONTAINER" env | grep -E 'PASSWORD|LICENSE'
    exit 1
fi

# Check if passwords are not visible in plaintext in process command lines
echo "Checking process command line exposure..."
PS_WITH_PASSWORD=$(docker exec "$NR_CONTAINER" ps aux | grep -E 'PASSWORD|LICENSE' | grep -v grep | wc -l)
if [[ "$PS_WITH_PASSWORD" -eq 0 ]]; then
    echo "✅ Credentials are not exposed in process command lines"
else
    echo "❌ Sensitive information found in process command lines:"
    docker exec "$NR_CONTAINER" ps aux | grep -E 'PASSWORD|LICENSE' | grep -v grep
    exit 1
fi

# Verify TLS connections to New Relic
echo "Checking TLS for New Relic connections..."
TLS_CHECK=$(docker exec "$NR_CONTAINER" curl -sI https://metric-api.newrelic.com/status | grep "HTTP/2 200")
if [[ -n "$TLS_CHECK" ]]; then
    echo "✅ TLS connection to New Relic validated"
else
    echo "❌ TLS connection to New Relic failed"
    echo "Response:"
    docker exec "$NR_CONTAINER" curl -sI https://metric-api.newrelic.com/status
    exit 1
fi

# Check file permissions
echo "Checking sensitive file permissions..."
CONFIG_PERMISSIONS=$(docker exec "$NR_CONTAINER" stat -c "%a" /etc/newrelic-infra.yml)
if [[ "$CONFIG_PERMISSIONS" == "644" || "$CONFIG_PERMISSIONS" == "640" ]]; then
    echo "✅ Configuration file has appropriate permissions: $CONFIG_PERMISSIONS"
else
    echo "❌ Configuration file has unsafe permissions: $CONFIG_PERMISSIONS"
    echo "Expected 644 or 640"
    exit 1
fi

# Check log file access
echo "Checking log file security..."
LOG_PERMISSIONS=$(docker exec "$NR_CONTAINER" stat -c "%a" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null || echo "Not found")
if [[ "$LOG_PERMISSIONS" == "644" || "$LOG_PERMISSIONS" == "640" || "$LOG_PERMISSIONS" == "Not found" ]]; then
    echo "✅ Log file permissions are appropriate: $LOG_PERMISSIONS"
else
    echo "❌ Log file has unsafe permissions: $LOG_PERMISSIONS"
    echo "Expected 644 or 640"
    exit 1
fi

# Scan for secrets in logs
echo "Checking logs for exposed secrets..."
SECRETS_IN_LOGS=$(docker exec "$NR_CONTAINER" grep -E "password|secret|credential|key" /var/log/newrelic-infra/newrelic-infra.log 2>/dev/null | grep -v "checking\|validating" | wc -l)
if [[ "$SECRETS_IN_LOGS" -eq 0 ]]; then
    echo "✅ No secrets found in log files"
else
    echo "❌ Potential secrets found in log files: $SECRETS_IN_LOGS occurrences"
    docker exec "$NR_CONTAINER" grep -E "password|secret|credential|key" /var/log/newrelic-infra/newrelic-infra.log | grep -v "checking\|validating" | head -5
    exit 1
fi

# Check network security
echo "Checking network security settings..."
OPEN_PORTS=$(docker exec "$NR_CONTAINER" netstat -tulpn 2>/dev/null | grep -v "127.0.0.1" | grep "LISTEN" | wc -l)
if [[ "$OPEN_PORTS" -le 1 ]]; then
    echo "✅ Limited exposed ports: $OPEN_PORTS"
else
    echo "❌ Multiple ports exposed to the network: $OPEN_PORTS"
    docker exec "$NR_CONTAINER" netstat -tulpn | grep -v "127.0.0.1" | grep "LISTEN"
    exit 1
fi

# Check health endpoint security
echo "Checking health endpoint protection..."
if docker exec "$NR_CONTAINER" curl -s http://localhost:8001/metrics > /dev/null 2>&1; then
    echo "❌ Health endpoint is accessible without authentication"
    exit 1
else
    echo "✅ Health endpoint is properly secured"
fi

# Check for vulnerable packages
echo "Checking for vulnerable packages..."
VULNERABILITIES=$(docker exec "$NR_CONTAINER" apt list --installed 2>/dev/null | grep -E 'openssl|libssl|libcurl|libc6' | wc -l)
if [[ "$VULNERABILITIES" -gt 0 ]]; then
    echo "ℹ️ Security-critical packages detected (further analysis needed):"
    docker exec "$NR_CONTAINER" apt list --installed 2>/dev/null | grep -E 'openssl|libssl|libcurl|libc6'
else
    echo "✅ No obvious security-critical packages found"
fi

echo "----------------------------------"
echo "✅ All security tests passed!"
exit 0