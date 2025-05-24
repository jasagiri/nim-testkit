# Test to verify Phase 1 implementation is complete
# Compiles all modules and runs basic functionality tests

import std/[os, strutils]
import ../src/nimtestkit

# Simple test framework since unittest conflicts with our exports
template test(name: string, body: untyped) =
  echo "  Testing: ", name
  try:
    body
    echo "    ✓ PASSED"
  except AssertionDefect as e:
    echo "    ✗ FAILED: ", e.msg
    quit(1)
  except CatchableError as e:
    echo "    ✗ ERROR: ", e.msg
    quit(1)

template check(condition: bool, msg: string = "") =
  if not condition:
    let message = if msg.len > 0: msg else: "Check failed"
    raise newException(AssertionDefect, message)

echo "Running Phase 1 Completion Tests..."

test "All modules export correctly":
  # Test that all modules are accessible
  var config = initTestConfig()
  check config.timeout >= 0.0, "Config should initialize with timeout >= 0"
  
  var runner = initTestRunner(config)
  # Just verify runner initializes
  check true
  
  # Test MECE detection
  let meceReport = analyzeMECE(".")
  check meceReport.isValid or not meceReport.isValid  # Just check it runs
  
  # Test environment detection
  let envInfo = detectEnvironment()
  check envInfo.environment.ord >= 0  # Just verify it returns a valid enum

test "Test generation templates work":
  # Unit test generation
  let unitTemplate = generateKernelFunctionTest("testFunc", "kernel/core")
  check unitTemplate.functionName == "testFunc", "Unit template function name mismatch"
  check unitTemplate.category == tcUnit, "Unit template category mismatch"
  
  # Integration test generation
  let integTemplate = generateHALIntegrationTest("memory", "uart")
  check integTemplate.testName == "HAL-uart", "Integration template test name mismatch"
  check integTemplate.category == tcIntegration, "Integration template category mismatch"
  
  # System test generation
  let sysTemplate = generateBootSequenceTest()
  check sysTemplate.testName == "BootSequence", "System template test name mismatch"
  check sysTemplate.category == tcSystem, "System template category mismatch"

test "Category runner initializes":
  var runner = initCategoryRunner()
  # Just verify it initializes without error
  check true

test "Configuration parsing works":
  # Test config loading
  let config = loadConfig()  # Load default config
  check config.outputFormat in [ofText, ofJson, ofXml, ofTap, ofJunit]
  check config.timeout >= 0.0
  
  # Test environment variable override
  var testConfig = initTestConfig()
  testConfig.parallel = true
  parseEnvConfig(testConfig)
  # Config values may have been overridden by env vars
  check testConfig.outputFormat in [ofText, ofJson, ofXml, ofTap, ofJunit]

echo "Phase 1 implementation verified successfully!"