# Test suite for core/types.nim - 100% coverage target

import std/[unittest, times]
import ../../../src/core/types

suite "Core Types Tests":
  
  test "TestStatus enum values":
    check $tsUnknown == "unknown"
    check $tsPending == "pending"
    check $tsRunning == "running"
    check $tsPassed == "passed"
    check $tsFailed == "failed"
    check $tsSkipped == "skipped"
    check $tsError == "error"
  
  test "TestCategory enum values":
    check $tcUnit == "unit"
    check $tcIntegration == "integration"
    check $tcSystem == "system"
    check $tcPerformance == "performance"
    check $tcCustom == "custom"
  
  test "OutputFormat enum values":
    check $ofText == "text"
    check $ofJson == "json"
    check $ofXml == "xml"
    check $ofTap == "tap"
    check $ofJunit == "junit"

  test "initTestResult creates proper TestResult":
    let result = initTestResult("test_name", tcIntegration)
    check result.name == "test_name"
    check result.category == tcIntegration
    check result.status == tsPending
    check result.startTime == 0.0
    check result.endTime == 0.0
    check result.duration == 0.0
    check result.message == ""
    check result.stackTrace == ""
    check result.file == ""
    check result.line == 0
  
  test "initTestResult with default category":
    let result = initTestResult("test_name")
    check result.category == tcUnit

  test "initTestCase creates proper TestCase":
    proc dummyTest() {.nimcall.} = discard
    let testCase = initTestCase("test_name", dummyTest, tcSystem)
    check testCase.name == "test_name"
    check testCase.category == tcSystem
    check testCase.file == ""
    check testCase.line == 0
    check testCase.testProc != nil
    check testCase.setupProc == nil
    check testCase.teardownProc == nil
    check testCase.tags.len == 0
    check testCase.timeout == 0.0
  
  test "initTestCase with default category":
    proc dummyTest() {.nimcall.} = discard
    let testCase = initTestCase("test_name", dummyTest)
    check testCase.category == tcUnit

  test "initTestSuite creates proper TestSuite":
    let suite = initTestSuite("suite_name", tcPerformance)
    check suite.name == "suite_name"
    check suite.category == tcPerformance
    check suite.tests.len == 0
    check suite.setupSuite == nil
    check suite.teardownSuite == nil
    check suite.parallel == false
  
  test "initTestSuite with default category":
    let suite = initTestSuite("suite_name")
    check suite.category == tcUnit

  test "initTestReport creates proper TestReport":
    let report = initTestReport()
    check report.suites.len == 0
    check report.results.len == 0
    check report.totalTests == 0
    check report.passed == 0
    check report.failed == 0
    check report.skipped == 0
    check report.errors == 0
    check report.startTime == 0.0
    check report.endTime == 0.0
    check report.duration == 0.0

  test "initTestConfig creates proper TestConfig":
    let config = initTestConfig()
    check config.outputFormat == ofText
    check config.verbose == false
    check config.parallel == false
    check config.failFast == false
    check config.filter.categories.len == 0
    check config.filter.tags.len == 0
    check config.filter.patterns.len == 0
    check config.filter.excludePatterns.len == 0
    check config.timeout == 300.0
    check config.reportFile == ""
    check config.randomSeed == 0

  test "TestCase category helpers":
    proc dummyTest() {.nimcall.} = discard
    let unitTest = initTestCase("unit", dummyTest, tcUnit)
    let integrationTest = initTestCase("integration", dummyTest, tcIntegration)
    let systemTest = initTestCase("system", dummyTest, tcSystem)
    
    check unitTest.isUnitTest()
    check not unitTest.isIntegrationTest()
    check not unitTest.isSystemTest()
    
    check not integrationTest.isUnitTest()
    check integrationTest.isIntegrationTest()
    check not integrationTest.isSystemTest()
    
    check not systemTest.isUnitTest()
    check not systemTest.isIntegrationTest()
    check systemTest.isSystemTest()

  test "TestResult status helpers":
    var result = initTestResult("test")
    
    result.status = tsPassed
    check result.isPassed()
    check not result.isFailed()
    check not result.isError()
    check not result.isSkipped()
    
    result.status = tsFailed
    check not result.isPassed()
    check result.isFailed()
    check not result.isError()
    check not result.isSkipped()
    
    result.status = tsError
    check not result.isPassed()
    check not result.isFailed()
    check result.isError()
    check not result.isSkipped()
    
    result.status = tsSkipped
    check not result.isPassed()
    check not result.isFailed()
    check not result.isError()
    check result.isSkipped()

  test "TestResult all fields can be modified":
    var result = initTestResult("test")
    result.name = "modified_name"
    result.category = tcIntegration
    result.status = tsPassed
    result.startTime = 1.0
    result.endTime = 2.0
    result.duration = 1.0
    result.message = "test message"
    result.stackTrace = "stack trace"
    result.file = "test.nim"
    result.line = 42
    
    check result.name == "modified_name"
    check result.category == tcIntegration
    check result.status == tsPassed
    check result.startTime == 1.0
    check result.endTime == 2.0
    check result.duration == 1.0
    check result.message == "test message"
    check result.stackTrace == "stack trace"
    check result.file == "test.nim"
    check result.line == 42

  test "TestCase all fields can be modified":
    proc dummyTest() {.nimcall.} = discard
    proc dummySetup() {.nimcall.} = discard
    proc dummyTeardown() {.nimcall.} = discard
    
    var testCase = initTestCase("test", dummyTest)
    testCase.name = "modified_test"
    testCase.category = tcSystem
    testCase.file = "test.nim"
    testCase.line = 10
    testCase.setupProc = dummySetup
    testCase.teardownProc = dummyTeardown
    testCase.tags = @["fast", "unit"]
    testCase.timeout = 30.0
    
    check testCase.name == "modified_test"
    check testCase.category == tcSystem
    check testCase.file == "test.nim"
    check testCase.line == 10
    check testCase.setupProc != nil
    check testCase.teardownProc != nil
    check testCase.tags == @["fast", "unit"]
    check testCase.timeout == 30.0

  test "TestSuite all fields can be modified":
    proc dummySetup() {.nimcall.} = discard
    proc dummyTeardown() {.nimcall.} = discard
    proc dummyTest() {.nimcall.} = discard
    
    var suite = initTestSuite("suite")
    suite.name = "modified_suite"
    suite.category = tcPerformance
    suite.tests = @[initTestCase("test1", dummyTest)]
    suite.setupSuite = dummySetup
    suite.teardownSuite = dummyTeardown
    suite.parallel = true
    
    check suite.name == "modified_suite"
    check suite.category == tcPerformance
    check suite.tests.len == 1
    check suite.setupSuite != nil
    check suite.teardownSuite != nil
    check suite.parallel == true

  test "TestFilter all fields can be modified":
    var filter = TestFilter()
    filter.categories = @[tcUnit, tcIntegration]
    filter.tags = @["fast", "slow"]
    filter.patterns = @["test_*", "*_test"]
    filter.excludePatterns = @["*_slow"]
    
    check filter.categories == @[tcUnit, tcIntegration]
    check filter.tags == @["fast", "slow"]
    check filter.patterns == @["test_*", "*_test"]
    check filter.excludePatterns == @["*_slow"]

  test "TestConfig all fields can be modified":
    var config = initTestConfig()
    config.outputFormat = ofJson
    config.verbose = true
    config.parallel = true
    config.failFast = true
    config.timeout = 60.0
    config.reportFile = "report.json"
    config.randomSeed = 12345
    config.filter.categories = @[tcUnit]
    
    check config.outputFormat == ofJson
    check config.verbose == true
    check config.parallel == true
    check config.failFast == true
    check config.timeout == 60.0
    check config.reportFile == "report.json"
    check config.randomSeed == 12345
    check config.filter.categories == @[tcUnit]