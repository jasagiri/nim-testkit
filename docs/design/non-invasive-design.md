# Nim TestKit Non-Invasive Design

This document explains the non-invasive design of Nim TestKit, making it easy to use in existing projects without interfering with current setup or requiring significant configuration changes.

## Design Goals

1. **Minimize Intrusion**: Keep Nim TestKit files separate from the target project's files
2. **Respect Existing Configuration**: Work with existing project configurations without modification
3. **Simple Setup**: Provide a one-command setup process
4. **Unified Interface**: Keep the familiar nimble commands while using isolated scripts

## Architecture

### Directory Structure

Nim TestKit uses a dedicated directory structure to prevent collision with existing project files:

```
your-project/
├── .git/
├── src/                  # Your project source files
├── tests/                # Your project test files
├── your-project.nimble   # Your project .nimble file
└── scripts/
    └── nim-testkit/      # All Nim TestKit scripts in isolated directory
        ├── config/
        │   └── nimtestkit.toml
        ├── generate/     # Test generator scripts
        ├── run/          # Test runner scripts
        ├── guard/        # Test guard scripts 
        ├── coverage/     # Coverage scripts
        └── hooks/        # Git hooks
```

### Standalone Tools

Core functionality is provided through standalone executables:

- **nimtestkit_setup**: Initializes Nim TestKit in an existing project
- **nimtestkit_generator**: Generates test files based on source code
- **nimtestkit_runner**: Runs tests and reports results

### Configuration

Nim TestKit uses its own configuration file (`nimtestkit.toml`) rather than modifying existing ones:

```toml
[directories]
# Source directory (relative to project root)
source = "src"
# Tests directory (relative to project root)
tests = "tests"

[patterns]
# File patterns to include
include = "*.nim"
# Test file naming pattern
test_name = "test_${module}.nim"

[options]
# Coverage threshold percentage
coverage_threshold = 80
```

## Setup Process

When you run `nimble setup` in your project, Nim TestKit:

1. Creates the `scripts/nim-testkit` directory structure
2. Copies template scripts and configuration files
3. Adds Nimble tasks to your project's .nimble file
4. Creates a default configuration file that respects your project's structure

## Integration with Nimble

Nim TestKit adds the following tasks to your .nimble file:

```nim
task generate, "Generate test skeletons":
  exec "scripts/nim-testkit/generate/generate.sh"

task tests, "Run tests":
  exec "scripts/nim-testkit/run/run.sh"

task guard, "Start test guard":
  exec "scripts/nim-testkit/guard/guard.sh"

task coverage, "Generate coverage report":
  exec "scripts/nim-testkit/coverage/coverage.sh"

task install_hooks, "Install git hooks":
  exec "scripts/nim-testkit/hooks/install_hooks.sh"
```

## Usage

After setup, you can use the familiar nimble commands:

```bash
# Generate tests
nimble generate

# Run tests
nimble tests

# Monitor for code changes and run tests automatically
nimble guard

# Generate coverage report
nimble coverage

# Install git hooks
nimble install_hooks
```

## Customization

You can customize Nim TestKit behavior by editing the `scripts/nim-testkit/config/nimtestkit.toml` file in your project.

## Upgrading

To upgrade Nim TestKit in your project:

```bash
# Install the latest version
nimble install nimtestkit

# Re-run setup with the --update flag
nimble setup . --update
```

This will update the scripts while preserving your configuration.