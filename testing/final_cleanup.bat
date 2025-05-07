@echo off
echo Executing final cleanup of redundant test directories...

REM Remove old test directories that have been completely replaced
echo Removing old test directories...
rd /s /q D:\NewRelic\db-aws\docker\testing\tests\config_validation
rd /s /q D:\NewRelic\db-aws\docker\testing\tests\db_monitoring
rd /s /q D:\NewRelic\db-aws\docker\testing\tests\integration
rd /s /q D:\NewRelic\db-aws\docker\testing\tests\performance
rd /s /q D:\NewRelic\db-aws\docker\testing\tests\unit

REM Remove run_tests.bat from root after everything is migrated
echo Removing old runner script...
del D:\NewRelic\db-aws\docker\run_tests_in_docker.bat 2>nul

echo Final cleanup complete. The new Bats-based testing structure is now the primary testing framework.
echo To run tests, use the new Makefile-based system:
echo   cd testing
echo   make test
