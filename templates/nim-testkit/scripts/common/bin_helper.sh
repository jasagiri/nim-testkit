#!/bin/sh
# Helper function to find and use pre-built binaries

# Function to find and run the appropriate binary
find_and_run_binary() {
  local binary_name="$1"
  shift  # Remove first argument, leaving the rest as $@
  
  # Determine architecture
  local ARCH="linux"
  if [ "$(uname)" = "Darwin" ]; then
    ARCH="macos"
  elif [ "$(uname -o 2>/dev/null)" = "Msys" ] || [ -n "$WINDIR" ]; then
    ARCH="windows"
    binary_name="${binary_name}.exe"
  fi
  
  # Try to find the binary from nimble path
  if command -v nimble > /dev/null; then
    local NIMBLE_BIN=$(nimble path nimtestkit 2>/dev/null)"/bin/${binary_name}"
    if [ -f "$NIMBLE_BIN" ]; then
      "$NIMBLE_BIN" "$@"
      return $?
    fi
  fi
  
  # Fall back to using the nimtestkit_* binary directly from PATH
  if command -v "nimtestkit_${binary_name}" > /dev/null; then
    "nimtestkit_${binary_name}" "$@"
    return $?
  fi
  
  # If all else fails, try to build from source
  echo "Error: ${binary_name} not found in path or nimble package."
  echo "Please ensure Nim TestKit is properly installed."
  return 1
}