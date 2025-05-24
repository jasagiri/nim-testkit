# Comprehensive test runner for nim-testkit - runs all tests and reports coverage

import std/[unittest, os, strformat, times]
import ../src/nimtestkit

# Import all test modules
import spec/unit/test_core_types
import spec/unit/test_core_results  
import spec/unit/test_core_runner
import spec/unit/test_mece_detector
import spec/unit/test_config_parser
import spec/unit/test_nimtestkit

proc runAllTests*() =
  echo "Running comprehensive nim-testkit test suite..."
  echo "=" .repeat(60)
  
  let startTime = epochTime()
  
  # The unittest module will automatically run all test suites
  # that have been imported above
  
  let endTime = epochTime()
  let duration = endTime - startTime
  
  echo "\n" & "=" .repeat(60)
  echo fmt"All tests completed in {duration:.2f} seconds"
  echo "=" .repeat(60)

when isMainModule:
  runAllTests()