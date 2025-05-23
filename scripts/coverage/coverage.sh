#!/bin/sh
# Generate code coverage reports for Nim TestKit

# Get script directory path
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

# Source the helper script
. "$ROOT_DIR/scripts/common/bin_helper.sh"

# Create build directories
mkdir -p "$ROOT_DIR/build/coverage/html" "$ROOT_DIR/build/coverage/raw"

# Clean nimcache to avoid contamination
rm -rf "$ROOT_DIR/build/nimcache"
mkdir -p "$ROOT_DIR/build/nimcache"

# Run all tests with coverage flags
echo "Running tests with coverage flags..."
for testfile in "$ROOT_DIR"/tests/test_*.nim; do
  if [ "$(basename "$testfile")" != "test_coverage_helper.nim" ] && 
     [ "$(basename "$testfile")" != "test_runner.nim" ] && 
     [ "$(basename "$testfile")" != "test_runner_enhancements.nim" ]; then
    echo "Testing $(basename "$testfile")..."
    nim c --debugger:native --passC:--coverage --passL:--coverage -r "$testfile"
  fi
done

# Generate coverage report
echo "Generating coverage report..."
find_and_run_binary "coverage_helper" "$@"

echo "Coverage analysis completed!"