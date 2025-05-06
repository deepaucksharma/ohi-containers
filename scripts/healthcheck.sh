#!/bin/bash
# Health check for New Relic infrastructure agent
# This performs a basic validation of the agent's functionality

set -e

# Check if the New Relic agent process is running
if ! pgrep -f "newrelic-infra" > /dev/null; then
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

echo "Health check passed"
exit 0