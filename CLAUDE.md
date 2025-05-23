# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Nim TestKit is a versatile test automation toolkit for Nim projects. It helps maintain code quality by automatically generating and running tests, monitoring code coverage, and ensuring new code has associated tests.

## Commands

### Build and Install

```bash
nimble install
```

### Common Development Commands

#### Generate Test Skeletons

```bash
nimble generate
```

Analyzes the Nim codebase, identifies functions without tests, and generates test skeletons for them.

#### Run Tests

```bash
nimble run
```

Runs all the tests that have been generated or manually created.

#### Run Toolkit Self-Tests

```bash
nimble test
```

Runs the self-tests for the Nim TestKit itself.

#### Start Continuous Testing

```bash
nimble guard
```

Starts the test guard, which monitors source files for changes and automatically runs tests when changes are detected.

#### Generate Code Coverage Reports

```bash
nimble coverage
```

Generates a code coverage report to identify areas of the codebase that need more testing.

#### Install Git Hooks

```bash
nimble install_hooks
```

Installs Git hooks to automatically run tests before allowing commits.

#### Generate README

```bash
nimble readme
```

Generates the README.md file from the source code documentation.

## Architecture

### Core Components

1. **Test Generator** (`src/test_generator.nim`):
   - Analyzes a codebase for functions without tests
   - Generates test skeletons for untested functions
   - Creates new test files or updates existing ones

2. **Test Runner** (`src/test_runner.nim`):
   - Discovers and runs all tests in the tests/ directory
   - Reports test results and overall status

3. **Test Guard** (`src/test_guard.nim`):
   - Monitors source code for changes
   - Automatically runs tests when changes are detected
   - Provides continuous feedback during development

4. **Coverage Helper** (`src/coverage_helper.nim`):
   - Generates code coverage reports
   - Identifies areas of the codebase with insufficient test coverage

### Directory Structure

- `src/`: Core toolkit implementation
  - `config.nim`: Configuration system with TOML support
  - `jujutsu.nim`: Jujutsu VCS integration
  - `vcs_commands.nim`: Version control system commands
  - `doc_generator.nim`: Documentation and badge generation
- `scripts/`: Platform-specific scripts for each feature
  - `generate/`: Test generation scripts
  - `run/`: Test running scripts
  - `guard/`: Continuous testing scripts
  - `coverage/`: Coverage reporting scripts
  - `hooks/`: Git hook scripts
- `tests/`: Self-tests for the toolkit
- `build/`: Build artifacts and coverage reports
- `docs/`: Generated documentation

### Configuration

The toolkit uses a `nimtestkit.toml` configuration file with the following options:

```toml
[directories]
source = "src"
tests = "tests"

[patterns]
include = ["*.nim"]
exclude = ["*_test.nim", "test_*.nim"]
test_name = "${module}_test.nim"

[coverage]
threshold = 80.0

[tests]
parallel = false
color = true

[templates]
test = """
import unittest
import "$MODULE"

suite "$MODULE_NAME Tests":
  test "example test":
    check true
"""
```

### New Features

- **Configuration System**: Full TOML-based configuration
- **Coverage Implementation**: Real coverage analysis with HTML reports
- **Enhanced Test Runner**: Colored output, JUnit XML, TAP format, parallel execution
- **Smarter Test Generation**: Async support, Result types, property-based templates
- **Jujutsu Integration**: Change-based testing, conflict detection, cache support
- **Documentation Generation**: Markdown docs, coverage reports, API docs, badges
- **Power Assert Integration**: Enhanced assertion messages showing expression values (enabled by default)
- **MCP-Jujutsu Integration**: Advanced Jujutsu support with best practices guidance (optional)
- **Multi-VCS Support**: Configurable support for Git, Jujutsu, Mercurial, SVN, and Fossil