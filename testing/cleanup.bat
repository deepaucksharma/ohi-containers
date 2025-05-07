@echo off
echo Cleaning up redundant test files...

REM Remove old test scripts that have been replaced
echo Removing old integration test scripts...
del /Q D:\NewRelic\db-aws\docker\testing\tests\integration\mysql\*.sh
del /Q D:\NewRelic\db-aws\docker\testing\tests\integration\postgres\*.sh
del /Q D:\NewRelic\db-aws\docker\testing\tests\image_validation\layer_test.sh

REM Remove old duplicate workflow files
echo Removing duplicate workflow files...
del /Q D:\NewRelic\db-aws\docker\.github\workflows\test-integration.yml

REM Copy fixtures if needed
echo Ensuring fixtures are copied to new location...
if not exist D:\NewRelic\db-aws\docker\testing\fixtures\mysql\init.sql (
    xcopy /Y D:\NewRelic\db-aws\docker\testing\tests\fixtures\mysql\*.* D:\NewRelic\db-aws\docker\testing\fixtures\mysql\
)
if not exist D:\NewRelic\db-aws\docker\testing\fixtures\postgres\init.sql (
    xcopy /Y D:\NewRelic\db-aws\docker\testing\tests\fixtures\postgres\*.* D:\NewRelic\db-aws\docker\testing\fixtures\postgres\
)
if not exist D:\NewRelic\db-aws\docker\testing\fixtures\wiremock\*.* (
    xcopy /Y D:\NewRelic\db-aws\docker\testing\tests\fixtures\wiremock\*.* D:\NewRelic\db-aws\docker\testing\fixtures\wiremock\
)

echo Cleanup complete.
