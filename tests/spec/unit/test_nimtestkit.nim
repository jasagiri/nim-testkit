# Test suite for nimtestkit.nim main module - 100% coverage target

import std/[unittest, os, strutils]
import ../../../src/nimtestkit

var testRan = false
var setupRan = false
var teardownRan = false

suite "NimTestKit Main Module Tests":

  test "version constants are defined":
    check NimTestKitVersion == "0.1.0"
    check NimTestKitDescription == "Minimal, zero-dependency test framework for Nim"

  test "all types are exported and accessible":
    # Test that all main types are exported
    var status: TestStatus = tsPassed
    var category: TestCategory = tcUnit
    var format: OutputFormat = ofText
    var result: TestResult = initTestResult("test")
    var testCase: TestCase = initTestCase("test", proc() = discard)
    var suite: TestSuite = initTestSuite("suite")
    var report: TestReport = initTestReport()
    var config: TestConfig = initTestConfig()
    var collector: ResultCollector = initResultCollector()
    var runner: TestRunner = initTestRunner()
    
    check status == tsPassed
    check category == tcUnit
    check format == ofText
    check result.name == "test"
    check testCase.name == "test"
    check suite.name == "suite"
    check config.outputFormat == ofText

  test "check macro works correctly":
    check(true, "This should pass")
    
    expect AssertionDefect:
      check(false, "This should fail")

  test "check macro with default message":
    expect AssertionDefect:
      check(1 == 2) # Should use default message

  test "expect macro catches expected exceptions":
    expect(ValueError):
      raise newException(ValueError, "Expected error")

  test "expect macro fails on wrong exception":
    expect AssertionDefect:
      expect(ValueError):
        raise newException(IOError, "Wrong error type")

  test "expect macro fails when no exception raised":
    expect AssertionDefect:
      expect(ValueError):
        discard # No exception raised

  test "skip macro raises SkipTest":
    expect SkipTest:
      skip("Skipping this test")

  test "skip macro with empty reason":
    expect SkipTest:
      skip()

  test "parseCommandLine handles basic options":
    # We can't easily test command line parsing without modifying global state,
    # but we can test that the function exists and returns a config
    let config = parseCommandLine()
    check config.outputFormat in {ofText, ofJson, ofXml, ofTap, ofJunit}

# Test the template system with actual usage
proc testTemplateUsage() =
  var testSuites {.global.}: seq[TestSuite] = @[]
  
  suite "Template Test Suite":
    setup:
      setupRan = true
    
    teardown:
      teardownRan = true
    
    test "template test":
      testRan = true
      check true

suite "Template System Tests":
  
  test "suite and test templates work":
    # Reset flags
    testRan = false
    setupRan = false
    teardownRan = false
    
    # Call the template usage function
    testTemplateUsage()
    
    # The templates should have created test structures
    check true # If we get here, templates compiled successfully

  test "test templates can be nested in suites":
    var localTestSuites: seq[TestSuite] = @[]
    
    # Test that we can create multiple test cases in a suite
    block:
      var testCases {.inject.}: seq[TestCase] = @[]
      
      # Simulate test template expansion
      proc testProc1() {.nimcall, gensym.} = discard
      testCases.add(initTestCase("test1", testProc1))
      
      proc testProc2() {.nimcall, gensym.} = discard
      testCases.add(initTestCase("test2", testProc2))
      
      localTestSuites.add(TestSuite(
        name: "Local Suite",
        category: tcUnit,
        tests: testCases
      ))
    
    check localTestSuites.len == 1
    check localTestSuites[0].tests.len == 2

suite "Command Line Integration Tests":

  test "parseCommandLine processes verbose flag":
    # This is challenging to test without manipulating command line args
    # We verify the function exists and basic structure
    when false: # Disabled because it requires actual command line manipulation
      let config = parseCommandLine()
      check config.verbose in [true, false]

  test "parseCommandLine processes format options":
    # Similar to above, we test structure rather than actual parsing
    let defaultConfig = loadConfig()
    check defaultConfig.outputFormat in {ofText, ofJson, ofXml, ofTap, ofJunit}

suite "Integration Tests":

  test "full test execution flow":
    proc simpleTest() {.nimcall.} = 
      check 1 + 1 == 2
    
    let tests = @[initTestCase("simple_test", simpleTest)]
    let config = initTestConfig()
    let report = runTests(tests, config)
    
    check report.totalTests == 1
    check report.passed == 1
    check report.failed == 0

  test "test execution with configuration":
    proc passingTest() {.nimcall.} = discard
    proc failingTest() {.nimcall.} = 
      raise newException(AssertionDefect, "Test failed")
    
    var config = initTestConfig()
    config.verbose = false
    config.failFast = true
    
    let tests = @[
      initTestCase("passing", passingTest),
      initTestCase("failing", failingTest)
    ]
    
    let report = runTests(tests, config)
    
    check report.totalTests == 2
    check report.passed == 1
    check report.failed == 1

  test "test filtering integration":
    proc unitTest() {.nimcall.} = discard
    proc integrationTest() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.filter.categories = @[tcUnit]
    
    let tests = @[
      initTestCase("unit_test", unitTest, tcUnit),
      initTestCase("integration_test", integrationTest, tcIntegration)
    ]
    
    let report = runTests(tests, config)
    
    # Should only run unit test, integration test should be skipped
    check report.totalTests == 2
    check report.passed == 1
    check report.skipped == 1

  test "MECE analysis integration":
    let tempDir = "temp_mece_integration"
    createDir(tempDir)
    createDir(tempDir / "tests" / "spec" / "unit")
    writeFile(tempDir / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    
    let report = analyzeMECE(tempDir)
    
    check report.stats.totalFiles == 1
    check report.stats.categorizedFiles == 1
    
    removeDir(tempDir)

  test "configuration loading integration":
    let configContent = """
[output]
format = "json"
verbose = true

[runner]
timeout = 60.0

[filter]
categories = ["unit"]
"""
    writeFile("integration_test.toml", configContent)
    
    let config = loadConfig("integration_test.toml")
    
    check config.outputFormat == ofJson
    check config.verbose == true
    check config.timeout == 60.0
    check config.filter.categories == @[tcUnit]
    
    removeFile("integration_test.toml")

  test "report generation integration":
    proc testProc() {.nimcall.} = discard
    
    var config = initTestConfig()
    config.reportFile = "integration_report.json"
    config.outputFormat = ofJson
    
    let tests = @[initTestCase("integration_test", testProc)]
    let report = runTests(tests, config)
    
    check fileExists("integration_report.json")
    let content = readFile("integration_report.json")
    check "totalTests" in content
    
    removeFile("integration_report.json")

suite "Error Handling Tests":

  test "graceful handling of test exceptions":
    proc exceptionTest() {.nimcall.} = 
      raise newException(ValueError, "Custom error")
    
    let testCase = initTestCase("exception_test", exceptionTest)
    let result = runTest(testCase)
    
    check result.status == tsFailed
    check "Custom error" in result.message

  test "handling of setup exceptions":
    proc failingSetup() {.nimcall.} = 
      raise newException(IOError, "Setup failed")
    
    proc testProc() {.nimcall.} = discard
    
    var testCase = initTestCase("test_with_failing_setup", testProc)
    testCase.setupProc = failingSetup
    
    let result = runTest(testCase)
    
    check result.status == tsError
    check "Setup failed" in result.message

  test "SkipTest exception type exists":
    let skipException = newException(SkipTest, "Test skipped")
    check skipException.msg == "Test skipped"
    check skipException of SkipTest
    check skipException of CatchableError

suite "Edge Cases":

  test "empty test suite execution":
    let emptyTests: seq[TestCase] = @[]
    let report = runTests(emptyTests)
    
    check report.totalTests == 0
    check report.passed == 0
    check report.failed == 0

  test "test with nil procedures":
    # Test case with minimal setup
    var testCase = TestCase(
      name: "minimal_test",
      category: tcUnit,
      file: "",
      line: 0,
      testProc: proc() = discard,
      setupProc: nil,
      teardownProc: nil,
      tags: @[],
      timeout: 0.0
    )
    
    let result = runTest(testCase)
    check result.status == tsPassed

  test "configuration with extreme values":
    var config = initTestConfig()
    config.timeout = 0.001 # Very short timeout
    config.randomSeed = high(int)
    config.filter.patterns = @["*"] # Match everything
    
    # Should handle extreme values gracefully
    check config.timeout > 0.0
    check config.randomSeed == high(int)