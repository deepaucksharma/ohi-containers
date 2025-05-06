FROM newrelic/infrastructure-bundle:3.7.1

# Set metadata labels
LABEL maintainer="platform-eng@example.com" \
      version="1.0" \
      description="New Relic Infrastructure with DB Monitoring Integrations"

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    gettext-base \
    netcat-openbsd \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY configs/ /etc/newrelic-infra/integrations.d/
COPY configs/newrelic-infra.yml.template /etc/newrelic-infra.yml.template

# Create required directories
RUN mkdir -p \
    /var/log/test-results \
    /var/db/newrelic-infra/test-data \
    /var/log/newrelic-infra \
    /var/log/mysql

# Set permissions
RUN chmod -R 777 /var/log/newrelic-infra \
    && chmod -R 777 /var/log/mysql \
    && chmod -R 755 /etc/newrelic-infra/integrations.d/

# Add and configure health check script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Add entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Configure healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Use entrypoint script to process templates before starting the agent
ENTRYPOINT ["/entrypoint.sh"]
