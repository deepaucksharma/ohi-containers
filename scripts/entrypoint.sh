#!/bin/sh
set -e

# Support both license key environment variables
export NRIA_LICENSE_KEY="${NRIA_LICENSE_KEY:-$NEW_RELIC_LICENSE_KEY}"

# Process the configuration template with environment variables
# Create a temporary file for preprocessing
TEMP_FILE=$(mktemp)

# Preprocess the template to handle default values
cat /etc/newrelic-infra.yml.template | while IFS= read -r line; do
  # Process each line to replace ${VAR:default} format with proper defaults
  processed_line=$(echo "$line" | sed -E 's/\$\{([A-Za-z0-9_]+):([^}]*)\}/\${\1:-\2}/g')
  echo "$processed_line" >> "$TEMP_FILE"
done

# Now use envsubst on the preprocessed file
envsubst < "$TEMP_FILE" > /home/newrelic-user/config/newrelic-infra.yml
rm -f "$TEMP_FILE"

# Check if license key is provided
if [ -z "${NRIA_LICENSE_KEY}" ] || [ "${NRIA_LICENSE_KEY}" = "" ]; then
  echo "ERROR: NRIA_LICENSE_KEY or NEW_RELIC_LICENSE_KEY environment variable is required but not set"
  exit 1
fi

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

# Ensure log directory has correct permissions for newrelic-user
if [ -d "/var/log/newrelic-infra" ]; then
  echo "Setting permissions for log directory..."
  # Always try to set permissions, regardless of user
  chmod -R 777 /var/log/newrelic-infra 2>/dev/null || echo "WARNING: Could not chmod log directory"
  
  # Try to change ownership if running as root
  if [ "$(id -u)" = "0" ]; then
    chown -R nri-agent:nri-agent /var/log/newrelic-infra 2>/dev/null || \
    chown -R 1000:1000 /var/log/newrelic-infra 2>/dev/null || \
    echo "WARNING: Could not change ownership of log directory, but permissions are set to 777"
  fi
fi

echo "Starting New Relic Infrastructure Agent..."
exec /usr/bin/newrelic-infra "$@"
