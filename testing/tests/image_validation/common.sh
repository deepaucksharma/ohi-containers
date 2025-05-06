#!/bin/bash
# Shared utilities for image validation tests

# Load the common utilities from the correct location
testing_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Source the actual common.sh file
. "$testing_root/lib/common.sh"
