# Nim TestKit Setup Guide

This guide explains how to set up Nim TestKit in your existing Nim project.

## Prerequisites

- Nim (version 1.6.0 or higher)
- Nimble (the Nim package manager)
- A Nim project with a `.nimble` file

## Installation

### 1. Install Nim TestKit

```bash
nimble install nimtestkit
```

### 2. Add as a Dependency

Add Nim TestKit to your project's `.nimble` file:

```nim
requires "nim >= 1.6.0"
requires "nimtestkit >= 0.1.0"
```

### 3. Setup in Your Project

Run the setup command in your project directory:

```bash
cd /path/to/your-project
nimble setup .
```

This will:
- Create the necessary directory structure
- Add nimble tasks to your project
- Create a default configuration

## Verifying Installation

After setup, you should have:

1. A `scripts/nim-testkit` directory in your project
2. Nimble tasks in your `.nimble` file
3. A default configuration file

## Basic Usage

### Generating Tests

```bash
nimble generate
```

This will analyze your source files and generate test skeletons for untested functions.

### Running Tests

```bash
nimble tests
```

This will execute all your tests and report results.

### Continuous Testing

```bash
nimble guard
```

This will monitor your source files for changes and automatically run tests when files are modified.

### Coverage Analysis

```bash
nimble coverage
```

This will generate a code coverage report to help identify untested code.

### Git Hooks

```bash
nimble install_hooks
```

This will install Git hooks to run tests before commits.

## Configuration

Nim TestKit uses a configuration file located at `scripts/nim-testkit/config/nimtestkit.toml`.

Example configuration:

```toml
[directories]
source = "src"
tests = "tests"

[patterns]
include = "*.nim"
test_name = "test_${module}.nim"

[options]
coverage_threshold = 80
```

For full configuration options, see the [Configuration Reference](configuration.md).

## Troubleshooting

### Common Issues

1. **Nimble tasks not found**:
   - Check that the setup command completed successfully
   - Verify that tasks were added to your `.nimble` file

2. **Tests not generating**:
   - Check your source directory path in the configuration file
   - Verify that your files match the include pattern

3. **Scripts permission issues**:
   - Make scripts executable with `chmod +x scripts/nim-testkit/**/*.sh`

## Upgrading

To upgrade Nim TestKit in your project:

```bash
# Install latest version
nimble install nimtestkit

# Update scripts
nimble setup . --update
```

## Custom Integration

For custom build systems or specialized project structures, see the [Advanced Integration Guide](advanced-integration.md).

## Next Steps

- Customize your test templates
- Configure coverage thresholds
- Add CI/CD integration
- Review the non-invasive design documentation