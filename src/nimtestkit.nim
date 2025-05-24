# Nim TestKit - Zero-dependency test framework
# Main module that exports all functionality

import std/[os, parseopt, strutils]
import ./core/[types, results, runner]
import ./analysis/mece_detector
import ./config/parser
import ./generation/[unit_gen, integration_gen, system_gen]
import ./runner/category_runner
import ./utils/env_detector

export types, results, runner, mece_detector, parser
export unit_gen except TestCase
export integration_gen except TestStep  
export system_gen
export category_runner, env_detector

# Version information
const
  NimTestKitVersion* = "0.1.0"
  NimTestKitDescription* = "Minimal, zero-dependency test framework for Nim"

# Re-export commonly used types and procs from core modules
export
  # Types from core/types
  TestStatus, TestCategory, TestResult, TestCase, TestSuite, TestReport,
  TestFilter, TestConfig, OutputFormat,
  # Result handling from core/results
  ResultCollector, initResultCollector, addResult, startTest, endTest,
  passTest, failTest, errorTest, skipTest, generateReport, printSummary,
  # Runner from core/runner
  TestRunner, initTestRunner, addSuite, run, runTests, runTest,
  # MECE from analysis/mece_detector
  MECEStructure, MECEReport, MECEStats, analyzeStructure, validateMECE,
  analyzeMECE, initMECEStructure, printMECEReport, generateMECEStructure,
  # Config from config/parser
  parseTestConfig, parseEnvConfig, loadConfig, generateDefaultConfig, saveDefaultConfig,
  # Generation functions (avoiding type conflicts)
  generateUnitTest, generateKernelFunctionTest, generateMemoryManagementTest,
  generateCapabilityTest, saveUnitTest,
  generateIntegrationTest, generateHALIntegrationTest, generateWASIIntegrationTest,
  generatePlatformDriverTest, saveIntegrationTest,
  generateSystemTest, generateBootSequenceTest, generateARVRWorkloadTest,
  generatePerformanceBenchmark, saveSystemTest,
  # Category runner
  CategoryRunner, initCategoryRunner, CategoryRunConfig, ExecutionMode,
  # Environment detection
  detectEnvironment, EnvironmentInfo, BuildEnvironment

# Helper templates for test definition
template test*(name: string, body: untyped): untyped =
  ## Define a test case
  proc testProc() {.nimcall, gensym.} =
    body
  
  testCases.add(initTestCase(name, testProc))

template suite*(name: string, body: untyped): untyped =
  ## Define a test suite
  var testCases {.inject.}: seq[types.TestCase] = @[]
  body
  testSuites.add(types.TestSuite(
    name: name,
    category: tcUnit,  # Default to unit tests
    tests: testCases
  ))

template setup*(body: untyped): untyped =
  ## Define setup for current test or suite
  proc setupProc() {.nimcall, gensym.} =
    body
  when declared(testCases):
    if testCases.len > 0:
      testCases[^1].setupProc = setupProc
  else:
    currentSetup = setupProc

template teardown*(body: untyped): untyped =
  ## Define teardown for current test or suite
  proc teardownProc() {.nimcall, gensym.} =
    body
  when declared(testCases):
    if testCases.len > 0:
      testCases[^1].teardownProc = teardownProc
  else:
    currentTeardown = teardownProc

# Assertion helpers
template check*(condition: bool, message: string = "") =
  ## Check a condition, fail test if false
  if not condition:
    let msg = if message.len > 0: message else: "Check failed: " & astToStr(condition)
    raise newException(AssertionDefect, msg)

template expect*(exception: typedesc, body: untyped) =
  ## Expect an exception to be raised
  var raised = false
  try:
    body
  except exception:
    raised = true
  except CatchableError:
    raised = false
  
  if not raised:
    raise newException(AssertionDefect, "Expected " & $exception & " to be raised")

template skip*(reason: string = "") =
  ## Skip the current test
  raise newException(SkipTest, reason)

type
  SkipTest* = object of CatchableError

# Command-line interface helpers
proc parseCommandLine*(): TestConfig =
  ## Parse command-line arguments for test configuration
  result = loadConfig()
  
  var p = initOptParser()
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "v", "verbose":
        result.verbose = true
      of "f", "format":
        case p.val
        of "text": result.outputFormat = ofText
        of "json": result.outputFormat = ofJson
        of "xml": result.outputFormat = ofXml
        of "tap": result.outputFormat = ofTap
        of "junit": result.outputFormat = ofJunit
        else: discard
      of "p", "parallel":
        result.parallel = true
      of "fail-fast":
        result.failFast = true
      of "t", "timeout":
        try:
          result.timeout = parseFloat(p.val)
        except ValueError:
          discard
      of "c", "category":
        case p.val
        of "unit": result.filter.categories.add(tcUnit)
        of "integration": result.filter.categories.add(tcIntegration)
        of "system": result.filter.categories.add(tcSystem)
        of "performance": result.filter.categories.add(tcPerformance)
        else: discard
      of "tag":
        result.filter.tags.add(p.val)
      of "pattern":
        result.filter.patterns.add(p.val)
      of "exclude":
        result.filter.excludePatterns.add(p.val)
      of "o", "output":
        result.reportFile = p.val
      of "analyze-mece":
        # Special mode to analyze test structure
        let report = analyzeMECE(getCurrentDir())
        report.printMECEReport()
        quit(if report.isValid: 0 else: 1)
      of "generate-mece":
        generateMECEStructure(getCurrentDir())
        quit(0)
      of "generate-config":
        saveDefaultConfig()
        quit(0)
      else: discard
    of cmdArgument:
      # Could be used for specific test files
      discard

# Main entry point
proc runTestsMain*() =
  ## Main entry point for test execution
  var testSuites {.global.}: seq[TestSuite] = @[]
  
  let config = parseCommandLine()
  var runner = initTestRunner(config)
  
  for suite in testSuites:
    runner.addSuite(suite)
  
  let report = runner.run()
  
  # Exit with appropriate code
  if report.failed > 0 or report.errors > 0:
    quit(1)
  else:
    quit(0)

# Convenience macro for defining main test module
template nimTestMain*() =
  when isMainModule:
    runTestsMain()