# Nim TestKit

Generic automated test toolkit for Nim projects.

## Overview

Nim TestKit is a versatile test automation toolkit for Nim projects. It helps maintain code quality by automatically generating and running tests, monitoring code coverage, and ensuring new code has associated tests.

## Key Features

- **Automated Test Generation**: Creates test skeletons for functions that don't have tests
- **Cross-Platform Testing**: Specialized tests for all supported platforms
- **Continuous Testing**: Monitors for code changes and automatically runs tests
- **Code Coverage Analysis**: Tracks and reports on test coverage
- **Git Integration**: Pre-commit hooks to enforce testing standards

## Installation

### For New Projects

If you're starting a new Nim project and want to use Nim TestKit:

```bash
# Navigate to your project root directory
cd /path/to/your-project

# Install Nim TestKit from the package repository
nimble install nimtestkit
```

### For Existing Projects

If you already have a Nim project and want to add Nim TestKit, our non-invasive setup makes it easy:

```bash
# Navigate to your project root directory  
cd /path/to/your-project

# Install Nim TestKit
nimble install nimtestkit

# Add to your project's .nimble file dependencies
# Add the following line to your project.nimble file:
# requires "nimtestkit >= 0.1.0"

# Setup Nim TestKit in your project (creates scripts/nim-testkit directory)
nimble setup .
```

This setup will:
1. Create a `scripts/nim-testkit` directory with all necessary scripts
2. Add nimble tasks to your project
3. Create a `nimtestkit.toml` configuration file
4. Respect your existing project structure

### Installing from Source

If you want to install directly from the source repository:

```bash
# Clone the repository
git clone https://github.com/jasagiri/nim-testkit.git
cd nim-testkit

# Install globally
nimble install

# Or link for development
nimble develop
```

### Adding as a Project Dependency

To add Nim TestKit as a dependency to your project's `.nimble` file:

```nim
# In your project's .nimble file
requires "nim >= 1.6.0"
requires "nimtestkit >= 0.1.0"
```

## Usage

### Generating Tests

```bash
nimble generate
```

This command analyzes your Nim codebase, identifies functions without tests, and generates test skeletons for them.

### Running Tests

```bash
nimble tests
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

## Configuration

Nim TestKit uses a `nimtestkit.toml` configuration file to customize its behavior. Here's an overview of key configuration options:

### Power Assert Integration

Nim TestKit comes with [nim-power-assert](https://github.com/jasagiri/nim-power-assert) integration enabled by default. This provides enhanced assertion messages that show the values of all expressions in a failed assertion.

```toml
[tests]
power_assert = true  # Enable power_assert (default: true)
```

#### Benefits of Power Assert

Unlike standard assertions that only show "assertion failed", power_assert provides detailed information:

```nim
# Standard assertion output:
# Error: unhandled exception: assertion failed [AssertionDefect]

# Power assert output:
# Error: assertion failed:
#   assert a + b == c * d
#          |   |    |   |
#          2   3    5   4
#          5        20
```

To disable power_assert and use standard unittest assertions:

```toml
[tests]
power_assert = false
```

### Version Control System (VCS) Integration

Nim TestKit supports multiple version control systems. You can enable/disable each VCS individually:

```toml
[vcs]
git = true          # Enable Git integration (default: true)
jujutsu = false     # Enable Jujutsu integration (default: false)
mercurial = false   # Enable Mercurial (hg) integration (default: false)
svn = false         # Enable Subversion integration (default: false)
fossil = false      # Enable Fossil integration (default: false)
```

When a VCS is enabled, Nim TestKit will:
- Detect changes in your repository
- Run only tests related to modified files
- Show VCS status before running tests
- Support VCS-specific hooks and workflows

#### Jujutsu Integration

When Jujutsu is enabled (`vcs.jujutsu = true`), you get advanced features through MCP-Jujutsu:
- **Change-based testing**: Only run tests affected by current changes
- **Conflict-aware testing**: Get test recommendations during conflict resolution
- **Test caching**: Skip unchanged tests across rebases and operations
- **Best practices**: Automatic guidance for Jujutsu workflows

### Other Configuration Options

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
power_assert = true

[vcs]
git = true
jujutsu = false
mercurial = false
svn = false
fossil = false

[templates]
test = """
import unittest
import power_assert
import "$MODULE"

suite "$MODULE_NAME Tests":
  test "example test":
    assert true
"""
```

## MCP (Model Context Protocol) Integration

Nim TestKit integrates with MCP servers to provide unified VCS operations across Git, GitHub, GitLab, and Jujutsu.

### Setup MCP Integration

```bash
# Set up environment variables (optional but recommended)
export GITHUB_TOKEN="your_github_token"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token"

# Initialize MCP integration
nimble mcp_setup
```

### MCP Commands

#### Status and Management

```bash
nimble mcp_status      # Show MCP server status and VCS info
nimble mcp_stop        # Stop all MCP servers
nimble mcp_list_tools  # List available tools for all servers
nimble mcp_help        # Show detailed help
```

#### Git Operations

```bash
nimble mcp_git status                    # Get repository status
nimble mcp_git commit "Your message"     # Commit changes
```

#### GitHub Operations

```bash
nimble mcp_github create-issue "Bug report" "Description"
nimble mcp_github create-pr "Fix bug" "feature-branch" "main" "PR description"
```

#### GitLab Operations

```bash
nimble mcp_gitlab create-issue "Enhancement" "Description"
nimble mcp_gitlab create-mr "Add feature" "feature-branch" "main" "MR description"
```

#### Jujutsu Operations

```bash
nimble mcp_jujutsu status                # Get Jujutsu status
nimble mcp_jujutsu new "description"     # Create new change
nimble mcp_jujutsu describe "message"    # Update change description
```

### Jujutsu Best Practices

When using Nim TestKit with Jujutsu (with `jujutsu.enabled = true`):

1. **Test Before Creating Changes**: Run tests before `jj new` to ensure clean baseline
2. **Change-Based Testing**: TestKit automatically runs only tests affected by your current change
3. **Conflict Resolution**: Get test recommendations during conflict resolution
4. **Test Caching**: Tests are cached per change ID, surviving rebases and operations
5. **Workspace Testing**: Use `jj workspace` to test different configurations in parallel
6. **Split Test Changes**: Use `jj split` to separate test additions from implementation
7. **Document Coverage**: Include test coverage info in change descriptions with `jj describe`

### MCP Server Dependencies

The MCP integration relies on server implementations in the `vendor/` directory:

- **Git**: `vendor/servers/src/git` (Python-based MCP server)
- **GitHub**: `vendor/servers/src/github` (Node.js-based MCP server)
- **GitLab**: `vendor/servers/src/gitlab` (Node.js-based MCP server)
- **Jujutsu**: `vendor/mcp-jujutsu` (Nim-based MCP server)

### Environment Variables

- `GITHUB_TOKEN`: GitHub personal access token for API operations
- `GITLAB_PERSONAL_ACCESS_TOKEN`: GitLab personal access token for API operations

### MCP Features

- **Unified Interface**: Single command-line interface for multiple VCS platforms
- **Automatic Detection**: Automatically detects repository type and remote platforms
- **Token Management**: Secure token handling through environment variables
- **Async Operations**: Non-blocking MCP communication for better performance
- **Error Handling**: Comprehensive error reporting and recovery

## Integration with Your Project

To integrate Nim TestKit with your project:

1. Install the toolkit as described above
2. Add it to your project's nimble dependencies:
   ```nim
   # In your project.nimble file
   requires "nimtestkit >= 0.1.0"
   ```
3. Create the required directory structure:
   ```bash
   mkdir -p src tests
   ```
4. Run `nimble generate` to create initial tests for your functions
5. Use `nimble tests` to execute tests
6. Create a `nimtestkit.toml` configuration file to customize test generation

### Quick Start Example

```bash
# Create a new Nim project
mkdir my-nim-project
cd my-nim-project
nimble init

# Install Nim TestKit
nimble install nimtestkit

# Create source and test directories  
mkdir -p src tests

# Set up Nim TestKit in your project
nimble setup .

# Generate tests for your code
nimble generate

# Run the generated tests
nimble tests
```

## Project Structure

- `src/`: Source code for the toolkit
  - Core tools:
    - `test_generator.nim`: Generates test skeletons for untested functions
    - `test_runner.nim`: Runs all tests
    - `test_guard.nim`: Monitors code changes and triggers tests
    - `coverage_helper.nim`: Generates code coverage reports
  - Standalone tools:
    - `nimtestkit_setup.nim`: Initializes Nim TestKit in existing projects
    - `nimtestkit_generator.nim`: Standalone test generator
    - `nimtestkit_runner.nim`: Standalone test runner
- `templates/`: Template files for project setup
  - `nim-testkit/config/`: Configuration templates
  - `nim-testkit/scripts/`: Script templates
- `scripts/`: Supporting scripts and tools (for Nim TestKit development)
  - `generate/`: Test generation scripts
  - `run/`: Test running scripts
  - `guard/`: Continuous testing scripts
  - `coverage/`: Coverage reporting scripts
  - `hooks/`: Git hook scripts
- `build/`: Build artifacts (generated during build process)
  - `debug/`: Debug build artifacts
    - `windows/`: Windows specific binaries
    - `linux/`: Linux specific binaries
    - `macos/`: macOS specific binaries
  - `release/`: Release build artifacts
    - `windows/`: Windows specific binaries
    - `linux/`: Linux specific binaries
    - `macos/`: macOS specific binaries
- `bin/`: Distribution binaries (copied from release build)

## Building

### Debug Build

For development and testing:

```bash
nimble build_debug
```

Debug builds are placed in `build/debug/<platform>/`.

### Release Build

For optimized binaries:

```bash
nimble build_release
```

Release builds are placed in `build/release/<platform>/`.

### Distribution

To create distribution binaries:

```bash
nimble dist
```

This runs the release build and copies the binaries to the `bin/` directory.

## License

MIT

Generated on 2025-05-19