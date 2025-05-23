# Testing Guide

Comprehensive guide to testing with Nim TestKit, covering test generation, execution, and best practices.

## Overview

Nim TestKit provides a complete testing workflow from automatic test generation to continuous monitoring. This guide covers all aspects of testing with the toolkit.

## Quick Start

### 1. Generate Tests
```bash
nimble generate
```
Analyzes your codebase and creates test skeletons for functions without tests.

### 2. Run Tests
```bash
nimble run
```
Executes all tests and displays results with coverage information.

### 3. Continuous Testing
```bash
nimble guard
```
Monitors files for changes and automatically runs tests when code is modified.

## Test Generation

### Automatic Test Discovery

The test generator analyzes your source code to identify:
- Public functions without corresponding tests
- New functions added since last generation
- Functions with incomplete test coverage

```nim
# Example: Function in src/calculator.nim
proc add*(a, b: int): int =
  result = a + b

# Generated test in tests/calculator_test.nim
import unittest
import calculator

suite "Calculator Tests":
  test "add should sum two integers":
    check add(2, 3) == 5
    check add(-1, 1) == 0
    check add(0, 0) == 0
```

### Generation Options

Configure test generation behavior in `nimtestkit.toml`:

```toml
[generation]
# Include patterns for source files
include = ["*.nim"]

# Exclude patterns (tests, examples, etc.)
exclude = ["*_test.nim", "test_*.nim", "examples/*"]

# Template for test file names
test_name = "${module}_test.nim"

# Generate async test variants
async_support = true

# Include property-based test templates
property_based = true

# Generate benchmark tests
benchmarks = false
```

### Custom Templates

Override default test templates by creating template files:

```nim
# templates/custom_test.nim
import unittest, times
import "$MODULE"

suite "$MODULE_NAME Tests":
  setup:
    echo "Setting up test for $MODULE_NAME"
  
  teardown:
    echo "Cleaning up after $MODULE_NAME tests"
  
  test "$FUNCTION_NAME basic functionality":
    # TODO: Implement test for $FUNCTION_NAME
    skip("Test not implemented yet")
```

### Advanced Generation

#### Async Function Support
```nim
# Source function
proc fetchData*(url: string): Future[string] {.async.} =
  # Implementation

# Generated async test
test "fetchData should retrieve data from URL":
  let result = waitFor fetchData("http://example.com")
  check result.len > 0
```

#### Result Type Handling
```nim
# Source function
proc parseNumber*(s: string): Result[int, string] =
  # Implementation

# Generated test with Result handling
test "parseNumber should handle valid input":
  let result = parseNumber("42")
  check result.isOk()
  check result.get() == 42

test "parseNumber should handle invalid input":
  let result = parseNumber("not-a-number")
  check result.isErr()
```

## Test Execution

### Basic Execution
```bash
# Run all tests
nimble run

# Run specific test file
nimble run tests/specific_test.nim

# Run tests matching pattern
nimble run --filter "Calculator*"
```

### Output Formats

#### Default Format
```
Running tests in tests/calculator_test.nim
✓ Calculator Tests / add should sum two integers
✓ Calculator Tests / multiply should handle zero
✗ Calculator Tests / divide should handle division by zero
  Expected ZeroDivisionError but got 42

Test Results:
- Passed: 2
- Failed: 1
- Skipped: 0
- Total: 3

Coverage: 85.7% (6/7 lines)
```

#### JUnit XML Output
```bash
nimble run --format junit --output results.xml
```

#### TAP Format
```bash
nimble run --format tap
```

#### JSON Format
```bash
nimble run --format json | jq '.results'
```

### Parallel Execution

Enable parallel test execution for faster results:

```toml
[tests]
parallel = true
max_workers = 4
```

```bash
# Override parallel settings
nimble run --parallel --workers 8
```

### Test Filtering

#### By Test Name
```bash
nimble run --filter "add*"
nimble run --filter "*integration*"
```

#### By Tag
```nim
# Tag tests in source
test "slow database operation":
  tags = ["slow", "database"]
  # Test implementation
```

```bash
nimble run --tags database
nimble run --exclude-tags slow
```

#### By Category
```bash
nimble run --category unit
nimble run --category integration
nimble run --exclude-category benchmark
```

## Coverage Analysis

### Basic Coverage
```bash
nimble coverage
```

Generates coverage report in `build/coverage/`:
- `index.html` - Interactive HTML report
- `coverage.json` - Raw coverage data
- `lcov.info` - LCOV format for CI integration

### Coverage Configuration

```toml
[coverage]
# Minimum coverage threshold
threshold = 80.0

# Coverage output format
format = ["html", "json", "lcov"]

# Include/exclude patterns for coverage
include = ["src/**/*.nim"]
exclude = ["src/experimental/**"]

# Line coverage vs branch coverage
mode = "line"  # or "branch"
```

### Coverage Reports

#### HTML Report
Interactive report with:
- File-by-file coverage breakdown
- Line-by-line coverage highlighting
- Function coverage statistics
- Historical coverage trends

#### Console Output
```
Coverage Report:
╭─────────────────────┬──────────┬───────┬─────────╮
│ File                │ Coverage │ Lines │ Missing │
├─────────────────────┼──────────┼───────┼─────────┤
│ src/calculator.nim  │ 85.7%    │ 7     │ 1       │
│ src/parser.nim      │ 92.3%    │ 13    │ 1       │
│ src/utils.nim       │ 100.0%   │ 5     │ 0       │
├─────────────────────┼──────────┼───────┼─────────┤
│ Total               │ 89.2%    │ 25    │ 2       │
╰─────────────────────┴──────────┴───────┴─────────╯
```

### Coverage Integration

#### CI/CD Integration
```yaml
# GitHub Actions example
- name: Run tests with coverage
  run: nimble coverage --format lcov

- name: Upload coverage to Codecov
  uses: codecov/codecov-action@v3
  with:
    file: build/coverage/lcov.info
```

#### Coverage Badges
```bash
# Generate coverage badge
nimble docs --badges
```

## Continuous Testing

### Test Guard

Monitor files and automatically run tests on changes:

```bash
nimble guard
```

#### Guard Configuration

```toml
[guard]
# Files to monitor
watch = ["src/**/*.nim", "tests/**/*.nim"]

# Ignore patterns
ignore = ["*.tmp", ".git/**"]

# Commands to run on change
on_change = ["test"]

# Debounce delay (milliseconds)
debounce = 500

# Run full test suite vs affected tests only
mode = "affected"  # or "full"
```

#### Guard Output
```
🔍 Watching for file changes...
📁 Monitoring: src/, tests/
⚙️  Mode: affected tests only

[14:32:15] src/calculator.nim changed
[14:32:15] Running affected tests...
[14:32:16] ✓ tests/calculator_test.nim (3/3 passed)
[14:32:16] 🎉 All tests passed!

🔍 Watching for file changes...
```

### Smart Test Selection

Run only tests affected by code changes:

```bash
# Test selection based on git changes
nimble run --changed

# Test selection based on dependencies
nimble run --affected src/calculator.nim
```

## Best Practices

### Test Organization

#### Directory Structure
```
tests/
├── unit/                 # Unit tests
│   ├── calculator_test.nim
│   └── parser_test.nim
├── integration/          # Integration tests
│   ├── api_test.nim
│   └── database_test.nim
├── benchmark/           # Performance tests
│   └── sorting_bench.nim
└── fixtures/           # Test data
    ├── data.json
    └── sample.txt
```

#### Naming Conventions
```nim
# Good: Descriptive test names
test "parseNumber should return error for invalid input"
test "Calculator.add should handle integer overflow"
test "FileProcessor.readFile should handle missing files gracefully"

# Bad: Vague test names
test "test1"
test "parsing"
test "error case"
```

### Test Quality

#### Comprehensive Testing
```nim
suite "String Utilities":
  test "trim should remove whitespace":
    # Test normal case
    check trim("  hello  ") == "hello"
    
    # Test edge cases
    check trim("") == ""
    check trim("   ") == ""
    check trim("hello") == "hello"
    
    # Test special characters
    check trim("\n\t  hello  \t\n") == "hello"
```

#### Test Data Management
```nim
# Use fixtures for complex test data
const testData = staticRead("fixtures/sample.json")

test "JSON parser should handle complex objects":
  let data = parseJson(testData)
  check data["users"].len == 3
  check data["users"][0]["name"].getStr() == "Alice"
```

#### Async Testing
```nim
suite "Async Operations":
  test "HTTP client should handle timeouts":
    let future = fetchUrl("http://slow-server.example.com")
    
    expect(TimeoutError):
      discard waitFor future.withTimeout(1000)
```

### Performance Testing

#### Benchmark Tests
```nim
import times, stats

suite "Performance Tests":
  test "sorting algorithm benchmark":
    var samples: seq[float]
    
    for i in 0..<100:
      let data = generateRandomData(1000)
      let start = cpuTime()
      let sorted = quickSort(data)
      let elapsed = cpuTime() - start
      samples.add(elapsed * 1000)  # Convert to milliseconds
    
    let stats = samples.summary()
    echo &"Average: {stats.mean:.2f}ms"
    echo &"Median: {stats.median:.2f}ms"
    echo &"95th percentile: {stats.percentile(95):.2f}ms"
    
    # Performance assertion
    check stats.mean < 10.0  # Should complete in under 10ms on average
```

#### Memory Testing
```nim
test "memory usage should be bounded":
  let memBefore = getOccupiedMem()
  
  # Perform memory-intensive operation
  let result = processLargeDataSet(data)
  
  let memAfter = getOccupiedMem()
  let memUsed = memAfter - memBefore
  
  check memUsed < 100_000_000  # Should use less than 100MB
```

## Integration with CI/CD

### GitHub Actions
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Nim
        uses: iffy/install-nim@v4
        with:
          version: stable
      
      - name: Install dependencies
        run: nimble install -y
      
      - name: Generate tests
        run: nimble generate
      
      - name: Run tests
        run: nimble run --format junit --output test-results.xml
      
      - name: Generate coverage
        run: nimble coverage --format lcov
      
      - name: Upload test results
        uses: dorny/test-reporter@v1
        if: success() || failure()
        with:
          name: Test Results
          path: test-results.xml
          reporter: java-junit
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: build/coverage/lcov.info
```

### GitLab CI
```yaml
stages:
  - test
  - coverage

test:
  stage: test
  script:
    - nimble install -y
    - nimble generate
    - nimble run --format junit --output test-results.xml
  artifacts:
    reports:
      junit: test-results.xml
    paths:
      - test-results.xml

coverage:
  stage: coverage
  script:
    - nimble coverage --format lcov
  coverage: '/Total.*?(\d+(?:\.\d+)?)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: build/coverage/coverage.xml
```

## Troubleshooting

### Common Issues

#### Test Generation Fails
```bash
# Check source code syntax
nim check src/mymodule.nim

# Verify configuration
nimble generate --dry-run

# Enable debug output
nimble generate --verbose
```

#### Tests Don't Run
```bash
# Check test file syntax
nim check tests/mymodule_test.nim

# Verify test discovery
nimble run --list-tests

# Run individual test
nim c -r tests/mymodule_test.nim
```

#### Coverage Reports Empty
```bash
# Ensure coverage build flags
nim c --debugger:native --passC:"-fprofile-arcs -ftest-coverage" tests/test.nim

# Check coverage data files
ls -la *.gcda *.gcno

# Manual coverage generation
gcov *.gcda
```

### Debug Mode

Enable detailed debugging information:

```bash
# Debug test generation
NIMTESTKIT_DEBUG=true nimble generate

# Debug test execution
NIMTESTKIT_DEBUG=true nimble run

# Debug coverage analysis
NIMTESTKIT_DEBUG=true nimble coverage
```

### Performance Issues

#### Slow Test Generation
- Reduce source file scope with better include/exclude patterns
- Use incremental generation mode
- Enable parallel processing

#### Slow Test Execution
- Enable parallel test execution
- Use test filtering to run subset
- Optimize individual test performance

#### Large Coverage Reports
- Exclude unnecessary files from coverage
- Use summary reports instead of detailed line coverage
- Compress coverage artifacts in CI/CD