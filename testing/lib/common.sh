#!/bin/bash
# Common utility functions for Linux test execution
# Version: 2.0.0

# Platform-independent file existence check
file_exists() {
  local file_path="$1"
  
  if [ -f "$file_path" ]; then
    return 0
  else
    return 1
  fi
}

# Platform-independent directory existence check
dir_exists() {
  local dir_path="$1"
  
  if [ -d "$dir_path" ]; then
    return 0
  else
    return 1
  fi
}

# Get temporary directory
get_temp_dir() {
  echo "/tmp"
}

# Execute command
execute_command() {
  local cmd="$1"
  bash -c "$cmd"
}

# Docker command helper
docker_cmd() {
  echo "docker"
}

# Log a message with timestamp
log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  
  case "$level" in
    "INFO")  echo "[$timestamp] [INFO] $message" ;;
    "WARN")  echo "[$timestamp] [WARN] $message" >&2 ;;
    "ERROR") echo "[$timestamp] [ERROR] $message" >&2 ;;
    *)       echo "[$timestamp] $message" ;;
  esac
}
