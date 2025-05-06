#!/bin/bash
# Wrapper script to run tests from the root directory
echo "Running New Relic tests..."
./testing/runners/test.sh "$@"
