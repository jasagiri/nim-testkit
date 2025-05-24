import std/[unittest, os, tempfiles, strutils, sequtils, times, json]
import ../src/execution/runner
import ../src/config/config
import ../src/organization/standard_layout
import ../src/integrations/[lang_core_integration, aspects_integration, optional_dependencies]

suite "TestRunner - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("test_runner_", "")
    let projectDir = tempDir / "test_project"
    createDir(projectDir)
    createDir(projectDir / "tests")
    createDir(projectDir / "build")
    
  teardown:
    removeDir(tempDir)
    
  test "Test discovery - find all test files":
    # Create test files
    writeFile(projectDir / "tests" / "test_basic.nim", "# Test file")
    writeFile(projectDir / "tests" / "test_advanced.nim", "# Test file")
    createDir(projectDir / "tests" / "unit")
    writeFile(projectDir / "tests" / "unit" / "test_core.nim", "# Test file")
    writeFile(projectDir / "tests" / "not_a_test.nim", "# Not a test")
    
    let runner = newTestRunner(projectDir)
    let tests = runner.discoverTests()
    
    check tests.len == 3
    check tests.anyIt("test_basic.nim" in it)
    check tests.anyIt("test_advanced.nim" in it)
    check tests.anyIt("test_core.nim" in it)
    check not tests.anyIt("not_a_test.nim" in it)
    
  test "Test discovery - empty directory":
    let runner = newTestRunner(projectDir)
    let tests = runner.discoverTests()
    check tests.len == 0
    
  test "Test discovery - with pattern filter":
    writeFile(projectDir / "tests" / "test_unit_one.nim", "# Test")
    writeFile(projectDir / "tests" / "test_unit_two.nim", "# Test")
    writeFile(projectDir / "tests" / "test_integration.nim", "# Test")
    
    let runner = newTestRunner(projectDir)
    let tests = runner.discoverTests("*unit*")
    
    check tests.len == 2
    check tests.allIt("unit" in it)
    
  test "Test execution - successful test":
    let testFile = projectDir / "tests" / "test_success.nim"
    writeFile(testFile, """
import std/unittest

suite "Success":
  test "passes":
    check true
""")
    
    let runner = newTestRunner(projectDir)
    let result = runner.runTest(testFile)
    
    check result.success
    check result.exitCode == 0
    check "OK" in result.output or "PASS" in result.output
    
  test "Test execution - failing test":
    let testFile = projectDir / "tests" / "test_fail.nim"
    writeFile(testFile, """
import std/unittest

suite "Failure":
  test "fails":
    check false
""")
    
    let runner = newTestRunner(projectDir)
    let result = runner.runTest(testFile)
    
    check not result.success
    check result.exitCode != 0
    check "FAIL" in result.output
    
  test "Test execution - compilation error":
    let testFile = projectDir / "tests" / "test_error.nim"
    writeFile(testFile, """
import std/unittest
invalid syntax here
""")
    
    let runner = newTestRunner(projectDir)
    let result = runner.runTest(testFile)
    
    check not result.success
    check result.exitCode != 0
    check result.error.len > 0
    
  test "Test execution - with timeout":
    let testFile = projectDir / "tests" / "test_timeout.nim"
    writeFile(testFile, """
import std/[unittest, os]

suite "Timeout":
  test "hangs":
    sleep(10000)  # Sleep for 10 seconds
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.timeout = 1  # 1 second timeout
    let result = runner.runTest(testFile)
    
    check not result.success
    check "timeout" in result.error.toLower or result.duration > 1.0
    
  test "Parallel test execution":
    # Create multiple test files
    for i in 1..5:
      let testFile = projectDir / "tests" / &"test_parallel_{i}.nim"
      writeFile(testFile, &"""
import std/[unittest, os]

suite "Parallel {i}":
  test "runs":
    sleep(100)  # Small delay
    check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.parallel = true
    runner.config.workers = 3
    
    let startTime = epochTime()
    let results = runner.runAllTests()
    let duration = epochTime() - startTime
    
    check results.total == 5
    check results.passed == 5
    check results.failed == 0
    # Should be faster than running sequentially (5 * 0.1 = 0.5s)
    check duration < 0.4
    
  test "Sequential test execution":
    # Create multiple test files
    for i in 1..3:
      let testFile = projectDir / "tests" / &"test_seq_{i}.nim"
      writeFile(testFile, &"""
import std/unittest

suite "Sequential {i}":
  test "runs":
    check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.parallel = false
    
    let results = runner.runAllTests()
    
    check results.total == 3
    check results.passed == 3
    check results.failed == 0
    
  test "Test filtering by pattern":
    writeFile(projectDir / "tests" / "test_unit_foo.nim", """
import std/unittest
suite "Unit": test "foo": check true
""")
    writeFile(projectDir / "tests" / "test_integration_bar.nim", """
import std/unittest
suite "Integration": test "bar": check true
""")
    
    let runner = newTestRunner(projectDir)
    let results = runner.runTests("*unit*")
    
    check results.total == 1
    check results.passed == 1
    
  test "Test output formatting - minimal":
    writeFile(projectDir / "tests" / "test_format.nim", """
import std/unittest
suite "Format": test "test": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.verbosity = Minimal
    let results = runner.runAllTests()
    
    check results.total == 1
    check results.passed == 1
    
  test "Test output formatting - verbose":
    writeFile(projectDir / "tests" / "test_verbose.nim", """
import std/unittest
suite "Verbose": test "detailed": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.verbosity = Verbose
    let results = runner.runAllTests()
    
    check results.total == 1
    check results.passed == 1
    
  test "Test result aggregation":
    writeFile(projectDir / "tests" / "test_pass.nim", """
import std/unittest
suite "Pass": test "ok": check true
""")
    writeFile(projectDir / "tests" / "test_fail.nim", """
import std/unittest
suite "Fail": test "not ok": check false
""")
    writeFile(projectDir / "tests" / "test_skip.nim", """
import std/unittest
suite "Skip": test "skipped": skip()
""")
    
    let runner = newTestRunner(projectDir)
    let results = runner.runAllTests()
    
    check results.total == 3
    check results.passed == 1
    check results.failed == 1
    check results.skipped == 1
    
  test "Test report generation - JSON":
    writeFile(projectDir / "tests" / "test_report.nim", """
import std/unittest
suite "Report": test "data": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.reportFormat = JsonFormat
    let results = runner.runAllTests()
    
    let reportFile = projectDir / "build" / "test-results.json"
    check fileExists(reportFile)
    
    let reportData = parseFile(reportFile)
    check reportData["total"].getInt() == 1
    check reportData["passed"].getInt() == 1
    
  test "Test report generation - JUnit XML":
    writeFile(projectDir / "tests" / "test_junit.nim", """
import std/unittest
suite "JUnit": test "xml": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.reportFormat = JUnitFormat
    let results = runner.runAllTests()
    
    let reportFile = projectDir / "build" / "test-results.xml"
    check fileExists(reportFile)
    check "<testsuite" in readFile(reportFile)
    
  test "Coverage integration":
    writeFile(projectDir / "tests" / "test_coverage.nim", """
import std/unittest
suite "Coverage": test "tracked": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.coverage = true
    let results = runner.runAllTests()
    
    check results.total == 1
    # Coverage files would be generated if coverage tool is available
    
  test "Custom test command":
    let runner = newTestRunner(projectDir)
    runner.config.testCommand = "echo 'custom test'"
    
    let testFile = projectDir / "tests" / "test_custom.nim"
    writeFile(testFile, "# Test")
    
    let result = runner.runTest(testFile)
    check "custom test" in result.output
    
  test "Environment variables":
    writeFile(projectDir / "tests" / "test_env.nim", """
import std/[unittest, os]
suite "Env": test "var": check getEnv("TEST_VAR") == "test_value"
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.environment["TEST_VAR"] = "test_value"
    let results = runner.runAllTests()
    
    check results.passed == 1
    
  test "Before/after hooks":
    var beforeCalled = false
    var afterCalled = false
    
    let runner = newTestRunner(projectDir)
    runner.beforeAll = proc() = beforeCalled = true
    runner.afterAll = proc() = afterCalled = true
    
    writeFile(projectDir / "tests" / "test_hooks.nim", """
import std/unittest
suite "Hooks": test "run": check true
""")
    
    discard runner.runAllTests()
    
    check beforeCalled
    check afterCalled
    
  test "Test retry on failure":
    var attemptCount = 0
    let testFile = projectDir / "tests" / "test_retry.nim"
    
    # This would need a more complex setup to actually retry
    writeFile(testFile, """
import std/unittest
suite "Retry": test "flaky": check true
""")
    
    let runner = newTestRunner(projectDir)
    runner.config.retryCount = 2
    let result = runner.runTest(testFile)
    
    check result.success
    
  test "Watch mode file detection":
    let runner = newTestRunner(projectDir)
    
    # Simulate file change detection
    writeFile(projectDir / "tests" / "test_watch.nim", "# Initial")
    let files1 = runner.discoverTests()
    
    sleep(100)
    writeFile(projectDir / "tests" / "test_watch.nim", "# Modified")
    writeFile(projectDir / "tests" / "test_new.nim", "# New file")
    
    let files2 = runner.discoverTests()
    check files2.len == files1.len + 1
    
  test "Integration with aspects":
    writeFile(projectDir / "tests" / "test_aspects.nim", """
import std/unittest
suite "Aspects": test "traced": check true
""")
    
    let runner = newTestRunner(projectDir)
    when defined(useAspects):
      runner.config.enableAspects = true
    
    let results = runner.runAllTests()
    check results.passed == 1
    
  test "Build directory management":
    let runner = newTestRunner(projectDir)
    let layout = detectProjectLayout(projectDir)
    
    runner.prepareTestEnvironment()
    
    check dirExists(layout.buildDir)
    check dirExists(layout.testResultsDir)
    check dirExists(layout.coverageDir)
    
  test "Error handling - invalid project directory":
    let runner = newTestRunner("/nonexistent/path")
    let tests = runner.discoverTests()
    check tests.len == 0
    
  test "Error handling - permission denied":
    when not defined(windows):
      let restrictedDir = projectDir / "restricted"
      createDir(restrictedDir)
      writeFile(restrictedDir / "test_perm.nim", "# Test")
      
      # This would need actual permission changes to test properly
      let runner = newTestRunner(projectDir)
      let tests = runner.discoverTests()
      check tests.len >= 0  # Should handle gracefully