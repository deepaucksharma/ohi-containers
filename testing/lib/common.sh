#!/bin/sh
# Common utility functions for cross-platform test execution
# Version: 2.0.0

# Detect platform in a more robust way
detect_platform() {
  case "$(uname -s 2>/dev/null || echo 'unknown')" in
    Linux*)     echo "linux";;
    Darwin*)    echo "macos";;
    CYGWIN*)    echo "windows";;
    MINGW*)     echo "windows";;
    MSYS*)      echo "windows";;
    Windows*)   echo "windows";;
    *)
      # Fallback detection for environments where uname is not available
      if [ -d "/proc" ] && [ -f "/etc/os-release" ]; then
        echo "linux"
      elif [ -d "C:\\Windows" ]; then
        echo "windows"
      else
        echo "unknown"
      fi
      ;;
  esac
}

# Normalize path for cross-platform compatibility
normalize_path() {
  local path="$1"
  # Replace backslashes with forward slashes
  echo "$path" | sed 's/\\/\//g'
}

# Platform-independent file existence check
file_exists() {
  local file_path="$(normalize_path "$1")"
  
  if [ -f "$file_path" ]; then
    return 0
  else
    return 1
  fi
}

# Platform-independent directory existence check
dir_exists() {
  local dir_path="$(normalize_path "$1")"
  
  if [ -d "$dir_path" ]; then
    return 0
  else
    return 1
  fi
}

# Get temporary directory in a platform-independent way
get_temp_dir() {
  local platform=$(detect_platform)
  
  case "$platform" in
    "windows") echo "${TEMP:-${TMP:-C:/temp}}" | sed 's/\\/\//g' ;;
    "macos")   echo "${TMPDIR:-/tmp}" ;;
    *)         echo "${TMPDIR:-/tmp}" ;;
  esac
}

# Execute command with proper shell based on platform
execute_command() {
  local cmd="$1"
  local platform=$(detect_platform)
  
  case "$platform" in
    "windows") cmd.exe /c "$cmd" ;;
    *)         sh -c "$cmd" ;;
  esac
}

# Docker command helper for cross-platform compatibility
docker_cmd() {
  local platform=$(detect_platform)
  
  case "$platform" in
    "windows") 
      # Check if Docker Desktop is installed
      if command -v "docker.exe" >/dev/null 2>&1; then
        echo "docker.exe"
      else
        echo "docker"
      fi
      ;;
    *)
      echo "docker"
      ;;
  esac
}

# Log a message with timestamp
log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$(date)")
  
  case "$level" in
    "INFO")  echo "[$timestamp] [INFO] $message" ;;
    "WARN")  echo "[$timestamp] [WARN] $message" >&2 ;;
    "ERROR") echo "[$timestamp] [ERROR] $message" >&2 ;;
    *)       echo "[$timestamp] $message" ;;
  esac
}
