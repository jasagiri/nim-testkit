# Simple test to avoid name conflicts
import ../src/test_runner
import std/[os, strutils, xmltree]

# Direct testing without unittest to avoid name conflicts
proc testJUnitXML() =
  var suite = TestSuite(
    name: "Test Suite",
    totalDuration: 1.5
  )
  
  suite.results.add(TestResult(
    name: "test1",
    file: "test1.nim",
    passed: true,
    duration: 0.5,
    output: "Success"
  ))
  
  suite.results.add(TestResult(
    name: "test2",
    file: "test2.nim",
    passed: false,
    duration: 1.0,
    output: "Failed"
  ))
  
  let xml = generateJUnitXML(suite)
  assert xml.contains("testsuite")
  assert xml.contains("testcase")
  assert xml.contains("failure")
  echo "JUnit XML test: PASS"

proc testTAP() =
  var suite = TestSuite(
    name: "Test Suite",
    totalDuration: 1.0
  )
  
  suite.results.add(TestResult(
    name: "test1",
    file: "test1.nim", 
    passed: true,
    duration: 0.5,
    output: ""
  ))
  
  suite.results.add(TestResult(
    name: "test2",
    file: "test2.nim",
    passed: false,
    duration: 0.5,
    output: "Error message"
  ))
  
  let tap = generateTAP(suite)
  assert tap.contains("TAP version 13")
  assert tap.contains("1..2")
  assert tap.contains("ok 1")
  assert tap.contains("not ok 2")
  echo "TAP format test: PASS"

proc testFilter() =
  let testFiles = @[
    "tests/module1_test.nim",
    "tests/module2_test.nim",
    "tests/feature_test.nim"
  ]
  
  let filtered = filterTests(testFiles, "module")
  assert filtered.len == 2
  assert filtered[0].contains("module")
  assert filtered[1].contains("module")
  
  let filtered2 = filterTests(testFiles, "feature")
  assert filtered2.len == 1
  assert filtered2[0].contains("feature")
  echo "Filter test: PASS"

when isMainModule:
  echo "Running test runner enhancement tests..."
  testJUnitXML()
  testTAP()
  testFilter()
  echo "All tests passed!"