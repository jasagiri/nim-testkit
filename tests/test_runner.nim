# Simple test to avoid name conflicts
import ../src/test_runner
import std/os

# Direct testing without unittest
proc testTestSuite() =
  var testSuite = TestSuite(name: "Test Suite", results: @[])
  assert testSuite.name == "Test Suite"
  assert testSuite.results.len == 0
  echo "TestSuite test: PASS"

when isMainModule:
  echo "Running test runner basic tests..."
  testTestSuite()
  echo "All tests passed!"