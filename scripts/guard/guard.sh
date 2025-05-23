#!/bin/sh
# Start the Nim TestKit guard (continuous testing)

# Get script directory path
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

# Source the helper script
. "$ROOT_DIR/scripts/common/bin_helper.sh"

# Use the helper function to find and run the appropriate binary
find_and_run_binary "test_guard" "$@"