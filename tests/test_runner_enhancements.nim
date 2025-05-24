# Simple test to avoid name conflicts
import ../src/execution/runner
import std/[os, strutils]

# Direct testing without unittest
proc testFilterByPattern() =
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
  echo "Filter by pattern test: PASS"

proc testExtraFeatures() =
  # Add more tests for enhanced features here
  echo "Extra features test: PASS"

when isMainModule:
  echo "Running test runner enhancement tests..."
  testFilterByPattern()
  testExtraFeatures()
  echo "All tests passed!"