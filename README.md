# Nim TestKit

A minimal, zero-dependency test framework for Nim with MECE (Mutually Exclusive, Collectively Exhaustive) test organization support.

## Features

- **Zero Dependencies**: Uses only Nim standard library
- **MECE Test Organization**: Enforces clean test structure
- **Multiple Output Formats**: Text, JSON, TAP, JUnit, XML
- **Configuration Support**: TOML config files and environment variables
- **Test Filtering**: By category, tags, or patterns
- **Minimal Footprint**: Optimized for size and performance

## Installation

Add to your `.nimble` file:

```nim
requires "nimtestkit >= 0.1.0"
```

Or install directly:

```bash
nimble install nimtestkit
```

## Quick Start

```nim
import nimtestkit

suite "My Test Suite":
  test "basic test":
    check 1 + 1 == 2
  
  test "test with setup":
    var x: int
    
    setup:
      x = 42
    
    teardown:
      x = 0
    
    check x == 42

nimTestMain()
```

## MECE Test Organization

Nim TestKit encourages organizing tests into mutually exclusive categories:

```
tests/
├── spec/
│   ├── unit/          # Unit tests
│   ├── integration/   # Integration tests
│   └── system/        # System/E2E tests
└── support/
    ├── fixtures/      # Test data
    ├── helpers/       # Test utilities
    └── mocks/         # Mock objects
```

Analyze your test structure:

```bash
nim c -r src/nimtestkit.nim --analyze-mece
```

Generate MECE structure:

```bash
nim c -r src/nimtestkit.nim --generate-mece
```

## Configuration

Create `nimtestkit.toml`:

```toml
[output]
format = "text"
verbose = true

[runner]
parallel = false
failFast = true
timeout = 300.0

[filter]
categories = ["unit", "integration"]
tags = ["fast"]
```

Or use environment variables:

```bash
NIMTESTKIT_VERBOSE=true nim c -r tests/test_all.nim
NIMTESTKIT_CATEGORIES=unit,integration nim c -r tests/test_all.nim
```

## Command Line Options

- `-v, --verbose`: Enable verbose output
- `-f, --format <format>`: Output format (text, json, tap, junit, xml)
- `-p, --parallel`: Run tests in parallel
- `--fail-fast`: Stop on first failure
- `-t, --timeout <seconds>`: Global timeout
- `-c, --category <name>`: Run specific category
- `--tag <tag>`: Run tests with tag
- `--pattern <pattern>`: Run tests matching pattern
- `-o, --output <file>`: Save report to file

## API Reference

### Test Definition

- `suite(name, body)`: Define a test suite
- `test(name, body)`: Define a test case
- `setup(body)`: Setup before each test
- `teardown(body)`: Cleanup after each test

### Assertions

- `check(condition, message)`: Assert condition is true
- `expect(ExceptionType, body)`: Expect exception
- `skip(reason)`: Skip current test

### Test Running

- `runTests(tests, config)`: Run specific tests
- `runTestsMain()`: Main entry point
- `nimTestMain()`: Convenience macro

## License

MIT License