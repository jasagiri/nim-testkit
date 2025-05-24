## Comprehensive test runner for nim-testkit
## Executes all test suites and generates coverage report

import std/[os, strutils, sequtils, terminal, times, json]

type
  TestResult = object
    name: string
    passed: bool
    duration: float
    output: string
    
  TestSummary = object
    total: int
    passed: int
    failed: int
    skipped: int
    duration: float
    failures: seq[string]

proc colored(text: string, color: ForegroundColor): string =
  if isatty(stdout):
    return ansiForegroundColorCode(color) & text & ansiResetCode
  else:
    return text

proc runTest(testFile: string): TestResult =
  result.name = testFile.extractFilename()
  let startTime = epochTime()
  
  # Compile and run the test
  let cmd = "nim c -r --hints:off --mm:orc " & testFile
  let (output, exitCode) = gorgeEx(cmd)
  
  result.duration = epochTime() - startTime
  result.output = output
  result.passed = exitCode == 0
  
  if result.passed:
    echo colored("✓", fgGreen), " ", result.name, 
         colored(" (" & formatFloat(result.duration, ffDecimal, 2) & "s)", fgCyan)
  else:
    echo colored("✗", fgRed), " ", result.name,
         colored(" (" & formatFloat(result.duration, ffDecimal, 2) & "s)", fgCyan)

proc discoverTests(dir: string): seq[string] =
  for file in walkFiles(dir / "test_*.nim"):
    result.add(file)
  result.sort()

proc generateReport(summary: TestSummary, results: seq[TestResult]) =
  let reportDir = "build" / "test-results"
  createDir(reportDir)
  
  # Generate JSON report
  var jsonReport = %*{
    "summary": {
      "total": summary.total,
      "passed": summary.passed,
      "failed": summary.failed,
      "skipped": summary.skipped,
      "duration": summary.duration,
      "timestamp": $now(),
      "success": summary.failed == 0
    },
    "tests": []
  }
  
  for result in results:
    jsonReport["tests"].add(%*{
      "name": result.name,
      "passed": result.passed,
      "duration": result.duration
    })
  
  writeFile(reportDir / "results.json", jsonReport.pretty())
  
  # Generate markdown report
  var mdReport = "# Test Results\n\n"
  mdReport &= "**Date**: " & $now() & "\n"
  mdReport &= "**Duration**: " & formatFloat(summary.duration, ffDecimal, 2) & "s\n\n"
  mdReport &= "## Summary\n\n"
  mdReport &= "| Metric | Count |\n"
  mdReport &= "|--------|-------|\n"
  mdReport &= "| Total | " & $summary.total & " |\n"
  mdReport &= "| Passed | " & $summary.passed & " |\n"
  mdReport &= "| Failed | " & $summary.failed & " |\n"
  mdReport &= "| Skipped | " & $summary.skipped & " |\n"
  
  if summary.failures.len > 0:
    mdReport &= "\n## Failed Tests\n\n"
    for failure in summary.failures:
      mdReport &= "- " & failure & "\n"
  
  writeFile(reportDir / "results.md", mdReport)

proc printSummary(summary: TestSummary) =
  echo "\n", colored("=" * 60, fgBlue)
  echo colored("Test Summary", fgWhite)
  echo colored("=" * 60, fgBlue)
  
  echo "Total:   ", colored($summary.total, fgWhite)
  echo "Passed:  ", colored($summary.passed, fgGreen)
  echo "Failed:  ", colored($summary.failed, fgRed)
  echo "Skipped: ", colored($summary.skipped, fgYellow)
  echo "Duration: ", colored(formatFloat(summary.duration, ffDecimal, 2) & "s", fgCyan)
  
  if summary.failed == 0:
    echo "\n", colored("All tests passed! ✨", fgGreen)
  else:
    echo "\n", colored("Some tests failed! ❌", fgRed)
    echo "\nFailed tests:"
    for failure in summary.failures:
      echo "  - ", colored(failure, fgRed)

proc main() =
  echo colored("Running nim-testkit comprehensive test suite...\n", fgCyan)
  
  let testDir = getCurrentDir()
  if not dirExists("build"):
    createDir("build")
  
  let tests = discoverTests(testDir)
  if tests.len == 0:
    echo colored("No tests found!", fgYellow)
    quit(1)
  
  echo "Found ", colored($tests.len, fgWhite), " test files\n"
  
  var results: seq[TestResult]
  var summary = TestSummary()
  let startTime = epochTime()
  
  for testFile in tests:
    let result = runTest(testFile)
    results.add(result)
    
    inc(summary.total)
    if result.passed:
      inc(summary.passed)
    else:
      inc(summary.failed)
      summary.failures.add(result.name)
  
  summary.duration = epochTime() - startTime
  
  printSummary(summary)
  generateReport(summary, results)
  
  echo "\nTest report generated in: ", colored("build/test-results/", fgCyan)
  
  # Exit with appropriate code
  if summary.failed > 0:
    quit(1)
  else:
    quit(0)

when isMainModule:
  main()