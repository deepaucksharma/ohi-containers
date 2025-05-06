#!/bin/sh
# Common utility functions for platform-independent test execution
# Version: 1.0.0

# Detect platform
detect_platform() {
  case "$(uname -s 2>/dev/null)" in
    Linux*)     echo "linux" ;;
    Darwin*)    echo "macos" ;;
    CYGWIN*)    echo "windows" ;;
    MINGW*)     echo "windows" ;;
    MSYS*)      echo "windows" ;;
    Windows*)   echo "windows" ;;
    *)          
      # If uname fails, try other methods
      if command -v cmd.exe >/dev/null 2>&1; then
        echo "windows"
      else
        echo "linux"  # Default to linux if detection fails
      fi
      ;;
  esac
}

# Platform-independent path handling
normalize_path() {
  local path="$1"
  local platform=$(detect_platform)
  
  if [ "$platform" = "windows" ]; then
    # Convert forward slashes to backslashes for Windows
    echo "$path" | sed 's/\//\\/g'
  else
    # Ensure forward slashes for Unix
    echo "$path" | sed 's/\\/\//g'
  fi
}

# Platform-independent temporary directory
get_temp_dir() {
  local platform=$(detect_platform)
  
  if [ "$platform" = "windows" ]; then
    echo "$TEMP"
  else
    echo "/tmp"
  fi
}

# Platform-independent command execution
execute_command() {
  local cmd="$1"
  local platform=$(detect_platform)
  
  if [ "$platform" = "windows" ]; then
    cmd.exe /c "$cmd"
  else
    sh -c "$cmd"
  fi
}

# Platform-independent Docker command
docker_cmd() {
  local platform=$(detect_platform)
  
  if [ "$platform" = "windows" ]; then
    echo "docker.exe"
  else
    echo "docker"
  fi
}

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
