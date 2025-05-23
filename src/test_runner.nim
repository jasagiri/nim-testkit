## Nim TestKit Automated Test Runner
##
## Runs all generated tests with support for various output formats

import std/[os, osproc, strformat, strutils, times, algorithm, terminal, json, xmltree, sequtils, strtabs]
import config, jujutsu_test_integration, vcs_integration
when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
  import mcp_jujutsu_integration

type
  TestResult* = object
    name*: string
    file*: string
    passed*: bool
    duration*: float
    output*: string
    
  TestSuite* = object
    name*: string
    results*: seq[TestResult]
    totalDuration*: float

proc colorize(text: string, color: ForegroundColor): string =
  if stdout.isatty:
    return fmt"{ansiForegroundColorCode(color)}{text}{ansiResetCode}"
  else:
    return text

proc runSingleTest(testFile: string, config: TestKitConfig): TestResult =
  ## Runs a single test file and returns the result
  let startTime = cpuTime()
  var compileFlags = ""
  if config.usePowerAssert:
    compileFlags &= " -d:powerAssert"
  let cmd = fmt"nim c -r{compileFlags} {testFile}"
  
  let (output, exitCode) = execCmdEx(cmd)
  let duration = cpuTime() - startTime
  
  result = TestResult(
    name: extractFilename(testFile),
    file: testFile,
    passed: exitCode == 0,
    duration: duration,
    output: output
  )

proc runTestsInParallel(testFiles: seq[string], config: TestKitConfig): seq[TestResult] =
  ## Runs tests in parallel - simplified implementation for now
  # TODO: Implement proper parallel execution with taskpools or malebolgia
  result = @[]
  
  for testFile in testFiles:
    result.add(runSingleTest(testFile, config))

proc generateJUnitXML*(suite: TestSuite): string =
  ## Generates JUnit XML format output
  var xml = newElement("testsuite")
  xml.attrs = newStringTable()
  xml.attrs["name"] = suite.name
  xml.attrs["tests"] = $suite.results.len
  xml.attrs["time"] = fmt"{suite.totalDuration:.3f}"
  
  var failures = 0
  for test in suite.results:
    if not test.passed:
      failures += 1
  
  xml.attrs["failures"] = $failures
  
  for test in suite.results:
    var testCase = newElement("testcase")
    testCase.attrs = newStringTable()
    testCase.attrs["name"] = test.name
    testCase.attrs["time"] = fmt"{test.duration:.3f}"
    
    if not test.passed:
      var failure = newElement("failure")
      failure.attrs = newStringTable()
      failure.attrs["message"] = "Test failed"
      failure.add(newText(test.output))
      testCase.add(failure)
    
    xml.add(testCase)
  
  return $xml

proc generateTAP*(suite: TestSuite): string =
  ## Generates TAP (Test Anything Protocol) format output
  result = fmt"TAP version 13{'\n'}"
  result &= fmt"1..{suite.results.len}{'\n'}"
  
  for i, test in suite.results:
    let status = if test.passed: "ok" else: "not ok"
    result &= fmt"{status} {i+1} - {test.name}{'\n'}"
    
    if not test.passed:
      # Add diagnostic output
      for line in test.output.splitLines():
        result &= fmt"# {line}{'\n'}"

proc printColoredOutput(suite: TestSuite, config: TestKitConfig) =
  ## Prints colored test output
  echo colorize("===== Nim TestKit Test Runner =====", fgCyan)
  echo ""
  
  var passed = 0
  var failed = 0
  
  for test in suite.results:
    let status = if test.passed:
      colorize("PASS", fgGreen)
    else:
      colorize("FAIL", fgRed)
    
    echo fmt"{status} {test.name} ({test.duration:.3f}s)"
    
    if test.passed:
      passed += 1
    else:
      failed += 1
      if config.colorOutput:
        echo colorize("Output:", fgYellow)
        echo test.output
  
  echo ""
  echo colorize("===== Test Summary =====", fgCyan)
  echo fmt"Total: {suite.results.len}"
  echo colorize(fmt"Passed: {passed}", fgGreen)
  echo colorize(fmt"Failed: {failed}", fgRed)
  echo fmt"Time: {suite.totalDuration:.3f}s"

proc filterTests*(testFiles: seq[string], pattern: string): seq[string] =
  ## Filters test files by pattern
  if pattern == "":
    return testFiles
  
  result = @[]
  for file in testFiles:
    if file.contains(pattern):
      result.add(file)

proc displayCachedResults(cache: TestCache) =
  ## Displays cached test results
  echo colorize("===== Cached Test Results =====", fgCyan)
  
  var passed = 0
  var failed = 0
  
  for (file, success) in cache.results:
    if success:
      echo colorize("PASS", fgGreen) & " " & file
      passed += 1
    else:
      echo colorize("FAIL", fgRed) & " " & file
      failed += 1
  
  echo ""
  echo colorize("===== Summary =====", fgCyan)
  echo fmt"Total: {cache.results.len}"
  echo colorize(fmt"Passed: {passed}", fgGreen)
  echo colorize(fmt"Failed: {failed}", fgRed)
  echo fmt"Cache timestamp: {cache.timestamp}"

proc runTests(pattern = "", outputFormat = "colored", jjIntegration = true, workspace = "") =
  echo "===== Nim TestKit Automated Test Runner ====="
  let startTime = cpuTime()
  
  # Load configuration
  let config = loadConfig()
  
  # Initialize VCS integration
  let vcsInterface = newVCSInterface(config.vcs)
  echo vcsInterface.getVCSStatusSummary()
  
  # Initialize MCP-Jujutsu if enabled
  when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
    var mcpJjContext: JujutsuTestContext
    # Use vcs.jujutsu instead of deprecated enableJujutsu
    if config.vcs.jujutsu:
      mcpJjContext = initJujutsuIntegration(config)
      if mcpJjContext.strategy.enabled:
        echo "MCP-Jujutsu integration enabled"
        
        # Show best practices
        for practice in getJujutsuBestPractices():
          echo practice
        echo ""
  
  # Get Jujutsu info if enabled
  var jjInfo: JujutsuInfo
  var cache: TestCache
  var snapshotOptimized = false
  
  if jjIntegration:
    jjInfo = getJujutsuInfo()
    if jjInfo.isJjRepo:
      echo "Jujutsu repository detected"
      
      # Set up workspace if specified
      if workspace != "":
        setupWorkspaceTests(workspace)
      
      # Get operation log and workspaces
      jjInfo.operationLog = getOperationLog()
      jjInfo.workspaces = getWorkspaces()
      
      cache = loadTestCache()
      
      # Check snapshot optimization
      let lastSnapshot = cache.contentHash
      let currentSnapshot = getSnapshotInfo().hash
      
      if not shouldRunTests(jjInfo, cache):
        echo "No changes detected, using cached results"
        displayCachedResults(cache)
        return
      
      # Optimize test runs based on snapshots
      if lastSnapshot != "" and lastSnapshot != currentSnapshot:
        snapshotOptimized = true
  
  # Get root directory
  let testsDir = config.testsDir
  
  if not dirExists(testsDir):
    echo "Error: Tests directory not found at " & testsDir
    quit(1)
    
  # Find all test files
  var testFiles: seq[string] = @[]
  
  for pattern in config.excludePatterns:
    for file in walkFiles(testsDir / pattern):
      testFiles.add(file)
  
  # Filter tests if pattern provided
  testFiles = filterTests(testFiles, pattern)
  
  # Use MCP-Jujutsu filtering if available, otherwise fall back to basic integration
  var mcpUsed = false
  when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
    if mcpJjContext.strategy.enabled and mcpJjContext.strategy.changeBasedTesting:
      testFiles = getTestFilesForChange(mcpJjContext, testFiles)
      echo fmt"MCP-Jujutsu: Running {testFiles.len} tests for current change"
      mcpUsed = true
      
      # Show conflict warnings
      let conflictWarnings = handleConflicts(mcpJjContext)
      for warning in conflictWarnings:
        echo warning
  
  # Filter by Jujutsu changes if enabled (fallback to basic integration)
  if not mcpUsed and jjIntegration and jjInfo.isJjRepo:
    if snapshotOptimized:
      let optimizedFiles = optimizeTestRuns(testFiles, cache.contentHash)
      if optimizedFiles.len < testFiles.len:
        echo fmt"Snapshot optimization: Running {optimizedFiles.len} of {testFiles.len} tests"
        testFiles = optimizedFiles
    else:
      testFiles = filterTestsByChange(testFiles, jjInfo)
      echo fmt"Running {testFiles.len} tests affected by current changes"
  
  # Filter by VCS changes if any VCS has changes
  if vcsInterface.hasChanges():
    let vcsFilteredFiles = vcsInterface.getTestFilesForChanges(testFiles)
    if vcsFilteredFiles.len < testFiles.len:
      echo fmt"VCS integration: Running {vcsFilteredFiles.len} tests related to changes"
      testFiles = vcsFilteredFiles
  
  # Sort test files for consistent execution
  testFiles.sort()
  
  # Run tests
  var results: seq[TestResult]
  
  if config.parallelTests:
    results = runTestsInParallel(testFiles, config)
  else:
    results = @[]
    for testFile in testFiles:
      # Check MCP-Jujutsu cache
      when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
        if mcpJjContext.strategy.enabled and shouldSkipTest(mcpJjContext, testFile):
          # Add cached result
          results.add(TestResult(
            name: extractFilename(testFile),
            file: testFile,
            passed: true,
            duration: 0.0,
            output: "Cached (PASS)"
          ))
          continue
      
      let result = runSingleTest(testFile, config)
      results.add(result)
      
      # Cache result with MCP-Jujutsu
      when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
        if mcpJjContext.strategy.enabled:
          cacheTestResult(mcpJjContext, testFile, result.passed, result.duration)
  
  # Create test suite
  let suite = TestSuite(
    name: "Nim TestKit Tests",
    results: results,
    totalDuration: cpuTime() - startTime
  )
  
  # Output results in requested format
  case outputFormat:
  of "junit":
    let xml = generateJUnitXML(suite)
    writeFile("test-results.xml", xml)
    echo "JUnit XML written to test-results.xml"
  of "tap":
    echo generateTAP(suite)
  else:
    printColoredOutput(suite, config)
  
  # Save test history if jj integration is enabled
  if jjIntegration and jjInfo.isJjRepo:
    var history = TestHistory(
      changeId: jjInfo.currentChange,
      timestamp: now().toTime(),
      coverage: 0.0  # TODO: Get actual coverage
    )
    
    # Get parent changes
    history.parentChanges = @[]
    let parentHistory = trackTestEvolution(jjInfo.currentChange)
    for ph in parentHistory:
      history.parentChanges.add(ph.changeId)
    
    # Convert TestResult to TestHistoryResult
    history.results = @[]
    for test in results:
      history.results.add(TestHistoryResult(
        name: test.name,
        file: test.file,
        passed: test.passed
      ))
    
    saveTestHistory(history)
    
    # Update cache
    cache.changeId = jjInfo.currentChange
    cache.contentHash = getSnapshotInfo().hash
    cache.timestamp = now().toTime()
    cache.results = @[]
    
    for test in results:
      cache.results.add((file: test.file, passed: test.passed))
    
    saveTestCache(cache)
  
  # Generate MCP-Jujutsu report if enabled
  when not defined(noMcpJujutsu) and not defined(disableMcpJujutsu):
    if mcpJjContext.strategy.enabled:
      let testResults = results.mapIt((file: it.file, passed: it.passed))
      let report = createChangeTestReport(mcpJjContext, testResults)
      if report != "":
        echo ""
        echo report
  
  # Exit with error code if any tests failed
  for test in results:
    if not test.passed:
      quit(1)

when isMainModule:
  import cligen
  dispatch(runTests)