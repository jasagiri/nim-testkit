#!/bin/sh
# Helper function to find and use pre-built binaries

# Function to find and run the appropriate binary
find_and_run_binary() {
  local binary_name="$1"
  shift  # Remove first argument, leaving the rest as $@
  
  # Get script directory path and find project root
  local SCRIPT_DIR=$(dirname "$(realpath "$0")")
  local ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")
  
  # Determine architecture
  local ARCH="linux"
  if [ "$(uname)" = "Darwin" ]; then
    ARCH="macos"
  elif [ "$(uname -o 2>/dev/null)" = "Msys" ] || [ -n "$WINDIR" ]; then
    ARCH="windows"
    binary_name="${binary_name}.exe"
  fi
  
  # Define binary paths
  local DEBUG_BIN="${ROOT_DIR}/build/debug/${ARCH}/${binary_name}"
  local RELEASE_BIN="${ROOT_DIR}/build/release/${ARCH}/${binary_name}"
  local DIST_BIN="${ROOT_DIR}/bin/${binary_name}"
  
  # Use the most appropriate binary
  if [ -f "$DIST_BIN" ]; then
    # Use distribution binary if available
    "$DIST_BIN" "$@"
  elif [ -f "$RELEASE_BIN" ]; then
    # Use release binary if available
    "$RELEASE_BIN" "$@"
  elif [ -f "$DEBUG_BIN" ]; then
    # Use debug binary if available
    "$DEBUG_BIN" "$@"
  else
    # Build and run from source
    echo "No pre-built binary found. Building from source..."
    cd "$ROOT_DIR" && nim c -r "src/${binary_name}.nim" "$@"
  fi
}