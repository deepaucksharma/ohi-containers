#!/bin/sh 
echo "Testing on Linux environment" 
echo "Detecting platform: $(uname -s)" 
if [ -f "/app/lib/common.sh" ]; then 
  . /app/lib/common.sh 
  platform=$(detect_platform) 
  echo "Platform detected by library: $platform" 
  temp_dir=$(get_temp_dir) 
  echo "Temporary directory: $temp_dir" 
  docker_command=$(docker_cmd) 
  echo "Docker command: $docker_command" 
  echo "[LINUX TEST PASSED]" 
else 
  echo "[ERROR] Cannot find common.sh library" 
  exit 1 
fi 
