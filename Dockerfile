FROM newrelic/infrastructure:latest

# Set metadata labels
LABEL maintainer="platform-eng@example.com" \
      version="1.0" \
      description="New Relic Infrastructure with DB Monitoring Integrations"

# Copy configuration files
COPY configs/ /etc/newrelic-infra/integrations.d/
COPY configs/newrelic-infra.yml.template /etc/newrelic-infra.yml.template

# Create directories for test outputs and data
RUN mkdir -p /var/log/test-results /var/db/newrelic-infra/test-data

# Add and configure health check script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Configure healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Default entrypoint and command
ENTRYPOINT ["/usr/bin/newrelic-infra"]
CMD ["--config=/etc/newrelic-infra.yml"]