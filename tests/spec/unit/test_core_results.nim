# Test suite for core/results.nim - 100% coverage target

import std/[unittest, times, strutils]
import ../../../src/core/[types, results]

suite "Core Results Tests":
  
  test "initResultCollector creates proper collector":
    let collector = initResultCollector()
    check collector.results.len == 0
    check collector.currentSuite == ""
    check collector.verbose == false
    
    let verboseCollector = initResultCollector(true)
    check verboseCollector.verbose == true

  test "setCurrentSuite updates suite name":
    var collector = initResultCollector()
    collector.setCurrentSuite("test_suite")
    check collector.currentSuite == "test_suite"

  test "startTest creates running test result":
    var collector = initResultCollector()
    let result = collector.startTest("test_name", tcIntegration)
    check result.name == "test_name"
    check result.category == tcIntegration
    check result.status == tsRunning
    check result.startTime > 0.0

  test "startTest with default category":
    var collector = initResultCollector()
    let result = collector.startTest("test_name")
    check result.category == tcUnit

  test "endTest adds result and sets timing":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    sleep(10) # Small delay to ensure duration > 0
    collector.endTest(result)
    
    check collector.results.len == 1
    check result.endTime > result.startTime
    check result.duration > 0.0

  test "passTest marks result as passed":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.passTest(result, "Success message")
    
    check result.status == tsPassed
    check result.message == "Success message"
    check collector.results.len == 1

  test "passTest with empty message":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.passTest(result)
    
    check result.status == tsPassed
    check result.message == ""

  test "failTest marks result as failed":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.failTest(result, "Failure message", "Stack trace")
    
    check result.status == tsFailed
    check result.message == "Failure message"
    check result.stackTrace == "Stack trace"
    check collector.results.len == 1

  test "failTest with empty stack trace":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.failTest(result, "Failure message")
    
    check result.status == tsFailed
    check result.stackTrace == ""

  test "errorTest marks result as error":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.errorTest(result, "Error message", "Error stack trace")
    
    check result.status == tsError
    check result.message == "Error message"
    check result.stackTrace == "Error stack trace"
    check collector.results.len == 1

  test "errorTest with empty stack trace":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.errorTest(result, "Error message")
    
    check result.status == tsError
    check result.stackTrace == ""

  test "skipTest marks result as skipped":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.skipTest(result, "Skip reason")
    
    check result.status == tsSkipped
    check result.message == "Skipped: Skip reason"
    check collector.results.len == 1

  test "skipTest with empty reason":
    var collector = initResultCollector()
    var result = collector.startTest("test_name")
    collector.skipTest(result)
    
    check result.status == tsSkipped
    check result.message == "Skipped"

  test "generateReport creates proper report":
    var collector = initResultCollector()
    
    # Add various test results
    var passedResult = collector.startTest("passed_test")
    collector.passTest(passedResult)
    
    var failedResult = collector.startTest("failed_test")
    collector.failTest(failedResult, "Failed")
    
    var errorResult = collector.startTest("error_test")
    collector.errorTest(errorResult, "Error")
    
    var skippedResult = collector.startTest("skipped_test")
    collector.skipTest(skippedResult)
    
    let report = collector.generateReport()
    
    check report.results.len == 4
    check report.totalTests == 4
    check report.passed == 1
    check report.failed == 1
    check report.errors == 1
    check report.skipped == 1
    check report.startTime > 0.0
    check report.endTime >= report.startTime
    check report.duration >= 0.0

  test "formatDuration formats correctly":
    check formatDuration(0.0005) == "500μs"
    check formatDuration(0.5).startsWith("500.0ms")
    check formatDuration(1.5).startsWith("1.50s")

  test "printSummary displays report summary":
    var collector = initResultCollector()
    var passedResult = collector.startTest("passed_test")
    collector.passTest(passedResult)
    
    var failedResult = collector.startTest("failed_test")
    failedResult.file = "test.nim"
    failedResult.line = 42
    collector.failTest(failedResult, "Test failed")
    
    let report = collector.generateReport()
    
    # This will print to stdout, we just verify it doesn't crash
    report.printSummary()
    check true # If we get here, printSummary worked

  test "toJson creates valid JSON structure":
    var collector = initResultCollector()
    var result = collector.startTest("test")
    result.file = "test.nim"
    result.line = 10
    collector.passTest(result, "Success")
    
    let report = collector.generateReport()
    let json = report.toJson()
    
    check "totalTests" in json
    check "passed" in json
    check "failed" in json
    check "errors" in json
    check "skipped" in json
    check "duration" in json
    check "results" in json
    check "test" in json
    check "Success" in json

  test "toTap creates valid TAP format":
    var collector = initResultCollector()
    
    var passedResult = collector.startTest("passed_test")
    collector.passTest(passedResult)
    
    var failedResult = collector.startTest("failed_test")
    failedResult.file = "test.nim"
    failedResult.line = 42
    collector.failTest(failedResult, "Failed message")
    
    var skippedResult = collector.startTest("skipped_test")
    collector.skipTest(skippedResult, "Skip reason")
    
    let report = collector.generateReport()
    let tap = report.toTap()
    
    check tap.startsWith("TAP version 13")
    check "1..3" in tap
    check "ok 1 - passed_test" in tap
    check "not ok 2 - failed_test" in tap
    check "ok 3 - skipped_test # SKIP" in tap
    check "Failed message" in tap

  test "saveReport saves JSON format":
    var collector = initResultCollector()
    var result = collector.startTest("test")
    collector.passTest(result)
    
    let report = collector.generateReport()
    let filename = "test_report.json"
    
    report.saveReport(filename, ofJson)
    
    # Verify file was created and contains JSON
    let content = readFile(filename)
    check "totalTests" in content
    check "passed" in content
    
    # Cleanup
    removeFile(filename)

  test "saveReport saves TAP format":
    var collector = initResultCollector()
    var result = collector.startTest("test")
    collector.passTest(result)
    
    let report = collector.generateReport()
    let filename = "test_report.tap"
    
    report.saveReport(filename, ofTap)
    
    # Verify file was created and contains TAP
    let content = readFile(filename)
    check content.startsWith("TAP version 13")
    
    # Cleanup
    removeFile(filename)

  test "saveReport with unsupported format does nothing":
    var collector = initResultCollector()
    var result = collector.startTest("test")
    collector.passTest(result)
    
    let report = collector.generateReport()
    let filename = "test_report.xml"
    
    # This should not create a file since XML is not implemented
    report.saveReport(filename, ofXml)
    check not fileExists(filename)

  test "verbose collector prints test results":
    # Test with verbose output (will print to stdout)
    var collector = initResultCollector(true)
    var result = collector.startTest("verbose_test")
    result.message = "Test message"
    result.stackTrace = "line1\nline2\n"
    collector.passTest(result)
    
    # If we get here without crashing, verbose output worked
    check true

  test "addResult directly adds result":
    var collector = initResultCollector()
    var result = initTestResult("direct_test")
    result.status = tsPassed
    
    collector.addResult(result)
    check collector.results.len == 1
    check collector.results[0].name == "direct_test"