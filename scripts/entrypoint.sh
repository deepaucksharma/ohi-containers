#!/bin/bash
set -e

# Process the configuration template with environment variables
envsubst < /etc/newrelic-infra.yml.template > /etc/newrelic-infra.yml

# Handle mock mode for testing
if [ "${NR_MOCK_MODE}" = "true" ]; then
  # Use mock backend
  export NRIA_METRICS_ENDPOINTS="http://mockbackend:8080/v1/metrics"
  export NRIA_INVENTORY_ENDPOINTS="http://mockbackend:8080/v1/inventory"
  export NRIA_EVENTS_ENDPOINTS="http://mockbackend:8080/v1/events"
  echo "Running in MOCK mode - using mock backend endpoints"
else
  # Use default/production endpoints
  unset NRIA_METRICS_ENDPOINTS
  unset NRIA_INVENTORY_ENDPOINTS
  unset NRIA_EVENTS_ENDPOINTS
  echo "Running in PRODUCTION mode - using default New Relic endpoints"
fi

echo "Starting New Relic Infrastructure Agent..."
exec /usr/bin/newrelic-infra "$@"
