#!/bin/bash
# Build nim-testkit with size optimization

set -e

echo "Building nim-testkit with size optimization..."

# Save current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create build directory
mkdir -p build

# Build core modules with size optimization
echo "Building optimized binaries..."
nim c --skipCfg --skipParentCfg --mm:orc --opt:size -o:build/nimtestkit src/nimtestkit.nim

# Build test runner if needed
if [ -f "src/runner/main.nim" ]; then
    nim c --skipCfg --skipParentCfg --mm:orc --opt:size -o:build/testrunner src/runner/main.nim
fi

# Show binary sizes
echo ""
echo "Optimized binary sizes:"
ls -lh build/

echo ""
echo "✅ Build completed successfully!"