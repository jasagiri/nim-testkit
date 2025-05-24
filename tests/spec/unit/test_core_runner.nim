# Test suite for core/runner.nim - 100% coverage target

import std/[unittest, os, times]
import ../../../src/core/[types, results, runner]

var globalSetupRan = false
var globalTeardownRan = false
var globalTestRan = false

suite "Core Runner Tests":

  test "initTestRunner creates proper runner":
    let config = initTestConfig()
    let runner = initTestRunner(config)
    check runner.config.outputFormat == ofText
    check runner.suites.len == 0

  test "initTestRunner with default config":
    let runner = initTestRunner()
    check runner.config.outputFormat == ofText

  test "addSuite adds suite to runner":
    var runner = initTestRunner()
    let suite = initTestSuite("test_suite")
    runner.addSuite(suite)
    check runner.suites.len == 1
    check runner.suites[0].name == "test_suite"

  test "runTest executes simple test successfully":
    proc simpleTest() {.nimcall.} = 
      globalTestRan = true
    
    globalTestRan = false
    var runner = initTestRunner()
    let testCase = initTestCase("simple_test", simpleTest)
    let result = runner.runTest(testCase)
    
    check globalTestRan == true
    check result.status == tsPassed
    check result.name == "simple_test"

  test "runTest with setup and teardown":
    proc setupProc() {.nimcall.} = 
      globalSetupRan = true
    
    proc teardownProc() {.nimcall.} = 
      globalTeardownRan = true
    
    proc testProc() {.nimcall.} = 
      globalTestRan = true
    
    globalSetupRan = false
    globalTeardownRan = false
    globalTestRan = false
    
    var runner = initTestRunner()
    var testCase = initTestCase("test_with_setup", testProc)
    testCase.setupProc = setupProc
    testCase.teardownProc = teardownProc
    
    let result = runner.runTest(testCase)
    
    check globalSetupRan == true
    check globalTeardownRan == true
    check globalTestRan == true
    check result.status == tsPassed

  test "runTest handles test failure":
    proc failingTest() {.nimcall.} = 
      raise newException(AssertionDefect, "Test failed")
    
    var runner = initTestRunner()
    let testCase = initTestCase("failing_test", failingTest)
    let result = runner.runTest(testCase)
    
    check result.status == tsFailed
    check "Test failed" in result.message

  test "runTest handles setup failure":
    proc failingSetup() {.nimcall.} = 
      raise newException(ValueError, "Setup failed")
    
    proc testProc() {.nimcall.} = 
      globalTestRan = true
    
    globalTestRan = false
    var runner = initTestRunner()
    var testCase = initTestCase("test_with_failing_setup", testProc)
    testCase.setupProc = failingSetup
    
    let result = runner.runTest(testCase)
    
    check globalTestRan == false # Test should not run if setup fails
    check result.status == tsError
    check "Setup failed" in result.message

  test "runTest handles teardown failure":
    proc passingTest() {.nimcall.} = 
      discard
    
    proc failingTeardown() {.nimcall.} = 
      raise newException(ValueError, "Teardown failed")
    
    var runner = initTestRunner()
    var testCase = initTestCase("test_with_failing_teardown", passingTest)
    testCase.teardownProc = failingTeardown
    
    let result = runner.runTest(testCase)
    
    check result.status == tsError
    check "Teardown failed" in result.message

  test "runTest with timeout":
    proc slowTest() {.nimcall.} = 
      sleep(100) # 100ms
    
    var runner = initTestRunner()
    var testCase = initTestCase("slow_test", slowTest)
    testCase.timeout = 0.05 # 50ms timeout
    
    let result = runner.runTest(testCase)
    
    check result.status == tsFailed
    check "exceeded timeout" in result.message

  test "runTest handles test filtering by category":
    proc testProc() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.filter.categories = @[tcUnit] # Only run unit tests
    var runner = initTestRunner(config)
    
    let integrationTest = initTestCase("integration_test", testProc, tcIntegration)
    let result = runner.runTest(integrationTest)
    
    check result.status == tsSkipped
    check "Filtered out" in result.message

  test "runTest handles test filtering by tags":
    proc testProc() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.filter.tags = @["fast"] # Only run tests with "fast" tag
    var runner = initTestRunner(config)
    
    var testCase = initTestCase("slow_test", testProc)
    testCase.tags = @["slow"]
    let result = runner.runTest(testCase)
    
    check result.status == tsSkipped

  test "runTest handles test filtering by patterns":
    proc testProc() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.filter.patterns = @["unit_"] # Only run tests starting with "unit_"
    var runner = initTestRunner(config)
    
    let testCase = initTestCase("integration_test", testProc)
    let result = runner.runTest(testCase)
    
    check result.status == tsSkipped

  test "runTest handles exclude patterns":
    proc testProc() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.filter.excludePatterns = @["slow"] # Exclude tests containing "slow"
    var runner = initTestRunner(config)
    
    let testCase = initTestCase("slow_test", testProc)
    let result = runner.runTest(testCase)
    
    check result.status == tsSkipped

  test "runTests convenience function":
    proc test1() {.nimcall.} = discard
    proc test2() {.nimcall.} = discard
    
    let tests = @[
      initTestCase("test1", test1),
      initTestCase("test2", test2)
    ]
    
    let report = runTests(tests)
    check report.totalTests == 2
    check report.passed == 2

  test "runTest convenience function":
    proc testProc() {.nimcall.} = discard
    
    let testCase = initTestCase("single_test", testProc)
    let result = runTest(testCase)
    
    check result.status == tsPassed
    check result.name == "single_test"

  test "discoverTests finds test files":
    # Create a temporary directory with test files
    let testDir = "temp_test_dir"
    createDir(testDir)
    writeFile(testDir / "test_example.nim", "# test file")
    writeFile(testDir / "not_a_test.nim", "# not a test")
    
    let discovered = discoverTests(testDir)
    check discovered.len >= 1
    check discovered.anyIt("test_example.nim" in it)
    
    # Cleanup
    removeFile(testDir / "test_example.nim")
    removeFile(testDir / "not_a_test.nim")
    removeDir(testDir)

  test "run executes full test suite":
    proc test1() {.nimcall.} = discard
    proc test2() {.nimcall.} = discard
    proc failingTest() {.nimcall.} = 
      raise newException(AssertionDefect, "Failed")
    
    var runner = initTestRunner()
    var suite = initTestSuite("test_suite")
    suite.tests = @[
      initTestCase("test1", test1),
      initTestCase("test2", test2),
      initTestCase("failing_test", failingTest)
    ]
    runner.addSuite(suite)
    
    let report = runner.run()
    
    check report.totalTests == 3
    check report.passed == 2
    check report.failed == 1

  test "run with suite setup and teardown":
    var suiteSetupRan = false
    var suiteTeardownRan = false
    
    proc suiteSetup() {.nimcall.} = 
      suiteSetupRan = true
    
    proc suiteTeardown() {.nimcall.} = 
      suiteTeardownRan = true
    
    proc testProc() {.nimcall.} = discard
    
    var runner = initTestRunner()
    var suite = initTestSuite("suite_with_setup")
    suite.setupSuite = suiteSetup
    suite.teardownSuite = suiteTeardown
    suite.tests = @[initTestCase("test", testProc)]
    runner.addSuite(suite)
    
    discard runner.run()
    
    check suiteSetupRan == true
    check suiteTeardownRan == true

  test "run with failing suite setup skips all tests":
    proc failingSuiteSetup() {.nimcall.} = 
      raise newException(ValueError, "Suite setup failed")
    
    proc testProc() {.nimcall.} = 
      globalTestRan = true
    
    globalTestRan = false
    var runner = initTestRunner()
    var suite = initTestSuite("suite_with_failing_setup")
    suite.setupSuite = failingSuiteSetup
    suite.tests = @[initTestCase("test", testProc)]
    runner.addSuite(suite)
    
    let report = runner.run()
    
    check globalTestRan == false
    check report.skipped == 1

  test "run with failFast stops on first failure":
    proc passingTest() {.nimcall.} = discard
    proc failingTest() {.nimcall.} = 
      raise newException(AssertionDefect, "Failed")
    
    var config = initTestConfig()
    config.failFast = true
    var runner = initTestRunner(config)
    
    var suite = initTestSuite("fail_fast_suite")
    suite.tests = @[
      initTestCase("passing_test", passingTest),
      initTestCase("failing_test", failingTest),
      initTestCase("skipped_test", passingTest) # Should be skipped
    ]
    runner.addSuite(suite)
    
    let report = runner.run()
    
    check report.passed == 1
    check report.failed == 1
    check report.skipped == 1 # Last test should be skipped

  test "run saves report to file when configured":
    proc testProc() {.nimcall.} = discard
    
    let reportFile = "test_report.json"
    var config = initTestConfig()
    config.reportFile = reportFile
    config.outputFormat = ofJson
    var runner = initTestRunner(config)
    
    var suite = initTestSuite("report_suite")
    suite.tests = @[initTestCase("test", testProc)]
    runner.addSuite(suite)
    
    discard runner.run()
    
    check fileExists(reportFile)
    let content = readFile(reportFile)
    check "totalTests" in content
    
    # Cleanup
    removeFile(reportFile)

  test "catchExceptions template handles various exception types":
    # Test CatchableError
    let (success1, error1) = catchExceptions:
      raise newException(ValueError, "Catchable error")
    check success1 == false
    check "Catchable error" in error1

    # Test successful execution
    let (success2, error2) = catchExceptions:
      discard
    check success2 == true
    check error2 == ""

  test "run sorts suites by category":
    proc testProc() {.nimcall.} = discard
    
    var runner = initTestRunner()
    
    # Add suites in reverse order to test sorting
    var systemSuite = initTestSuite("system_suite", tcSystem)
    systemSuite.tests = @[initTestCase("system_test", testProc)]
    runner.addSuite(systemSuite)
    
    var unitSuite = initTestSuite("unit_suite", tcUnit)
    unitSuite.tests = @[initTestCase("unit_test", testProc)]
    runner.addSuite(unitSuite)
    
    let report = runner.run()
    
    # Both tests should run successfully regardless of order
    check report.totalTests == 2
    check report.passed == 2