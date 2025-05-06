@echo off
:: Docker Compose compatibility helper for Windows
:: Determines the correct Docker Compose command based on environment

:: Check for Docker Compose V2
docker compose version >nul 2>&1
if %ERRORLEVEL% equ 0 (
  :: Docker Compose V2 is available
  docker compose %*
) else (
  :: Try Docker Compose V1
  docker-compose --version >nul 2>&1
  if %ERRORLEVEL% equ 0 (
    :: Docker Compose V1 is available
    docker-compose %*
  ) else (
    :: Docker Compose not found
    echo ERROR: Docker Compose not found. Please install Docker Compose and try again.
    exit /b 1
  )
)
