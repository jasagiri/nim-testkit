# Nim TestKit Configuration Reference

This document details the configuration options available in the `nimtestkit.toml` file.

## Basic Structure

```toml
[directories]
source = "src"  
tests = "tests"

[patterns]
include = "*.nim"
exclude = ""
test_name = "test_${module}.nim"

[options]
coverage_threshold = 80
parallel_tests = true
color_output = true
```

## Configuration Sections

### [directories]

Directory paths relative to your project root:

| Option | Description | Default |
|--------|-------------|---------|
| `source` | Source code directory | `"src"` |
| `tests` | Test files directory | `"tests"` |
| `output` | Directory for generated reports | `"build/test-results"` |

### [patterns]

Pattern specifications for files:

| Option | Description | Default |
|--------|-------------|---------|
| `include` | Glob pattern for files to include | `"*.nim"` |
| `exclude` | Glob pattern for files to exclude | `""` |
| `test_name` | Template for test file names<br>Variables: `${module}`, `${dir}` | `"test_${module}.nim"` |

### [options]

General test behavior options:

| Option | Description | Default |
|--------|-------------|---------|
| `coverage_threshold` | Minimum acceptable coverage percentage | `80` |
| `parallel_tests` | Run tests in parallel | `true` |
| `color_output` | Use colored output in terminal | `true` |
| `verbose` | Show detailed test output | `false` |
| `fail_fast` | Stop after first test failure | `false` |

### [tests]

Test execution configuration:

| Option | Description | Default |
|--------|-------------|---------|
| `parallel` | Run tests in parallel | `false` |
| `color` | Use colored output in terminal | `true` |
| `power_assert` | Enable power assertions for better error messages | `true` |

#### Power Assertions

Power assertions provide enhanced error messages that show the values of all sub-expressions when an assertion fails. This feature is enabled by default and significantly improves debugging experience.

**Benefits of Power Assertions:**

- **Detailed Failure Information**: Shows the value of each sub-expression in a failed assertion
- **Better Debugging**: No need to add print statements to understand what went wrong
- **Visual Expression Tree**: Displays the assertion in a tree-like format showing intermediate values
- **Zero Runtime Cost**: Only activated when assertions fail

**Example: Power Assert vs Regular Assert**

Consider this failing assertion:
```nim
let users = @["alice", "bob"]
let index = 2
assert users[index] == "charlie"
```

Regular assertion output:
```
Error: unhandled exception: assertion failed [AssertionDefect]
```

Power assertion output:
```
assert users[index] == "charlie"
       |    |       |
       |    2       false
       @["alice", "bob"]
       
Error: index 2 not in 0 .. 1 [IndexDefect]
```

To disable power assertions, set `power_assert = false` in your `nimtestkit.toml`:

```toml
[tests]
power_assert = false
```

### [templates]

Test template customization:

| Option | Description | Default |
|--------|-------------|---------|
| `basic_test` | Path to custom basic test template | `""` |
| `parameterized_test` | Path to custom parameterized test template | `""` |
| `property_test` | Path to custom property-based test template | `""` |

### [hooks]

Git hook behavior:

| Option | Description | Default |
|--------|-------------|---------|
| `pre_commit` | Enable pre-commit hook | `true` |
| `enforce_coverage` | Enforce coverage threshold in hooks | `true` |
| `run_tests` | Run tests in pre-commit hook | `true` |

## Example Configurations

### Basic Project

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

### Monorepo Project

```toml
[directories]
source = "packages/mylib/src"
tests = "packages/mylib/tests"

[patterns]
include = "*.nim"
exclude = "internal/*"
test_name = "${module}_test.nim"

[options]
coverage_threshold = 90
parallel_tests = true
```

### Legacy Project

```toml
[directories]
source = "lib"
tests = "test"

[patterns]
include = "*.nim"
test_name = "${module}_test.nim"

[options]
coverage_threshold = 60
parallel_tests = false
```

## Environment Variables

Nim TestKit also respects the following environment variables:

- `NIMTESTKIT_CONFIG`: Path to the configuration file
- `NIMTESTKIT_SOURCE_DIR`: Override source directory
- `NIMTESTKIT_TESTS_DIR`: Override tests directory
- `NIMTESTKIT_COVERAGE_THRESHOLD`: Override coverage threshold

Environment variables take precedence over configuration file settings.