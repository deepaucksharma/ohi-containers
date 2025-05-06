@echo off
REM Wrapper script to run tests from the root directory
echo Running New Relic tests...
call testing\runners\test.bat %*
