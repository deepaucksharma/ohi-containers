#!/usr/bin/env bash
# Database utility functions
# Version: 2.0.0

# Load common library
load "common"

# Execute a MySQL query
mysql_query() {
    local host="${1:-mysql}"
    local port="${2:-3306}"
    local user="${3:-newrelic}"
    local password="${4:-test_password}"
    local database="${5:-test}"
    local query="$6"
    
    MYSQL_PWD="$password" mysql -h "$host" -P "$port" -u "$user" "$database" -e "$query"
    return $?
}

# Execute a PostgreSQL query
pg_query() {
    local host="${1:-postgres}"
    local port="${2:-5432}"
    local user="${3:-postgres}"
    local password="${4:-postgres}"
    local database="${5:-postgres}"
    local query="$6"
    
    PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "$query"
    return $?
}

# Wait for MySQL to be available
wait_for_mysql() {
    local host="${1:-mysql}"
    local port="${2:-3306}"
    local user="${3:-newrelic}"
    local password="${4:-test_password}"
    local timeout="${5:-60}"
    
    log_message "INFO" "Waiting for MySQL at $host:$port to be available..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if MYSQL_PWD="$password" mysql -h "$host" -P "$port" -u "$user" -e "SELECT 1" >/dev/null 2>&1; then
            log_message "INFO" "MySQL is available at $host:$port"
            return 0
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    log_message "ERROR" "Timeout waiting for MySQL at $host:$port"
    return 1
}

# Wait for PostgreSQL to be available
wait_for_postgres() {
    local host="${1:-postgres}"
    local port="${2:-5432}"
    local user="${3:-postgres}"
    local password="${4:-postgres}"
    local database="${5:-postgres}"
    local timeout="${6:-60}"
    
    log_message "INFO" "Waiting for PostgreSQL at $host:$port to be available..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT 1" >/dev/null 2>&1; then
            log_message "INFO" "PostgreSQL is available at $host:$port"
            return 0
        fi
        
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    log_message "ERROR" "Timeout waiting for PostgreSQL at $host:$port"
    return 1
}

# Generate load on MySQL for performance testing
generate_mysql_load() {
    local host="${1:-mysql}"
    local port="${2:-3306}"
    local user="${3:-root}"
    local password="${4:-root}"
    local database="${5:-test}"
    local duration="${6:-10}"  # seconds
    
    log_message "INFO" "Generating load on MySQL for $duration seconds..."
    
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        MYSQL_PWD="$password" mysql -h "$host" -P "$port" -u "$user" "$database" -e "CALL generate_test_load()" >/dev/null 2>&1
        sleep 0.1
    done
    
    log_message "INFO" "Load generation completed"
}

# Generate load on PostgreSQL for performance testing
generate_postgres_load() {
    local host="${1:-postgres}"
    local port="${2:-5432}"
    local user="${3:-postgres}"
    local password="${4:-postgres}"
    local database="${5:-postgres}"
    local duration="${6:-10}"  # seconds
    
    log_message "INFO" "Generating load on PostgreSQL for $duration seconds..."
    
    local end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "SELECT test_monitoring.generate_test_load()" >/dev/null 2>&1
        sleep 0.1
    done
    
    log_message "INFO" "Load generation completed"
}
