# Category-aware test runner for nim-testkit
# Executes tests by category with proper isolation

import std/[os, osproc, strutils, strformat, tables, times, sequtils, streams, parseopt]
import ../core/[types, results]
import ../analysis/mece_detector

type
  CategoryRunner* = object
    config: TestConfig
    testDirs: Table[TestCategory, seq[string]]
    results: Table[TestCategory, seq[TestResult]]
    
  ExecutionMode* = enum
    emSequential = "sequential"
    emParallel = "parallel"
    emMixed = "mixed"  # Parallel within category, sequential between

  CategoryRunConfig* = object
    mode*: ExecutionMode
    maxParallelJobs*: int
    categoryOrder*: seq[TestCategory]
    isolateCategories*: bool
    reportProgress*: bool

proc initCategoryRunner*(config: TestConfig = initTestConfig()): CategoryRunner =
  result.config = config
  result.testDirs = initTable[TestCategory, seq[string]]()
  result.results = initTable[TestCategory, seq[TestResult]]()

proc discoverCategoryTests*(runner: var CategoryRunner, testRoot: string) =
  ## Discover tests organized by MECE categories
  let structure = analyzeStructure(testRoot)
  
  # Add standard category tests
  for category, files in structure.categories:
    if category notin runner.testDirs:
      runner.testDirs[category] = @[]
    runner.testDirs[category].add(files)
  
  # Add custom category tests as tcCustom
  for customCat, files in structure.customCategories:
    if tcCustom notin runner.testDirs:
      runner.testDirs[tcCustom] = @[]
    runner.testDirs[tcCustom].add(files)

proc runTestFile(testFile: string, config: TestConfig): TestResult =
  ## Run a single test file and return result
  result = initTestResult(testFile.extractFilename())
  result.file = testFile
  result.startTime = epochTime()
  
  # Compile test file
  let compileCmd = fmt"nim c --hints:off --mm:orc -r {testFile}"
  let compileResult = execCmdEx(compileCmd)
  
  result.endTime = epochTime()
  result.duration = result.endTime - result.startTime
  
  if compileResult.exitCode == 0:
    result.status = tsPassed
    result.message = "Test passed"
  else:
    result.status = tsFailed
    result.message = compileResult.output
    result.stackTrace = compileResult.output

proc runCategorySequential(runner: var CategoryRunner, category: TestCategory, 
                          files: seq[string], config: CategoryRunConfig): seq[TestResult] =
  ## Run all tests in a category sequentially
  result = @[]
  
  if config.reportProgress:
    echo fmt"Running {files.len} {category} tests sequentially..."
  
  for i, testFile in files:
    if config.reportProgress:
      echo fmt"  [{i+1}/{files.len}] {testFile.extractFilename()}"
    
    let testResult = runTestFile(testFile, runner.config)
    result.add(testResult)
    
    # Stop on failure if configured
    if runner.config.failFast and testResult.status == tsFailed:
      if config.reportProgress:
        echo "  ⚠️  Stopping due to test failure (fail-fast enabled)"
      break

proc runCategoryParallel(runner: var CategoryRunner, category: TestCategory,
                        files: seq[string], config: CategoryRunConfig): seq[TestResult] =
  ## Run all tests in a category in parallel using processes
  result = @[]
  
  if config.reportProgress:
    echo fmt"Running {files.len} {category} tests in parallel (max {config.maxParallelJobs} jobs)..."
  
  # Simple process-based parallel execution
  var running: seq[tuple[process: Process, file: string, startTime: float]] = @[]
  var fileIndex = 0
  
  while fileIndex < files.len or running.len > 0:
    # Start new processes up to the limit
    while running.len < config.maxParallelJobs and fileIndex < files.len:
      let testFile = files[fileIndex]
      let cmd = fmt"nim c --hints:off --mm:orc -r {testFile}"
      let process = startProcess(cmd, options = {poUsePath})
      running.add((process: process, file: testFile, startTime: epochTime()))
      inc fileIndex
    
    # Check for completed processes
    var i = 0
    while i < running.len:
      if not running[i].process.running:
        let exitCode = running[i].process.waitForExit()
        let output = running[i].process.outputStream.readAll()
        running[i].process.close()
        
        # Create result
        var testResult = initTestResult(running[i].file.extractFilename())
        testResult.file = running[i].file
        testResult.startTime = running[i].startTime
        testResult.endTime = epochTime()
        testResult.duration = testResult.endTime - testResult.startTime
        
        if exitCode == 0:
          testResult.status = tsPassed
          testResult.message = "Test passed"
        else:
          testResult.status = tsFailed
          testResult.message = output
        
        result.add(testResult)
        running.del(i)
      else:
        inc i
    
    # Small delay to prevent busy waiting
    if running.len >= config.maxParallelJobs:
      sleep(50)
  
  if config.reportProgress:
    let passed = result.countIt(it.status == tsPassed)
    echo fmt"  ✓ Completed: {passed}/{result.len} passed"

proc runCategory*(runner: var CategoryRunner, category: TestCategory, 
                 config: CategoryRunConfig = CategoryRunConfig()): seq[TestResult] =
  ## Run all tests in a specific category
  if category notin runner.testDirs:
    return @[]
  
  let files = runner.testDirs[category]
  if files.len == 0:
    return @[]
  
  if config.reportProgress:
    echo fmt"\n{'='.repeat(60)}"
    echo fmt"Running {category} tests"
    echo fmt"{'='.repeat(60)}"
  
  # Run with appropriate execution mode
  case config.mode
  of emSequential:
    result = runner.runCategorySequential(category, files, config)
  of emParallel:
    result = runner.runCategoryParallel(category, files, config)
  of emMixed:
    # For mixed mode, use parallel for this category
    result = runner.runCategoryParallel(category, files, config)
  
  # Store results
  runner.results[category] = result
  
  # Category isolation cleanup if needed
  if config.isolateCategories:
    # Could add cleanup operations here
    discard

proc runAll*(runner: var CategoryRunner, config: CategoryRunConfig = CategoryRunConfig()): TestReport =
  ## Run all discovered tests by category
  var allResults: seq[TestResult] = @[]
  
  # Determine category execution order
  let categories = if config.categoryOrder.len > 0:
    config.categoryOrder
  else:
    # Default order: unit -> integration -> system -> custom
    @[tcUnit, tcIntegration, tcSystem, tcPerformance, tcCustom]
  
  # Run each category
  for category in categories:
    if category in runner.testDirs:
      let categoryResults = runner.runCategory(category, config)
      allResults.add(categoryResults)
      
      # Stop if fail-fast and category had failures
      if runner.config.failFast and categoryResults.anyIt(it.status == tsFailed):
        if config.reportProgress:
          echo "\n⚠️  Stopping test execution due to failures (fail-fast enabled)"
        break
  
  # Generate report
  result = initTestReport()
  result.results = allResults
  result.totalTests = allResults.len
  
  for r in allResults:
    case r.status
    of tsPassed: inc result.passed
    of tsFailed: inc result.failed
    of tsSkipped: inc result.skipped
    of tsError: inc result.errors
    else: discard
  
  result.endTime = epochTime()
  result.duration = result.endTime - result.startTime

proc printCategoryReport*(runner: CategoryRunner) =
  ## Print detailed report by category
  echo "\n" & "=".repeat(60)
  echo "Test Results by Category"
  echo "=".repeat(60)
  
  for category, results in runner.results:
    let total = results.len
    let passed = results.countIt(it.status == tsPassed)
    let failed = results.countIt(it.status == tsFailed)
    let skipped = results.countIt(it.status == tsSkipped)
    
    echo fmt"\n{category}:"
    echo fmt"  Total:   {total}"
    echo fmt"  Passed:  {passed} ({passed / total * 100:.1f}%)"
    echo fmt"  Failed:  {failed}"
    echo fmt"  Skipped: {skipped}"
    
    if failed > 0:
      echo "  Failed tests:"
      for result in results:
        if result.status == tsFailed:
          echo fmt"    - {result.name}"

# Convenience functions
proc runUnitTests*(testRoot: string, config: CategoryRunConfig = CategoryRunConfig()): seq[TestResult] =
  ## Run only unit tests
  var runner = initCategoryRunner()
  runner.discoverCategoryTests(testRoot)
  result = runner.runCategory(tcUnit, config)

proc runIntegrationTests*(testRoot: string, config: CategoryRunConfig = CategoryRunConfig()): seq[TestResult] =
  ## Run only integration tests
  var runner = initCategoryRunner()
  runner.discoverCategoryTests(testRoot)
  result = runner.runCategory(tcIntegration, config)

proc runSystemTests*(testRoot: string, config: CategoryRunConfig = CategoryRunConfig()): seq[TestResult] =
  ## Run only system tests
  var runner = initCategoryRunner()
  runner.discoverCategoryTests(testRoot)
  result = runner.runCategory(tcSystem, config)

# Main entry point
proc main() =
  ## Command-line interface for category runner
  
  var config = CategoryRunConfig(
    mode: emMixed,
    maxParallelJobs: 4,
    isolateCategories: true,
    reportProgress: true
  )
  
  var testRoot = getCurrentDir()
  var categories: seq[TestCategory] = @[]
  
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "sequential", "s":
        config.mode = emSequential
      of "parallel", "p":
        config.mode = emParallel
      of "mixed", "m":
        config.mode = emMixed
      of "jobs", "j":
        config.maxParallelJobs = parseInt(p.val)
      of "category", "c":
        case p.val.toLowerAscii()
        of "unit": categories.add(tcUnit)
        of "integration": categories.add(tcIntegration)
        of "system": categories.add(tcSystem)
        of "performance": categories.add(tcPerformance)
        else: discard
      of "no-isolation":
        config.isolateCategories = false
      of "quiet", "q":
        config.reportProgress = false
      else: discard
    of cmdArgument:
      testRoot = p.key
  
  if categories.len > 0:
    config.categoryOrder = categories
  
  # Run tests
  var runner = initCategoryRunner()
  runner.discoverCategoryTests(testRoot)
  
  let report = runner.runAll(config)
  
  # Print results
  runner.printCategoryReport()
  report.printSummary()
  
  # Exit with appropriate code
  if report.failed > 0 or report.errors > 0:
    quit(1)
  else:
    quit(0)

when isMainModule:
  main()