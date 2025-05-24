# Minimal test runner for nim-testkit
# Zero external dependencies - uses only Nim stdlib

import std/[times, os, strformat, strutils, algorithm]
import ./types, ./results

type
  TestRunner* = object
    config: TestConfig
    collector: ResultCollector
    suites: seq[TestSuite]

# Exception handling helpers
template catchExceptions*(body: untyped): tuple[success: bool, error: string] =
  var success = true
  var error = ""
  try:
    body
  except CatchableError as e:
    success = false
    error = e.msg & "\n" & e.getStackTrace()
  except Defect as d:
    success = false
    error = "Defect: " & d.msg & "\n" & d.getStackTrace()
  except Exception as e:
    success = false
    error = "Exception: " & e.msg & "\n" & e.getStackTrace()
  (success, error)

proc initTestRunner*(config: TestConfig = initTestConfig()): TestRunner =
  TestRunner(
    config: config,
    collector: initResultCollector(config.verbose),
    suites: @[]
  )

proc addSuite*(runner: var TestRunner, suite: TestSuite) =
  runner.suites.add(suite)

proc shouldRunTest(runner: TestRunner, test: TestCase): bool =
  let filter = runner.config.filter
  
  # Check categories
  if filter.categories.len > 0 and test.category notin filter.categories:
    return false
  
  # Check tags
  if filter.tags.len > 0:
    var hasTag = false
    for tag in filter.tags:
      if tag in test.tags:
        hasTag = true
        break
    if not hasTag:
      return false
  
  # Check patterns
  if filter.patterns.len > 0:
    var matches = false
    for pattern in filter.patterns:
      if pattern in test.name:
        matches = true
        break
    if not matches:
      return false
  
  # Check exclude patterns
  for pattern in filter.excludePatterns:
    if pattern in test.name:
      return false
  
  return true

proc runTest(runner: var TestRunner, test: TestCase): TestResult =
  if not runner.shouldRunTest(test):
    result = initTestResult(test.name, test.category)
    result.status = tsSkipped
    result.message = "Filtered out"
    return result
  
  result = runner.collector.startTest(test.name, test.category)
  result.file = test.file
  result.line = test.line
  
  # Run setup if provided
  if test.setupProc != nil:
    let (setupOk, setupError) = catchExceptions:
      test.setupProc()
    
    if not setupOk:
      runner.collector.errorTest(result, "Setup failed: " & setupError)
      return result
  
  # Run the test with timeout if specified
  let testStart = epochTime()
  let (testOk, testError) = catchExceptions:
    test.testProc()
  
  let testDuration = epochTime() - testStart
  
  # Check timeout
  if test.timeout > 0 and testDuration > test.timeout:
    runner.collector.failTest(result, 
      fmt"Test exceeded timeout of {test.timeout}s (took {testDuration:.2f}s)")
    return result
  
  # Handle test result
  if testOk:
    runner.collector.passTest(result)
  else:
    runner.collector.failTest(result, testError)
  
  # Run teardown if provided
  if test.teardownProc != nil:
    let (teardownOk, teardownError) = catchExceptions:
      test.teardownProc()
    
    if not teardownOk and result.status == tsPassed:
      # Only fail if test passed but teardown failed
      runner.collector.errorTest(result, "Teardown failed: " & teardownError)

proc runSuite(runner: var TestRunner, suite: TestSuite) =
  runner.collector.setCurrentSuite(suite.name)
  
  if runner.config.verbose:
    echo fmt"\nRunning suite: {suite.name} ({suite.category})"
    echo "-".repeat(40)
  
  # Run suite setup
  if suite.setupSuite != nil:
    let (setupOk, setupError) = catchExceptions:
      suite.setupSuite()
    
    if not setupOk:
      echo fmt"Suite setup failed: {setupError}"
      # Mark all tests as skipped
      for test in suite.tests:
        var result = initTestResult(test.name, test.category)
        result.status = tsSkipped
        result.message = "Suite setup failed"
        runner.collector.addResult(result)
      return
  
  # Run tests
  for test in suite.tests:
    let result = runner.runTest(test)
    
    # Fail fast if configured
    if runner.config.failFast and result.status in [tsFailed, tsError]:
      # Skip remaining tests
      for i in suite.tests.find(test) + 1 ..< suite.tests.len:
        var skipped = initTestResult(suite.tests[i].name, suite.tests[i].category)
        skipped.status = tsSkipped
        skipped.message = "Skipped due to fail-fast"
        runner.collector.addResult(skipped)
      break
  
  # Run suite teardown
  if suite.teardownSuite != nil:
    let (teardownOk, teardownError) = catchExceptions:
      suite.teardownSuite()
    
    if not teardownOk:
      echo fmt"Suite teardown failed: {teardownError}"

proc run*(runner: var TestRunner): TestReport =
  if runner.config.verbose:
    echo "Starting test run..."
    echo fmt"Running {runner.suites.len} test suites"
  
  # Sort suites by category for MECE compliance
  var sortedSuites = runner.suites
  sortedSuites.sort do (a, b: TestSuite) -> int:
    cmp(ord(a.category), ord(b.category))
  
  # Run suites
  for suite in sortedSuites:
    runner.runSuite(suite)
  
  # Generate report
  result = runner.collector.generateReport()
  
  # Save report if configured
  if runner.config.reportFile.len > 0:
    result.saveReport(runner.config.reportFile, runner.config.outputFormat)
  
  # Print summary
  if runner.config.outputFormat == ofText:
    result.printSummary()

# Convenience functions for simple test execution
proc runTests*(tests: seq[TestCase], config: TestConfig = initTestConfig()): TestReport =
  var runner = initTestRunner(config)
  var suite = initTestSuite("Default Suite")
  suite.tests = tests
  runner.addSuite(suite)
  result = runner.run()

proc runTest*(test: TestCase, config: TestConfig = initTestConfig()): TestResult =
  var runner = initTestRunner(config)
  result = runner.runTest(test)

# Test discovery helpers
proc discoverTests*(directory: string, pattern: string = "test*.nim"): seq[string] =
  result = @[]
  for file in walkFiles(directory / pattern):
    result.add(file)
  for dir in walkDirs(directory / "*"):
    result.add(discoverTests(dir, pattern))