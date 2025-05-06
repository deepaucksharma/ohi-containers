#!/bin/sh
# Docker Compose compatibility helper
# Determines the correct Docker Compose command based on environment

# Detect the Docker Compose command format
if docker compose version >/dev/null 2>&1; then
  # Docker Compose V2 (part of Docker CLI as 'docker compose')
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  # Docker Compose V1 (standalone 'docker-compose' command)
  COMPOSE_CMD="docker-compose"
else
  echo "ERROR: Docker Compose not found. Please install Docker Compose and try again."
  exit 1
fi

# Execute the command with all arguments passed to this script
$COMPOSE_CMD "$@"
