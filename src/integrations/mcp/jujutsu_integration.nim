## MCP-Jujutsu Integration for Nim TestKit
##
## Provides advanced Jujutsu integration using MCP-Jujutsu server
## for test optimization and best practices support.

import std/[os, osproc, strformat, strutils, json, tables, times, sequtils, hashes]
import ../../config/config

type
  MCPJujutsuClient* = object
    # Placeholder for actual MCP client
    connected: bool

proc newMCPJujutsuClient*(): MCPJujutsuClient =
  ## Create a new MCP Jujutsu client
  result.connected = false
  # In real implementation, would connect to MCP server

proc status*(client: MCPJujutsuClient): JsonNode =
  ## Get status from Jujutsu
  # Fallback to command line
  let (output, exitCode) = execCmdEx("jj status")
  if exitCode == 0:
    result = %output
  else:
    result = %""

proc diff*(client: MCPJujutsuClient, fromRev, toRev: string): JsonNode =
  ## Get diff between revisions
  let cmd = fmt"jj diff -r {fromRev}..{toRev}"
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode == 0:
    result = %output
  else:
    result = %""

proc conflicts*(client: MCPJujutsuClient): JsonNode =
  ## Get current conflicts
  # Check for conflict markers in files
  result = %[]

type
  JujutsuTestStrategy* = object
    enabled*: bool
    changeBasedTesting*: bool
    conflictAwareTesting*: bool
    testCaching*: bool
    autoTestOnNew*: bool
    
  JujutsuTestContext* = object
    strategy*: JujutsuTestStrategy
    client*: MCPJujutsuClient
    currentChange*: string
    modifiedFiles*: seq[string]
    testCache*: Table[string, seq[TestCacheEntry]]
    
  TestCacheEntry* = object
    fileHash*: string
    testFile*: string
    passed*: bool
    duration*: float
    timestamp*: Time

proc initJujutsuIntegration*(config: TestKitConfig): JujutsuTestContext =
  ## Initialize Jujutsu integration if enabled
  result.strategy = JujutsuTestStrategy(
    enabled: config.vcs.jujutsu,  # Use VCS config instead of deprecated field
    changeBasedTesting: true,
    conflictAwareTesting: true,
    testCaching: true,
    autoTestOnNew: true
  )
  
  if not result.strategy.enabled:
    return
  
  # Initialize MCP-Jujutsu client
  try:
    result.client = newMCPJujutsuClient()
    
    # Get current change information
    let status = result.client.status()
    if status.kind == JString:
      # Parse status to get current change
      let lines = status.getStr().splitLines()
      for line in lines:
        if line.startsWith("Working copy changes"):
          result.currentChange = line.split(":")[1].strip()
          break
    
    # Get modified files
    let diff = result.client.diff("@", "@-")
    if diff.kind == JString:
      for line in diff.getStr().splitLines():
        if line.startsWith("+++") or line.startsWith("---"):
          let file = line.split(" ")[1]
          if file.endsWith(".nim") and file notin result.modifiedFiles:
            result.modifiedFiles.add(file)
            
  except Exception as e:
    echo fmt"Warning: Failed to initialize MCP-Jujutsu: {e.msg}"
    result.strategy.enabled = false

proc getTestFilesForChange*(ctx: JujutsuTestContext, allTestFiles: seq[string]): seq[string] =
  ## Get test files that should be run for the current change
  if not ctx.strategy.enabled or not ctx.strategy.changeBasedTesting:
    return allTestFiles
  
  result = @[]
  
  # Always include tests for modified source files
  for modFile in ctx.modifiedFiles:
    let baseName = modFile.extractFilename().changeFileExt("")
    for testFile in allTestFiles:
      if testFile.contains(baseName):
        result.add(testFile)
  
  # If no specific tests found, run all tests
  if result.len == 0:
    return allTestFiles
  
  # Remove duplicates
  result = result.deduplicate()

proc shouldSkipTest*(ctx: JujutsuTestContext, testFile: string): bool =
  ## Check if a test can be skipped based on cache
  if not ctx.strategy.enabled or not ctx.strategy.testCaching:
    return false
  
  # Check if file has been modified
  if testFile in ctx.modifiedFiles:
    return false
  
  # Check cache for this change
  if ctx.currentChange in ctx.testCache:
    let cacheEntries = ctx.testCache[ctx.currentChange]
    for entry in cacheEntries:
      if entry.testFile == testFile:
        # Check if test file hasn't changed
        if fileExists(testFile):
          let content = readFile(testFile)
          var h: Hash = 0
          h = h !& hash(content)
          let currentHash = $(!$h)
          if currentHash == entry.fileHash and entry.passed:
            echo fmt"Skipping {testFile} (cached result: PASS)"
            return true
  
  return false

proc cacheTestResult*(ctx: var JujutsuTestContext, testFile: string, passed: bool, duration: float) =
  ## Cache test result for the current change
  if not ctx.strategy.enabled or not ctx.strategy.testCaching:
    return
  
  let fileHash = if fileExists(testFile):
    let content = readFile(testFile)
    var h: Hash = 0
    h = h !& hash(content)
    $(!$h)
  else:
    ""
  
  let entry = TestCacheEntry(
    fileHash: fileHash,
    testFile: testFile,
    passed: passed,
    duration: duration,
    timestamp: getTime()
  )
  
  if ctx.currentChange notin ctx.testCache:
    ctx.testCache[ctx.currentChange] = @[]
  
  ctx.testCache[ctx.currentChange].add(entry)

proc handleConflicts*(ctx: JujutsuTestContext): seq[string] =
  ## Get test recommendations for conflict resolution
  if not ctx.strategy.enabled or not ctx.strategy.conflictAwareTesting:
    return @[]
  
  result = @[]
  
  try:
    # Check for conflicts
    let conflicts = ctx.client.conflicts()
    if conflicts.kind == JArray and conflicts.len > 0:
      result.add("⚠️  Conflicts detected! Run these tests after resolution:")
      
      for conflict in conflicts:
        if conflict.kind == JObject and conflict.hasKey("path"):
          let path = conflict["path"].getStr()
          result.add(fmt"  - Tests for: {path}")
  except:
    discard

proc createChangeTestReport*(ctx: JujutsuTestContext, results: seq[tuple[file: string, passed: bool]]): string =
  ## Create a test report for the current change
  if not ctx.strategy.enabled:
    return ""
  
  result = fmt"""
Test Report for Change: {ctx.currentChange}
Modified Files: {ctx.modifiedFiles.len}
Tests Run: {results.len}
Passed: {results.filterIt(it.passed).len}
Failed: {results.filterIt(not it.passed).len}
"""

proc setupJujutsuHooks*(ctx: JujutsuTestContext) =
  ## Setup Jujutsu hooks for automatic testing
  if not ctx.strategy.enabled or not ctx.strategy.autoTestOnNew:
    return
  
  # Create hook script
  let hookScript = """#!/bin/sh
# Auto-run tests on jj new
if [ "$1" = "new" ]; then
  echo "Running tests for new change..."
  nimble test
fi
"""
  
  let hooksDir = ".jj/hooks"
  if not dirExists(hooksDir):
    createDir(hooksDir)
  
  let hookPath = hooksDir / "post-new"
  writeFile(hookPath, hookScript)
  when not defined(windows):
    discard execCmd(fmt"chmod +x {hookPath}")

proc getJujutsuBestPractices*(): seq[string] =
  ## Get Jujutsu-specific best practices for testing
  result = @[
    "📝 Jujutsu Best Practices for Testing:",
    "1. Run tests before 'jj new' to ensure clean changes",
    "2. Use 'jj split' to separate test additions from code changes",
    "3. Leverage 'jj describe' to document test coverage in commit messages",
    "4. Use 'jj workspace' for testing different configurations",
    "5. Run tests after conflict resolution with 'jj resolve'",
    "6. Use change-based test caching to speed up development",
    "7. Tag releases only after all tests pass"
  ]