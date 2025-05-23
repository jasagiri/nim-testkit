# Advanced Testing Features

Nim TestKit provides comprehensive advanced testing capabilities that go beyond traditional unit testing to ensure robust, reliable, and high-quality code.

## Overview

The advanced testing features include:

1. **Mutation Testing** - Validates test suite effectiveness by introducing code mutations
2. **Fuzz Testing** - Discovers edge cases and security vulnerabilities through random input generation
3. **Benchmark Testing** - Measures and monitors performance characteristics
4. **Contract Testing** - Enforces preconditions, postconditions, and invariants
5. **Integration Testing** - Tests component interactions and system workflows

## Quick Start

### Enable Advanced Testing

Add advanced testing configuration to your `nimtestkit.toml`:

```toml
[advanced]
enabled = true
test_types = ["unit", "integration", "benchmark", "fuzz", "mutation", "contract"]
```

### Generate Advanced Tests

```bash
nimble advanced_generate
```

### Run Specific Test Types

```bash
# Mutation testing
nimble mutation

# Fuzz testing  
nimble fuzz

# Benchmark testing
nimble benchmark

# Contract testing
nimble contract

# Integration testing
nimble integration
```

## Mutation Testing

Mutation testing validates the effectiveness of your test suite by introducing small changes (mutations) to your code and checking if your tests detect these changes.

### Configuration

```toml
[advanced.mutation]
operators = ["arithmetic", "logical", "relational", "assignment"]
iterations = 100
survivor_threshold = 0.1
output_dir = "build/mutation"
```

### Supported Mutation Operators

- **Arithmetic**: `+` ↔ `-`, `*` ↔ `/`
- **Logical**: `and` ↔ `or`, `not` removal
- **Relational**: `==` ↔ `!=`, `<` ↔ `>=`
- **Assignment**: Variable substitution
- **Boolean**: `true` ↔ `false`

### Example Generated Test

```nim
import unittest, times, json
import original_module

type
  MutationResult = object
    operator: string
    position: int
    survived: bool
    executionTime: float

suite "Mutation Tests for calculateSum":
  test "calculateSum mutation testing":
    var results: seq[MutationResult]
    
    # Test arithmetic mutations
    # Original: a + b
    # Mutated:  a - b
    let result = runMutationTest("plus_to_minus") do:
      check calculateSum(5, 3) == 8  # Should fail with mutation
    
    results.add(result)
    
    # Calculate mutation score
    let mutationScore = 1.0 - (survivors.len.float / results.len.float)
    check mutationScore >= 0.8  # 80% of mutants should be killed
```

### Running Mutation Tests

```bash
# Cross-platform
nimble mutation

# Windows (PowerShell)
scripts/advanced/mutation.ps1 --iterations 200 --threshold 0.9

# Unix/Linux/macOS
scripts/advanced/mutation.sh --iterations 200 --threshold 0.9
```

## Fuzz Testing

Fuzz testing discovers edge cases, security vulnerabilities, and robustness issues by feeding random or semi-random inputs to your functions.

### Configuration

```toml
[advanced.fuzz]
iterations = 1000
timeout = 30
input_types = ["int", "string", "seq", "object"]
output_dir = "build/fuzz"
```

### Input Generation

The fuzzer automatically generates:

- **Random strings** with various lengths and character sets
- **Integer values** including edge cases (min/max values)
- **Floating-point numbers** including special values (NaN, infinity)
- **Collections** with random sizes and contents
- **Edge cases** like empty inputs, null characters, very long strings

### Example Generated Test

```nim
import unittest, random, times
import original_module

type
  FuzzTestResult = object
    iteration: int
    input: string
    success: bool
    crashed: bool

suite "Fuzz Tests for parseInput":
  test "parseInput fuzz testing":
    var results: seq[FuzzTestResult]
    
    for i in 0..<1000:
      let randomInput = generateRandomString(200)
      
      try:
        discard parseInput(randomInput)
        results.add(FuzzTestResult(success: true))
      except Exception:
        # Expected for invalid inputs
        results.add(FuzzTestResult(success: false))
    
    # No crashes should occur
    let crashes = results.filterIt(it.crashed)
    check crashes.len == 0
```

### Running Fuzz Tests

```bash
# Cross-platform
nimble fuzz

# With custom parameters
scripts/advanced/fuzz.sh --iterations 5000 --timeout 60
```

## Benchmark Testing

Benchmark testing measures performance characteristics and detects performance regressions.

### Configuration

```toml
[advanced.benchmark]
iterations = 1000
warmup_runs = 10
time_limit = 5.0
memory_limit = 100000000
```

### Metrics Collected

- **Execution time** (average, min, max, standard deviation)
- **Memory usage** (peak memory, allocations)
- **Throughput** (operations per second)
- **Scalability** (performance vs. input size)

### Example Generated Test

```nim
import unittest, times, stats
import original_module

suite "Benchmark Tests for sortArray":
  test "sortArray performance benchmark":
    let result = benchmark("sortArray", 1000) do:
      let data = generateRandomArray(1000)
      discard sortArray(data)
    
    echo fmt"Average time: {result.avgTime * 1000:.3f}ms"
    echo fmt"Throughput: {1.0 / result.avgTime:.0f} ops/sec"
    
    # Performance assertions
    check result.avgTime < 0.001  # Under 1ms
    check result.memoryUsed < 10_000_000  # Under 10MB
```

### Performance Regression Detection

```nim
test "sortArray regression testing":
  let currentResult = benchmark("sortArray", 500) do:
    discard sortArray(testData)
  
  const baselineTime = 0.0005  # 0.5ms baseline
  let regression = checkPerformanceRegression(currentResult, baselineTime, 0.2)
  
  check not regression.regressed, "Performance should not regress significantly"
```

## Contract Testing

Contract testing enforces design-by-contract principles through preconditions, postconditions, and invariants.

### Configuration

```toml
[advanced.contract]
preconditions = true
postconditions = true
invariants = true
output_dir = "build/contracts"
```

### Contract Macros

```nim
template requires*(condition: bool, message: string = ""): untyped =
  ## Precondition check
  if not condition:
    raise newException(PreconditionError, message)

template ensures*(condition: bool, message: string = ""): untyped =
  ## Postcondition check
  if not condition:
    raise newException(PostconditionError, message)

template invariant*(condition: bool, message: string = ""): untyped =
  ## Invariant check
  if not condition:
    raise newException(InvariantError, message)
```

### Example Generated Test

```nim
import unittest
import original_module

suite "Contract Tests for divide":
  test "divide precondition validation":
    # Test that division by zero is rejected
    expect(PreconditionError):
      requires(denominator != 0, "Division by zero not allowed")
      discard divide(10, 0)
  
  test "divide postcondition validation":
    let result = divide(10, 2)
    ensures(result == 5, "Division result should be correct")
    ensures(result.isFinite(), "Result should be finite")
  
  test "divide invariant preservation":
    let stateBefore = getSystemState()
    discard divide(10, 2)
    let stateAfter = getSystemState()
    
    invariant(stateAfter.isConsistent(), "System state should remain consistent")
```

## Integration Testing

Integration testing validates component interactions and end-to-end workflows.

### Features

- **Database integration** testing
- **HTTP API** interaction testing
- **File system** operation testing
- **Async workflow** testing
- **Service dependency** testing

### Example Generated Test

```nim
import unittest, asyncdispatch, httpclient
import original_module

suite "Integration Tests for UserService":
  setup:
    # Initialize test environment
    let db = setupTestDatabase()
    let httpClient = newHttpClient()
  
  teardown:
    # Cleanup resources
    db.close()
    httpClient.close()
  
  test "UserService end-to-end workflow":
    # Create user via API
    let createResponse = httpClient.post("/api/users", userJson)
    check createResponse.status == Http201
    
    # Verify user in database
    let userId = parseJson(createResponse.body)["id"].getInt()
    let dbUser = db.getUserById(userId)
    check dbUser.name == "Test User"
    
    # Update user
    let updateResponse = httpClient.put(fmt"/api/users/{userId}", updateJson)
    check updateResponse.status == Http200
```

## Platform-Specific Testing

### Windows Testing

```nim
# Windows-specific features
when defined(windows):
  test "Windows registry integration":
    let regValue = readRegistryValue("HKEY_CURRENT_USER\\Software", "TestKey")
    check regValue.isValid()
  
  test "Windows service interaction":
    let serviceStatus = getServiceStatus("EventLog")
    check serviceStatus.isRunning
```

### macOS Testing

```nim
# macOS-specific features
when defined(macosx):
  test "macOS bundle validation":
    let bundle = createTestBundle("/tmp/Test.app")
    check bundle.hasValidPlist()
    check bundle.hasExecutable()
  
  test "macOS Spotlight integration":
    let searchResults = searchSpotlight("kMDItemKind == 'Application'")
    check searchResults.len > 0
```

### Mobile Testing

```nim
# Mobile platform testing
when defined(ios) or defined(android):
  test "mobile memory constraints":
    let memoryUsage = performMobileOperation()
    check memoryUsage < getDeviceMemoryLimit() / 4  # Use less than 25% of device memory
  
  test "mobile touch input handling":
    let touchResult = simulateTouchInput(100, 200, pressure = 0.8)
    check touchResult.recognized
```

### WebAssembly Testing

```nim
# WebAssembly-specific testing
when defined(js):
  test "WebAssembly DOM integration":
    let element = document.createElement("div")
    let result = processElement(element)
    check result.success
  
  test "WebAssembly performance":
    let wasmTime = benchmarkWasmOperation()
    let jsTime = benchmarkJavaScriptOperation()
    check wasmTime <= jsTime * 1.2  # WASM should be competitive with JS
```

## Best Practices

### Mutation Testing

1. **Achieve high mutation scores** (>80%) to ensure test quality
2. **Focus on critical paths** where mutations would cause real issues
3. **Review surviving mutants** to identify missing test cases
4. **Use equivalent mutants** detection to avoid false positives

### Fuzz Testing

1. **Include edge cases** in your fuzz input generation
2. **Monitor resource usage** to prevent system overload
3. **Save crash-inducing inputs** for debugging
4. **Use property-based assertions** rather than specific value checks

### Benchmark Testing

1. **Establish baselines** for performance regression detection
2. **Run multiple iterations** to account for variance
3. **Test with realistic data sizes** and usage patterns
4. **Monitor both time and memory** consumption

### Contract Testing

1. **Define clear contracts** with meaningful error messages
2. **Test contract violations** explicitly
3. **Keep contracts simple** and easy to understand
4. **Use contracts for documentation** as well as validation

### Integration Testing

1. **Use test doubles** for external dependencies when appropriate
2. **Test error scenarios** and edge cases
3. **Ensure proper cleanup** of test resources
4. **Verify end-to-end workflows** represent real usage

## Reporting

### Mutation Testing Report

```
Mutation Testing Results:
  Total Mutants: 500
  Killed: 425
  Survived: 75
  Mutation Score: 85.0%
  
Surviving Mutants:
  - arithmetic_plus_to_minus: line 42 in calculator.nim
  - logical_and_to_or: line 156 in validator.nim
```

### Fuzz Testing Report

```
Fuzz Testing Results:
  Total Tests: 10,000
  Successful: 9,847 (98.5%)
  Exceptions: 153 (1.5%)
  Timeouts: 0 (0.0%)
  Crashes: 0 (0.0%)
  
Edge Case Results:
  - Empty string: PASS
  - Very long string: PASS  
  - Unicode characters: PASS
  - Control characters: EXCEPTION (expected)
```

### Benchmark Report

```
Benchmark Results for sortArray:
  Iterations: 1,000
  Average Time: 0.245ms
  Median Time: 0.230ms
  95th Percentile: 0.380ms
  Memory Used: 2.1MB
  Throughput: 4,082 ops/sec
  
Performance: PASS (within acceptable limits)
```

## Continuous Integration

### GitHub Actions

```yaml
name: Advanced Testing
on: [push, pull_request]

jobs:
  advanced-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Nim
        uses: iffy/install-nim@v4
      
      - name: Run mutation tests
        run: nimble mutation
      
      - name: Run fuzz tests
        run: nimble fuzz
      
      - name: Run benchmark tests
        run: nimble benchmark
      
      - name: Upload reports
        uses: actions/upload-artifact@v3
        with:
          name: advanced-test-reports
          path: build/
```

### Quality Gates

Set up quality gates to ensure code quality:

```yaml
- name: Check mutation score
  run: |
    SCORE=$(grep "Mutation Score" build/mutation/report.txt | cut -d: -f2 | tr -d ' %')
    if [ "$SCORE" -lt "80" ]; then
      echo "Mutation score too low: $SCORE%"
      exit 1
    fi

- name: Check for crashes
  run: |
    if grep -q "CRASH DETECTED" build/fuzz/crashes.txt; then
      echo "Crashes detected in fuzz testing"
      exit 1
    fi
```

## Troubleshooting

### Common Issues

**Mutation tests not detecting changes**
- Review test assertions for specificity
- Ensure tests cover all code paths
- Check for equivalent mutants

**Fuzz tests causing system issues**
- Reduce iteration count or timeout values
- Add resource limits to prevent overload
- Use sandboxing for unsafe operations

**Benchmark tests showing high variance**
- Increase warmup runs
- Run tests on dedicated hardware
- Account for system load in CI environments

**Contract violations in production**
- Use contracts for development/testing only
- Provide meaningful error messages
- Consider graceful degradation strategies