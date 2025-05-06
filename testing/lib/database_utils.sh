#!/bin/sh
# Database utility functions for testing
# Version: 1.0.0

# Source common utilities
script_dir=$(dirname "$0")
. "$script_dir/common.sh"

# Execute MySQL query and return result
mysql_query() {
  local host="$1"
  local port="$2"
  local user="$3"
  local password="$4"
  local database="$5"
  local query="$6"
  local platform=$(detect_platform)
  local docker_command=$(docker_cmd)
  
  # Check if using a container or direct connection
  if [ -n "$7" ]; then
    local container="$7"
    $docker_command exec -i "$container" mysql -h"$host" -P"$port" -u"$user" -p"$password" "$database" -e "$query"
  else
    # Direct connection (requires mysql client)
    if command -v mysql >/dev/null 2>&1; then
      mysql -h"$host" -P"$port" -u"$user" -p"$password" "$database" -e "$query"
    else
      echo "MySQL client not found. Please install it or use container method."
      return 1
    fi
  fi
}

# Execute PostgreSQL query and return result
postgres_query() {
  local host="$1"
  local port="$2"
  local user="$3"
  local password="$4"
  local database="$5"
  local query="$6"
  local platform=$(detect_platform)
  local docker_command=$(docker_cmd)
  
  # Check if using a container or direct connection
  if [ -n "$7" ]; then
    local container="$7"
    PGPASSWORD="$password" $docker_command exec -i "$container" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "$query"
  else
    # Direct connection (requires psql client)
    if command -v psql >/dev/null 2>&1; then
      PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d "$database" -c "$query"
    else
      echo "PostgreSQL client not found. Please install it or use container method."
      return 1
    fi
  fi
}

# Wait for MySQL to be ready
wait_for_mysql() {
  local host="$1"
  local port="${2:-3306}"
  local user="$3"
  local password="$4"
  local timeout="${5:-60}"
  local container="$6"
  local docker_command=$(docker_cmd)
  
  log_message "INFO" "Waiting for MySQL to be ready at $host:$port..."
  
  local elapsed=0
  local interval=5
  
  while [ $elapsed -lt $timeout ]; do
    if [ -n "$container" ]; then
      if $docker_command exec "$container" mysqladmin -h"$host" -P"$port" -u"$user" -p"$password" ping >/dev/null 2>&1; then
        log_message "INFO" "MySQL is ready!"
        return 0
      fi
    else
      if command -v mysqladmin >/dev/null 2>&1; then
        if mysqladmin -h"$host" -P"$port" -u"$user" -p"$password" ping >/dev/null 2>&1; then
          log_message "INFO" "MySQL is ready!"
          return 0
        fi
      else
        # Try a simple connection
        if mysql_query "$host" "$port" "$user" "$password" "mysql" "SELECT 1" >/dev/null 2>&1; then
          log_message "INFO" "MySQL is ready!"
          return 0
        fi
      fi
    fi
    
    log_message "INFO" "Waiting for MySQL... $elapsed/$timeout seconds elapsed"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  
  log_message "ERROR" "Timed out waiting for MySQL"
  return 1
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
  local host="$1"
  local port="${2:-5432}"
  local user="$3"
  local password="$4"
  local database="${5:-postgres}"
  local timeout="${6:-60}"
  local container="$7"
  local docker_command=$(docker_cmd)
  
  log_message "INFO" "Waiting for PostgreSQL to be ready at $host:$port..."
  
  local elapsed=0
  local interval=5
  
  while [ $elapsed -lt $timeout ]; do
    if [ -n "$container" ]; then
      if PGPASSWORD="$password" $docker_command exec "$container" pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; then
        log_message "INFO" "PostgreSQL is ready!"
        return 0
      fi
    else
      if command -v pg_isready >/dev/null 2>&1; then
        if PGPASSWORD="$password" pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; then
          log_message "INFO" "PostgreSQL is ready!"
          return 0
        fi
      else
        # Try a simple connection
        if postgres_query "$host" "$port" "$user" "$password" "$database" "SELECT 1" >/dev/null 2>&1; then
          log_message "INFO" "PostgreSQL is ready!"
          return 0
        fi
      fi
    fi
    
    log_message "INFO" "Waiting for PostgreSQL... $elapsed/$timeout seconds elapsed"
    sleep $interval
    elapsed=$((elapsed + interval))
  done
  
  log_message "ERROR" "Timed out waiting for PostgreSQL"
  return 1
}
