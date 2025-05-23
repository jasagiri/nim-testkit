#!/bin/sh
# Install git hooks for Nim TestKit

# Get the root directory
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$ROOT_DIR" ]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

# Check if hooks directory exists
if [ ! -d "$ROOT_DIR/.git/hooks" ]; then
  echo "Error: .git/hooks directory not found"
  exit 1
fi

# Get the script directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Copy the pre-commit hook
cp "$SCRIPT_DIR/pre-commit" "$ROOT_DIR/.git/hooks/"
chmod +x "$ROOT_DIR/.git/hooks/pre-commit"

echo "Git hooks installed successfully"