#!/usr/bin/env bash
# Common utility functions for testing
# Version: 2.0.0

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    level=$1
    message=$2
    timestamp=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$(date)")
    echo "[$timestamp] [$level] $message"
}

# Get environment variable with fallback
get_env() {
    local name=$1
    local default=$2
    local value="${!name}"
    
    if [ -z "$value" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Detect platform (Linux, macOS, Windows)
detect_platform() {
    if [ -f /proc/version ]; then
        if grep -qi microsoft /proc/version; then
            echo "Windows (WSL)"
        else
            echo "Linux"
        fi
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macOS"
    elif [ -n "$WINDIR" ]; then
        echo "Windows"
    elif [ -n "$MSYSTEM" ]; then
        echo "Windows (MSYS/Git Bash)"
    else
        echo "Unknown"
    fi
}

# Check if running in a container
is_container() {
    if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        return 0  # Is a container
    else
        return 1  # Not a container
    fi
}

# Wait for a port to be available
wait_for_port() {
    host=$1
    port=$2
    timeout=${3:-60}  # Default timeout: 60 seconds
    
    log_message "INFO" "Waiting for $host:$port to be available (timeout: ${timeout}s)..."
    
    elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if nc -z "$host" "$port" >/dev/null 2>&1; then
            log_message "INFO" "Port $host:$port is now available"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    
    log_message "ERROR" "Timeout waiting for $host:$port"
    return 1
}

# Retry a command with exponential backoff
retry_with_backoff() {
    local max_attempts=${ATTEMPTS:-5}
    local timeout=${TIMEOUT:-1}
    local attempt=1
    local exitCode=0

    while [ $attempt -le $max_attempts ]; do
        "$@"
        exitCode=$?

        if [ $exitCode -eq 0 ]; then
            return 0
        fi

        echo "Command failed, retrying in $timeout seconds..."
        sleep $timeout
        attempt=$((attempt + 1))
        timeout=$((timeout * 2))
    done

    echo "Command failed after $max_attempts attempts"
    return $exitCode
}

# Poll a condition until it returns true or timeout
poll_until() {
    local timeout=$1
    shift
    local command="$@"
    local end_time=$(($(date +%s) + timeout))
    
    until [ $(date +%s) -gt $end_time ]; do
        if eval "$command"; then
            return 0
        fi
        sleep 1
    done
    
    echo "Timeout after $timeout seconds waiting for condition: $command"
    return 1
}

# Create a unique ID
generate_id() {
    prefix=$1
    if command -v uuidgen >/dev/null 2>&1; then
        echo "${prefix}-$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]' | head -c 8)"
    else
        echo "${prefix}-$(date +%s | md5sum 2>/dev/null || echo "$(date +%s)$(echo $RANDOM)" | md5sum 2>/dev/null || echo "${prefix}-$(date +%s)${RANDOM}")"
    fi
}
