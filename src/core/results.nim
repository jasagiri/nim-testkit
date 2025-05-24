# Test result handling for nim-testkit
# Zero external dependencies - uses only Nim stdlib

import std/[times, strformat, strutils]
import ./types

type
  ResultCollector* = object
    results: seq[TestResult]
    currentSuite: string
    startTime: float
    verbose: bool

proc initResultCollector*(verbose: bool = false): ResultCollector =
  ResultCollector(
    results: @[],
    currentSuite: "",
    startTime: epochTime(),
    verbose: verbose
  )

proc setCurrentSuite*(collector: var ResultCollector, suite: string) =
  collector.currentSuite = suite

proc addResult*(collector: var ResultCollector, result: TestResult) =
  collector.results.add(result)
  if collector.verbose:
    let statusSymbol = case result.status
      of tsPassed: "✓"
      of tsFailed: "✗"
      of tsError: "!"
      of tsSkipped: "⊘"
      else: "?"
    
    echo fmt"{statusSymbol} {result.name}"
    if result.message.len > 0:
      echo "  ", result.message
    if result.stackTrace.len > 0:
      echo "  Stack trace:"
      for line in result.stackTrace.splitLines():
        if line.len > 0:
          echo "    ", line

proc startTest*(collector: var ResultCollector, name: string, 
                category: TestCategory = tcUnit): TestResult =
  result = initTestResult(name, category)
  result.startTime = epochTime()
  result.status = tsRunning

proc endTest*(collector: var ResultCollector, result: var TestResult) =
  result.endTime = epochTime()
  result.duration = result.endTime - result.startTime
  collector.addResult(result)

proc passTest*(collector: var ResultCollector, result: var TestResult, 
               message: string = "") =
  result.status = tsPassed
  result.message = message
  collector.endTest(result)

proc failTest*(collector: var ResultCollector, result: var TestResult, 
               message: string, stackTrace: string = "") =
  result.status = tsFailed
  result.message = message
  result.stackTrace = stackTrace
  collector.endTest(result)

proc errorTest*(collector: var ResultCollector, result: var TestResult, 
                message: string, stackTrace: string = "") =
  result.status = tsError
  result.message = message
  result.stackTrace = stackTrace
  collector.endTest(result)

proc skipTest*(collector: var ResultCollector, result: var TestResult, 
               reason: string = "") =
  result.status = tsSkipped
  result.message = if reason.len > 0: fmt"Skipped: {reason}" else: "Skipped"
  collector.endTest(result)

proc generateReport*(collector: ResultCollector): TestReport =
  result = initTestReport()
  result.results = collector.results
  result.totalTests = collector.results.len
  result.startTime = collector.startTime
  result.endTime = epochTime()
  result.duration = result.endTime - result.startTime
  
  for r in collector.results:
    case r.status
    of tsPassed: inc result.passed
    of tsFailed: inc result.failed
    of tsSkipped: inc result.skipped
    of tsError: inc result.errors
    else: discard

proc formatDuration*(seconds: float): string =
  if seconds < 0.001:
    result = fmt"{seconds * 1000000:.0f}μs"
  elif seconds < 1.0:
    result = fmt"{seconds * 1000:.1f}ms"
  else:
    result = fmt"{seconds:.2f}s"

proc printSummary*(report: TestReport) =
  echo "\n" & "=".repeat(60)
  echo "Test Summary"
  echo "=".repeat(60)
  echo fmt"Total:   {report.totalTests} tests"
  echo fmt"Passed:  {report.passed} ({report.passed / report.totalTests * 100:.1f}%)"
  echo fmt"Failed:  {report.failed}"
  echo fmt"Errors:  {report.errors}"
  echo fmt"Skipped: {report.skipped}"
  echo fmt"Time:    {formatDuration(report.duration)}"
  echo "=".repeat(60)
  
  if report.failed > 0 or report.errors > 0:
    echo "\nFailed Tests:"
    for result in report.results:
      if result.status in [tsFailed, tsError]:
        echo fmt"\n• {result.name}"
        echo fmt"  Status: {result.status}"
        echo fmt"  {result.message}"
        if result.file.len > 0:
          echo fmt"  Location: {result.file}:{result.line}"

proc toJson*(report: TestReport): string =
  # Simple JSON serialization without external deps
  result = "{\n"
  result.add fmt"""  "totalTests": {report.totalTests},""" & "\n"
  result.add fmt"""  "passed": {report.passed},""" & "\n"
  result.add fmt"""  "failed": {report.failed},""" & "\n"
  result.add fmt"""  "errors": {report.errors},""" & "\n"
  result.add fmt"""  "skipped": {report.skipped},""" & "\n"
  result.add fmt"""  "duration": {report.duration},""" & "\n"
  result.add """  "results": [""" & "\n"
  
  for i, r in report.results:
    result.add "    {\n"
    result.add fmt"""      "name": "{r.name.escape}",""" & "\n"
    result.add fmt"""      "category": "{r.category}",""" & "\n"
    result.add fmt"""      "status": "{r.status}",""" & "\n"
    result.add fmt"""      "duration": {r.duration},""" & "\n"
    result.add fmt"""      "message": "{r.message.escape}"""
    if r.file.len > 0:
      result.add ",\n"
      result.add fmt"""      "file": "{r.file.escape}",""" & "\n"
      result.add fmt"""      "line": {r.line}"""
    result.add "\n    }"
    if i < report.results.len - 1:
      result.add ","
    result.add "\n"
  
  result.add "  ]\n"
  result.add "}"

proc toTap*(report: TestReport): string =
  # Test Anything Protocol format
  result = fmt"TAP version 13" & "\n"
  result.add fmt"1..{report.totalTests}" & "\n"
  
  for i, r in report.results:
    let num = i + 1
    case r.status
    of tsPassed:
      result.add fmt"ok {num} - {r.name}" & "\n"
    of tsFailed, tsError:
      result.add fmt"not ok {num} - {r.name}" & "\n"
      if r.message.len > 0:
        result.add fmt"  ---" & "\n"
        result.add fmt"  message: {r.message}" & "\n"
        if r.file.len > 0:
          result.add fmt"  file: {r.file}" & "\n"
          result.add fmt"  line: {r.line}" & "\n"
        result.add fmt"  ..." & "\n"
    of tsSkipped:
      result.add fmt"ok {num} - {r.name} # SKIP {r.message}" & "\n"
    else:
      result.add fmt"not ok {num} - {r.name} # TODO" & "\n"

proc saveReport*(report: TestReport, filename: string, format: OutputFormat) =
  let content = case format
    of ofJson: report.toJson()
    of ofTap: report.toTap()
    else: "" # Other formats not implemented yet
  
  if content.len > 0:
    writeFile(filename, content)