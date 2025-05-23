#!/bin/sh
# Generate README.md for Nim TestKit

# Get script directory path
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT_DIR=$(dirname "$(dirname "$SCRIPT_DIR")")

# Create README generator module if it doesn't exist
README_GENERATOR="$ROOT_DIR/scripts/readme/generate_readme.nim"
if [ ! -f "$README_GENERATOR" ]; then
  echo "Creating README generator module..."
  mkdir -p "$(dirname "$README_GENERATOR")"
  cat > "$README_GENERATOR" << 'ENDOFFILE'
## Nim TestKit README Generator
##
## Generates a README.md file for the test toolkit

import std/[os, strformat, times]

proc generateReadme*() =
  let readmePath = getCurrentDir() / ".." / "README.md"
  
  let content = fmt"""# Nim TestKit

Automated test toolkit for Nim projects.

## Overview

Nim TestKit is a specialized test automation toolkit for Nim projects. It helps maintain code quality by automatically generating and running tests, monitoring code coverage, and ensuring new code has associated tests.

## Key Features

- **Automated Test Generation**: Creates test skeletons for functions that don't have tests
- **Cross-Platform Testing**: Specialized tests for all supported platforms
- **Continuous Testing**: Monitors for code changes and automatically runs tests
- **Code Coverage Analysis**: Tracks and reports on test coverage
- **Git Integration**: Pre-commit hooks to enforce testing standards

## Installation

```bash
nimble install nimtestkit
```

## Usage

### Generating Tests

```bash
nimble generate
```

This command analyzes your codebase, identifies functions without tests, and generates test skeletons for them.

### Running Tests

```bash
nimble run
```

Runs all the tests that have been generated or manually created.

### Continuous Testing

```bash
nimble guard
```

Starts the test guard, which monitors source files for changes and automatically runs tests when changes are detected.

### Coverage Analysis

```bash
nimble coverage
```

Generates a code coverage report to help identify areas of the codebase that need more testing.

### Installing Git Hooks

```bash
nimble install_hooks
```

Installs Git hooks to automatically run tests before allowing commits.

## Project Structure

- `src/`: Source code for the toolkit
  - `test_generator.nim`: Generates test skeletons for untested functions
  - `test_runner.nim`: Runs all tests
  - `test_guard.nim`: Monitors code changes and triggers tests
  - `coverage_helper.nim`: Generates code coverage reports
- `scripts/`: Supporting scripts and tools
  - `generate/`: Test generation scripts
  - `run/`: Test running scripts
  - `guard/`: Continuous testing scripts
  - `coverage/`: Coverage reporting scripts
  - `hooks/`: Git hook scripts

## License

MIT

Generated on {now()}"""
  
  # Write the README
  writeFile(readmePath, content)
  echo fmt"Generated README: {readmePath}"

when isMainModule:
  generateReadme()
ENDOFFILE
fi

# Build and run README generator
cd "$ROOT_DIR"
nim c -r scripts/readme/generate_readme.nim