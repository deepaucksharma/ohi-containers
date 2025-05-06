FROM newrelic/infrastructure:latest

# Set metadata labels
LABEL maintainer="platform-eng@example.com" \
      version="1.0" \
      description="New Relic Infrastructure with DB Monitoring Integrations"

# Install additional dependencies required for database monitoring
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    netcat-openbsd \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Add New Relic repository for On-Host Integrations
RUN echo "deb https://download.newrelic.com/infrastructure_agent/linux/apt/ any main" > /etc/apt/sources.list.d/newrelic-infra.list \
    && curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | apt-key add -

# Install MySQL and PostgreSQL integrations
RUN apt-get update && apt-get install -y \
    nri-mysql \
    nri-postgresql \
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

# Configure healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Default entrypoint and command
ENTRYPOINT ["/usr/bin/newrelic-infra"]
CMD ["--config=/etc/newrelic-infra.yml"]
