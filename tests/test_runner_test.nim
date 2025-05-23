# Simple test to avoid name conflicts
import ../src/test_runner
import std/[strutils, random]

# Direct testing without unittest to avoid name conflicts
proc testGenerateJUnitXML() =
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
  
  let xml = generateJUnitXML(suite)
  assert xml.contains("testsuite")
  assert xml.contains("testcase")
  echo "generateJUnitXML test: PASS"

proc testGenerateTAP() =
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
  
  let tap = generateTAP(suite)
  assert tap.contains("TAP version 13")
  assert tap.contains("1..1")
  assert tap.contains("ok 1")
  echo "generateTAP test: PASS"

proc testFilterTests() =
  let testFiles = @[
    "tests/test1.nim",
    "tests/test2.nim"
  ]
  
  let result = filterTests(testFiles, "test1")
  assert result.len == 1
  assert result[0] == "tests/test1.nim"
  echo "filterTests test: PASS"

when isMainModule:
  echo "Running test runner tests..."
  testGenerateJUnitXML()
  testGenerateTAP()
  testFilterTests()
  echo "All tests passed!"