#!/bin/sh
# Health check for New Relic infrastructure agent
# This performs a basic validation of the agent's functionality

set -e

# Check if the New Relic agent process is running
# Use 'ps' instead of 'pgrep' for broader compatibility
if ! ps -ef | grep -q "[n]ewrelic-infra"; then
  echo "ERROR: New Relic Infrastructure agent process is not running"
  exit 1
fi

# Check if log directory exists and is writable
if [ ! -d "/var/log/newrelic-infra" ] || [ ! -w "/var/log/newrelic-infra" ]; then
  echo "ERROR: Log directory not accessible"
  exit 1
fi

# Check if we can connect to MySQL (if configured)
if [ -n "$MYSQL_HOST" ] && [ -n "$MYSQL_PORT" ]; then
  if ! nc -z "$MYSQL_HOST" "$MYSQL_PORT" > /dev/null 2>&1; then
    echo "WARNING: Cannot connect to MySQL at $MYSQL_HOST:$MYSQL_PORT"
  fi
fi

# Check if we can connect to PostgreSQL (if configured)
if [ -n "$POSTGRES_HOST" ] && [ -n "$POSTGRES_PORT" ]; then
  if ! nc -z "$POSTGRES_HOST" "$POSTGRES_PORT" > /dev/null 2>&1; then
    echo "WARNING: Cannot connect to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
  fi
fi

# Check if we can connect to the mock backend (if we're in testing mode)
if [ "${NR_MOCK_MODE}" = "true" ]; then
  MOCKBACKEND_HOST="mockbackend"
  MOCKBACKEND_PORT="8080"
  
  if ! nc -z "$MOCKBACKEND_HOST" "$MOCKBACKEND_PORT" > /dev/null 2>&1; then
    echo "WARNING: Cannot connect to mock backend at $MOCKBACKEND_HOST:$MOCKBACKEND_PORT"
  else
    # Check if the mock backend is responding properly
    if ! curl -s "http://$MOCKBACKEND_HOST:$MOCKBACKEND_PORT/__admin/mappings" > /dev/null; then
      echo "WARNING: Mock backend is not responding properly"
    fi
    
    # Check if the mock backend /status endpoint is available
    if ! curl -s "http://$MOCKBACKEND_HOST:$MOCKBACKEND_PORT/status" > /dev/null; then
      echo "WARNING: Mock backend /status endpoint not available"
    fi
  fi
fi

echo "Health check passed"
exit 0
