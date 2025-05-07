FROM newrelic/infrastructure-bundle:latest

# Set metadata labels
LABEL maintainer="platform-eng@example.com" \
      version="1.0" \
      description="New Relic Infrastructure with DB Monitoring Integrations"

# Install additional dependencies
RUN apk add --no-cache \
    curl \
    gettext \
    jq \
    procps

# Copy configuration files
COPY configs/ /etc/newrelic-infra/integrations.d/
COPY configs/newrelic-infra.yml.template /etc/newrelic-infra.yml.template

# Create required directories with appropriate permissions
RUN mkdir -p \
    /var/log/test-results \
    /var/db/newrelic-infra/test-data \
    /var/log/newrelic-infra \
    /var/log/mysql \
    && chmod -R 755 /var/log/test-results \
    /var/db/newrelic-infra/test-data \
    /var/log/newrelic-infra \
    /var/log/mysql

# Add and configure health check script
COPY scripts/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Add entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create a non-root user and set permissions
RUN adduser -D -u 1000 -h /home/newrelic-user newrelic-user \
    && chown -R newrelic-user:newrelic-user /var/log/newrelic-infra \
    && chmod -R 775 /var/log/newrelic-infra \
    && chown -R newrelic-user:newrelic-user /var/log/mysql \
    && chown -R newrelic-user:newrelic-user /var/log/test-results \
    && chown -R newrelic-user:newrelic-user /var/db/newrelic-infra \
    && chmod -R 755 /etc/newrelic-infra \
    && chmod 755 /entrypoint.sh /usr/local/bin/healthcheck.sh

# Create config directory in user's home directory and set symlink
RUN mkdir -p /home/newrelic-user/config \
    && chown -R newrelic-user:newrelic-user /home/newrelic-user/config \
    && chmod 755 /home/newrelic-user/config \
    && ln -sf /home/newrelic-user/config/newrelic-infra.yml /etc/newrelic-infra.yml

# Configure healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Switch to non-root user
USER 1000

# Use entrypoint script to process templates before starting the agent
ENTRYPOINT ["/entrypoint.sh"]
