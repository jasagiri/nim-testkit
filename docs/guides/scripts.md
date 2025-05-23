# Scripts Guide

Nim TestKit provides a comprehensive set of scripts to automate testing workflows. This guide covers all available scripts and their usage.

## Overview

Scripts are organized by function and available for multiple platforms:

```
scripts/
├── generate/     # Test generation
├── run/          # Test execution  
├── guard/        # Continuous testing
├── coverage/     # Coverage analysis
├── hooks/        # VCS hooks
├── readme/       # Documentation
└── common/       # Shared utilities
```

## Generate Scripts {#generate}

### Purpose
Automatically generate test skeletons for functions without existing tests.

### Available Scripts

#### `generate.sh` / `generate.bat`
**Location**: `scripts/generate/`
**Purpose**: Generate tests for all untested functions

```bash
# Unix/Linux/macOS
./scripts/generate/generate.sh

# Windows
scripts\generate\generate.bat

# Via nimble
nimble generate
```

**Features:**
- Analyzes source code for functions without tests
- Generates test skeletons with proper imports
- Creates test files following naming conventions
- Supports custom templates
- Handles async functions and property-based tests

**Configuration:**
```toml
# nimtestkit.toml
[generation]
source_dir = "src"
test_dir = "tests"
template = "unittest"  # or "property_based", "async"

[patterns]
include = ["*.nim"]
exclude = ["*_test.nim", "test_*.nim"]
test_name = "${module}_test.nim"
```

**Example Output:**
```
Analyzing source files...
Found 15 functions without tests:
- src/auth.nim: login, logout, validate
- src/api.nim: makeRequest, parseResponse
Generated 3 test files:
- tests/auth_test.nim
- tests/api_test.nim
```

## Run Scripts {#run}

### Purpose
Execute tests with various output formats and reporting options.

### Available Scripts

#### `run.sh` / `run.bat`
**Location**: `scripts/run/`
**Purpose**: Run all tests with enhanced reporting

```bash
# Unix/Linux/macOS
./scripts/run/run.sh

# Windows  
scripts\run\run.bat

# Via nimble
nimble tests
```

**Features:**
- Colored output for test results
- JUnit XML output for CI integration
- TAP (Test Anything Protocol) format
- Parallel test execution
- Filter tests by pattern

**Options:**
```bash
# Run with specific format
./scripts/run/run.sh --format=junit
./scripts/run/run.sh --format=tap
./scripts/run/run.sh --format=colored

# Run specific tests
./scripts/run/run.sh --filter="auth_test"
./scripts/run/run.sh --pattern="test_api_*"

# Parallel execution
./scripts/run/run.sh --parallel=4
```

**Configuration:**
```toml
# nimtestkit.toml
[tests]
parallel = false
color = true
format = "colored"  # "junit", "tap", "colored"
timeout = 30

[filters]
include_patterns = ["test_*.nim"]
exclude_patterns = ["test_*_slow.nim"]
```

## Guard Scripts {#guard}

### Purpose
Monitor source files for changes and automatically run tests.

### Available Scripts

#### `guard.sh` / `guard.bat`
**Location**: `scripts/guard/`
**Purpose**: Continuous testing with file monitoring

```bash
# Unix/Linux/macOS
./scripts/guard/guard.sh

# Windows
scripts\guard\guard.bat

# Via nimble
nimble guard
```

**Features:**
- Real-time file system monitoring
- Intelligent test selection based on changes
- Debounced execution to avoid rapid runs
- Visual indicators for test status
- Integration with desktop notifications

**Configuration:**
```toml
# nimtestkit.toml
[guard]
watch_dirs = ["src", "tests"]
watch_patterns = ["*.nim", "*.nims"]
exclude_patterns = [".git/**", "build/**"]
debounce_ms = 500

[guard.notifications]
enabled = true
success_sound = true
failure_sound = true
```

**Example Output:**
```
===== Nim TestKit Guard =====
Monitoring for source code changes...
[14:30:15] Source code changes detected ⚡
[14:30:15] Running tests for: src/auth.nim
[14:30:16] ✅ All tests passed (5/5)
[14:30:16] Monitoring for changes...
```

## Coverage Scripts {#coverage}

### Purpose
Generate and analyze code coverage reports.

### Available Scripts

#### `coverage.sh` / `coverage.bat`
**Location**: `scripts/coverage/`
**Purpose**: Generate comprehensive coverage reports

```bash
# Unix/Linux/macOS
./scripts/coverage/coverage.sh

# Windows
scripts\coverage\coverage.bat

# Via nimble
nimble coverage
```

**Features:**
- Line coverage analysis
- Branch coverage reporting  
- HTML report generation
- Coverage threshold enforcement
- Integration with CI systems

#### `show_coverage.sh`
**Purpose**: Display coverage results in browser

```bash
./scripts/coverage/show_coverage.sh
```

**Configuration:**
```toml
# nimtestkit.toml
[coverage]
threshold = 80.0
output_dir = "build/coverage"
html_report = true
exclude_dirs = ["tests", "vendor"]

[coverage.formats]
html = true
xml = true
json = false
```

**Example Output:**
```
Generating coverage report...
Running tests with coverage...
Analyzing coverage data...

Coverage Summary:
- src/auth.nim: 95.2% (40/42 lines)
- src/api.nim: 87.5% (35/40 lines)
- src/utils.nim: 100.0% (15/15 lines)

Overall Coverage: 92.8%
✅ Coverage above threshold (80.0%)

HTML report: build/coverage/index.html
```

## Hook Scripts {#hooks}

### Purpose
VCS hooks for automated testing and quality enforcement.

### Available Scripts

#### `install_hooks.sh` / `install_hooks.bat`
**Location**: `scripts/hooks/`
**Purpose**: Install VCS hooks for automated testing

```bash
# Unix/Linux/macOS
./scripts/hooks/install_hooks.sh

# Windows
scripts\hooks\install_hooks.bat

# Via nimble
nimble install_hooks
```

#### `pre-commit`
**Purpose**: Pre-commit hook that runs tests before commits

**Features:**
- Runs tests on staged files
- Prevents commits if tests fail
- Supports multiple VCS types (Git, Jujutsu)
- Configurable test selection

**Configuration:**
```toml
# nimtestkit.toml
[hooks]
pre_commit = true
pre_push = false
test_command = "nimble tests --fast"

[hooks.git]
enabled = true
skip_on_merge = false

[hooks.jujutsu]
enabled = true
validate_description = true
```

**Example:**
```bash
$ git commit -m "Add new feature"
Running pre-commit tests...
✅ All tests passed
[main abc1234] Add new feature
```

## MCP Scripts {#mcp}

### Purpose
MCP (Model Context Protocol) operations for unified VCS management.

### Available Commands

#### Setup and Management
```bash
# Initialize MCP integration
nimble mcp_setup

# Check server status
nimble mcp_status

# Stop all servers
nimble mcp_stop

# List available tools
nimble mcp_list_tools

# Show help
nimble mcp_help
```

#### VCS Operations
```bash
# Git operations
nimble mcp_git status
nimble mcp_git commit "Message"

# GitHub operations
nimble mcp_github create-issue "Title" "Description"
nimble mcp_github create-pr "Title" "branch" "base" "Description"

# GitLab operations
nimble mcp_gitlab create-issue "Title" "Description"
nimble mcp_gitlab create-mr "Title" "source" "target" "Description"

# Jujutsu operations
nimble mcp_jujutsu status
```

**Configuration:**
```bash
# Authentication
export GITHUB_TOKEN="your_github_token"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token"

# Custom API URLs (optional)
export GITHUB_API_URL="https://api.github.com"
export GITLAB_API_URL="https://gitlab.com/api/v4"
```

## README Scripts {#readme}

### Purpose
Generate and update project documentation.

### Available Scripts

#### `readme.sh` / `readme.bat`
**Location**: `scripts/readme/`
**Purpose**: Generate README.md from source documentation

```bash
# Unix/Linux/macOS
./scripts/readme/readme.sh

# Windows
scripts\readme\readme.bat

# Via nimble
nimble readme
```

**Features:**
- Extract documentation from source code
- Generate API documentation
- Create coverage badges
- Update project statistics
- Markdown formatting

## Common Utilities {#common}

### Purpose
Shared utilities used by other scripts.

### Available Utilities

#### `bin_helper.sh`
**Location**: `scripts/common/`
**Purpose**: Binary and path management utilities

**Functions:**
- `find_nim_binary()` - Locate Nim compiler
- `setup_path()` - Configure PATH for tools
- `check_dependencies()` - Verify required tools
- `platform_detect()` - Detect operating system

**Usage in Scripts:**
```bash
#!/bin/bash
source "$(dirname "$0")/../common/bin_helper.sh"

# Use utility functions
find_nim_binary
check_dependencies "git" "nimble"
setup_path
```

## Cross-Platform Considerations

### File Paths
Scripts handle path differences automatically:

```bash
# Unix-style paths in .sh files
SOURCE_DIR="src"
TEST_DIR="tests"

# Windows-style paths in .bat files
SET SOURCE_DIR=src
SET TEST_DIR=tests
```

### Executable Permissions
Unix scripts include permission setup:

```bash
# Made executable automatically
chmod +x scripts/**/*.sh
```

### Environment Variables
Platform-specific environment handling:

```bash
# Unix/Linux/macOS (.sh)
export NIMTESTKIT_DEBUG=1

# Windows (.bat)
SET NIMTESTKIT_DEBUG=1
```

## Custom Scripts

### Creating Custom Scripts

1. **Follow Naming Convention:**
   ```
   scripts/
   └── your_feature/
       ├── your_script.sh      # Unix/Linux/macOS
       ├── your_script.bat     # Windows
       └── README.md           # Documentation
   ```

2. **Use Common Utilities:**
   ```bash
   #!/bin/bash
   source "$(dirname "$0")/../common/bin_helper.sh"
   
   # Your script logic here
   ```

3. **Add Nimble Task:**
   ```nim
   # In nimtestkit.nimble
   task your_feature, "Description of your feature":
     when defined(windows):
       exec "scripts\\your_feature\\your_script.bat"
     else:
       exec "scripts/your_feature/your_script.sh"
   ```

### Script Template

```bash
#!/bin/bash
# Your Script Name
# Description of what this script does

set -e  # Exit on error

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bin_helper.sh"

# Configuration
DEFAULT_CONFIG="your_default_value"
YOUR_CONFIG="${YOUR_CONFIG:-$DEFAULT_CONFIG}"

# Main logic
main() {
    echo "Starting your script..."
    
    # Check dependencies
    check_dependencies "nim" "nimble"
    
    # Your implementation here
    echo "Script completed successfully!"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## Integration Examples

### CI/CD Integration

#### GitHub Actions
```yaml
name: Automated Testing
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Nim
        uses: jiro4989/setup-nim-action@v1
      - name: Install dependencies
        run: nimble install -y
      - name: Generate tests
        run: nimble generate
      - name: Run tests
        run: nimble tests
      - name: Generate coverage
        run: nimble coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

#### GitLab CI
```yaml
stages:
  - test
  - coverage

test:
  stage: test
  script:
    - nimble install -y
    - nimble generate
    - nimble tests

coverage:
  stage: coverage
  script:
    - nimble coverage
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: build/coverage/coverage.xml
```

### Pre-commit Framework Integration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: nim-testkit-generate
        name: Generate missing tests
        entry: nimble generate
        language: system
        pass_filenames: false
        
      - id: nim-testkit-test
        name: Run tests
        entry: nimble tests --fast
        language: system
        pass_filenames: false
```

---

*For more specific script configurations and advanced usage, see the individual tool documentation in the [API reference](../api/).*