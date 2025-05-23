## Nim TestKit Test Integration for Jujutsu
##
## Provides test-specific integration with Jujutsu version control system.
## This module handles test optimization, caching, and conflict testing
## for Jujutsu repositories.

import std/[os, osproc, strformat, strutils, json, tables, times, sets, sequtils]
import checksums/md5

type
  JujutsuInfo* = object
    isJjRepo*: bool
    currentChange*: string
    modifiedFiles*: seq[string]
    conflictedFiles*: seq[string]
    operationLog*: seq[string]
    workspaces*: seq[string]
    
  TestCache* = object
    changeId*: string
    contentHash*: string
    results*: seq[tuple[file: string, passed: bool]]
    timestamp*: Time
    
  TestHistoryResult* = object
    name*: string
    file*: string
    passed*: bool
    
  TestHistory* = object
    changeId*: string
    parentChanges*: seq[string]
    results*: seq[TestHistoryResult]
    coverage*: float
    timestamp*: Time

proc checkJujutsuRepo*(): bool =
  ## Checks if current directory is a Jujutsu repository
  let (output, exitCode) = execCmdEx("jj status")
  return exitCode == 0

proc getJujutsuInfo*(): JujutsuInfo =
  ## Gets information about the current Jujutsu repository state
  result.isJjRepo = checkJujutsuRepo()
  
  if not result.isJjRepo:
    return
  
  # Get current change ID
  let (changeOutput, changeCode) = execCmdEx("""jj log -r @ --no-graph --template 'change_id ++ "\n"'""")
  if changeCode == 0:
    result.currentChange = changeOutput.strip()
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("jj status")
  if statusCode == 0:
    for line in statusOutput.splitLines():
      if line.startsWith("M ") or line.startsWith("A ") or line.startsWith("R "):
        result.modifiedFiles.add(line[2..^1].strip())
      elif line.startsWith("C "):
        result.conflictedFiles.add(line[2..^1].strip())

proc getFilesInChange*(changeId = "@"): seq[string] =
  ## Gets list of files modified in a specific change
  let cmd = fmt"jj diff -r {changeId} --name-only"
  let (output, exitCode) = execCmdEx(cmd)
  
  if exitCode == 0:
    for line in output.splitLines():
      if line.strip() != "":
        result.add(line.strip())

proc getContentHash*(files: seq[string]): string =
  ## Calculates a hash of file contents for cache invalidation
  var combinedContent = ""
  
  for file in files:
    if fileExists(file):
      combinedContent &= readFile(file)
  
  return getMD5(combinedContent)

proc loadTestCache*(cacheFile = ".nimtestkit/cache.json"): TestCache =
  ## Loads test cache from disk
  if not fileExists(cacheFile):
    return TestCache()
  
  try:
    let jsonContent = readFile(cacheFile)
    let jsonNode = parseJson(jsonContent)
    
    result.changeId = jsonNode["changeId"].getStr()
    result.contentHash = jsonNode["contentHash"].getStr()
    result.timestamp = fromUnix(jsonNode["timestamp"].getInt())
    
    for test in jsonNode["results"]:
      result.results.add((
        file: test["file"].getStr(),
        passed: test["passed"].getBool()
      ))
  except:
    # Return empty cache if parsing fails
    return TestCache()

proc saveTestCache*(cache: TestCache, cacheFile = ".nimtestkit/cache.json") =
  ## Saves test cache to disk
  createDir(parentDir(cacheFile))
  
  var jsonNode = %* {
    "changeId": cache.changeId,
    "contentHash": cache.contentHash,
    "timestamp": cache.timestamp.toUnix(),
    "results": newJArray()
  }
  
  for test in cache.results:
    jsonNode["results"].add(%* {
      "file": test.file,
      "passed": test.passed
    })
  
  writeFile(cacheFile, $jsonNode)

proc shouldRunTests*(jjInfo: JujutsuInfo, cache: TestCache): bool =
  ## Determines if tests should be run based on change state
  if not jjInfo.isJjRepo:
    return true  # Always run if not in jj repo
  
  # Always run if there are conflicts
  if jjInfo.conflictedFiles.len > 0:
    return true
  
  # Check if change ID is different
  if cache.changeId != jjInfo.currentChange:
    return true
  
  # Check if content has changed
  let currentHash = getContentHash(jjInfo.modifiedFiles)
  if currentHash != cache.contentHash:
    return true
  
  # Check if cache is too old (> 1 hour)
  let currentTime = now().toTime()
  if (currentTime - cache.timestamp).inHours > 1:
    return true
  
  return false

proc filterTestsByChange*(testFiles: seq[string], jjInfo: JujutsuInfo): seq[string] =
  ## Filters test files to only those affected by current changes
  if not jjInfo.isJjRepo or jjInfo.modifiedFiles.len == 0:
    return testFiles
  
  result = @[]
  
  # Map source files to test files
  for modifiedFile in jjInfo.modifiedFiles:
    if modifiedFile.endsWith(".nim"):
      let baseName = modifiedFile.extractFilename().replace(".nim", "")
      
      for testFile in testFiles:
        if testFile.contains(baseName):
          result.add(testFile)
  
  # Always include tests that are directly modified
  for testFile in testFiles:
    if testFile in jjInfo.modifiedFiles:
      result.add(testFile)
  
  # Remove duplicates
  result = toSeq(result.toHashSet())

proc getOperationLog*(): seq[string] =
  ## Gets the operation log from jujutsu
  let (output, exitCode) = execCmdEx("jj op log --no-graph")
  if exitCode == 0:
    for line in output.splitLines():
      if line.strip() != "":
        result.add(line.strip())

proc getWorkspaces*(): seq[string] =
  ## Gets list of workspaces
  let (output, exitCode) = execCmdEx("jj workspace list")
  if exitCode == 0:
    for line in output.splitLines():
      if line.strip() != "":
        result.add(line.strip())

proc saveTestHistory*(history: TestHistory, historyDir = ".nimtestkit/history") =
  ## Saves test history for a change
  createDir(historyDir)
  
  let fileName = history.changeId & ".json"
  let filePath = historyDir / fileName
  
  var jsonNode = %* {
    "changeId": history.changeId,
    "parentChanges": history.parentChanges,
    "coverage": history.coverage,
    "timestamp": history.timestamp.toUnix(),
    "results": newJArray()
  }
  
  for result in history.results:
    jsonNode["results"].add(%* {
      "name": result.name,
      "file": result.file,
      "passed": result.passed
    })
  
  writeFile(filePath, $jsonNode)

proc loadTestHistory*(changeId: string, historyDir = ".nimtestkit/history"): TestHistory =
  ## Loads test history for a change
  let fileName = changeId & ".json"
  let filePath = historyDir / fileName
  
  if not fileExists(filePath):
    return TestHistory(changeId: changeId)
  
  try:
    let jsonContent = readFile(filePath)
    let jsonNode = parseJson(jsonContent)
    
    result.changeId = jsonNode["changeId"].getStr()
    result.coverage = jsonNode["coverage"].getFloat()
    result.timestamp = fromUnix(jsonNode["timestamp"].getInt())
    
    for parent in jsonNode["parentChanges"]:
      result.parentChanges.add(parent.getStr())
    
    # Simplified loading - would need full TestResult type
    result.results = @[]
  except:
    return TestHistory(changeId: changeId)

proc trackTestEvolution*(currentChange: string): seq[TestHistory] =
  ## Tracks test evolution across change history
  result = @[]
  
  # Get parent changes
  let (parentOutput, exitCode) = execCmdEx(fmt"""jj log -r {currentChange}^..{currentChange} --template 'change_id ++ "\n"'""")
  
  if exitCode == 0:
    for line in parentOutput.splitLines():
      let parentId = line.strip()
      if parentId != "":
        let history = loadTestHistory(parentId)
        if history.changeId != "":
          result.add(history)

proc getSnapshotInfo*(): tuple[hash: string, modTime: Time] =
  ## Gets working copy snapshot information
  let (hashOutput, _) = execCmdEx("jj log -r @ --no-graph --template 'commit_id'")
  result.hash = hashOutput.strip()
  
  # Get modification time of .jj/working_copy directory
  if dirExists(".jj/working_copy"):
    result.modTime = getLastModificationTime(".jj/working_copy")
  else:
    result.modTime = now().toTime()

proc optimizeTestRuns*(testFiles: seq[string], lastSnapshot: string): seq[string] =
  ## Optimizes test runs based on snapshot changes
  let currentSnapshot = getSnapshotInfo().hash
  
  if currentSnapshot == lastSnapshot:
    # No changes in working copy, run minimal tests
    return @[]
  
  # Get changed files since last snapshot
  let (diffOutput, _) = execCmdEx(fmt"jj diff -r {lastSnapshot}..@ --name-only")
  var changedFiles: HashSet[string]
  
  for line in diffOutput.splitLines():
    if line.strip() != "":
      changedFiles.incl(line.strip())
  
  # Filter tests based on changed files
  result = @[]
  for testFile in testFiles:
    # Check if test file is related to any changed file
    let baseName = testFile.extractFilename().replace("_test.nim", "")
    for changed in changedFiles:
      if changed.contains(baseName):
        result.add(testFile)
        break

proc setupWorkspaceTests*(workspace: string) =
  ## Sets up tests for a specific workspace
  let (output, exitCode) = execCmdEx(fmt"jj workspace set {workspace}")
  
  if exitCode == 0:
    echo fmt"Switched to workspace: {workspace}"
    
    # Load workspace-specific configuration
    let workspaceConfig = fmt".jj/workspaces/{workspace}/nimtestkit.toml"
    if fileExists(workspaceConfig):
      echo fmt"Loading workspace config: {workspaceConfig}"

proc setupJujutsuHooks*() =
  ## Sets up Jujutsu hooks for automatic testing
  let hookScript = """#!/bin/sh
# Nim TestKit pre-commit hook for Jujutsu

# Run tests before allowing changes
nimble test

# Exit with the test result
exit $?
"""
  
  let hooksDir = ".jj/hooks"
  createDir(hooksDir)
  
  let hookFile = hooksDir / "pre-commit"
  writeFile(hookFile, hookScript)
  
  # Make executable on Unix
  when not defined(windows):
    discard execCmd(fmt"chmod +x {hookFile}")
  
  echo "Jujutsu hooks installed successfully"

proc generateConflictTests*(conflictedFiles: seq[string]): string =
  ## Generates test cases for conflict resolution verification
  result = """
suite "Conflict Resolution Tests":
"""
  
  for file in conflictedFiles:
    let testName = file.extractFilename().replace(".nim", "")
    result &= fmt"""
  test "Conflict resolved in {testName}":
    # Verify no conflict markers remain
    let content = readFile("{file}")
    check not content.contains("<<<<<<< ")
    check not content.contains("======= ")
    check not content.contains(">>>>>>> ")
    
    # Verify file compiles after resolution
    let (output, exitCode) = execCmdEx("nim c {file}")
    check exitCode == 0
"""