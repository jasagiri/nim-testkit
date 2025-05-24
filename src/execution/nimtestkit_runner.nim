## Nim TestKit Runner Tool
##
## テスト実行を行うスタンドアロンツール

import std/[os, osproc, strutils, strformat, parseopt, json, tables]

type
  RunnerOptions = object
    configPath: string
    pattern: string
    verbose: bool
    failFast: bool

proc parseOptions(): RunnerOptions =
  result.pattern = "test_*.nim"
  result.verbose = false
  result.failFast = false
  
  var parser = initOptParser()
  for kind, key, val in parser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "config", "c":
        result.configPath = val
      of "pattern", "p":
        result.pattern = val
      of "verbose", "v":
        result.verbose = true
      of "fail-fast", "f":
        result.failFast = true
    of cmdArgument:
      if result.pattern == "test_*.nim":
        result.pattern = key
    of cmdEnd:
      discard

proc loadConfiguration(configPath: string): JsonNode =
  if configPath.len > 0 and fileExists(configPath):
    try:
      let content = readFile(configPath)
      result = parseJson(content)
    except:
      echo "Warning: Failed to parse config file: " & configPath
      result = newJObject()
  else:
    result = newJObject()
  
  # デフォルト値を設定
  if not result.hasKey("directories"):
    result["directories"] = newJObject()
  
  let dirs = result["directories"]
  if not dirs.hasKey("source"):
    dirs["source"] = %"src"
  if not dirs.hasKey("tests"):
    dirs["tests"] = %"tests"

proc main() =
  # コマンドライン引数を解析
  let opts = parseOptions()
  
  # 設定を読み込み
  let config = loadConfiguration(opts.configPath)
  let testsDir = config["directories"]["tests"].getStr("tests")
  
  echo "Running tests in directory: " & testsDir
  echo "Pattern: " & opts.pattern
  
  # テストを実行
  var exitCode = 0
  var testFiles: seq[string] = @[]
  
  for file in walkFiles(testsDir / opts.pattern):
    testFiles.add(file)
  
  echo fmt"Found {testFiles.len} test files"
  
  var passedTests = 0
  var failedTests = 0
  
  for testFile in testFiles:
    let relPath = relativePath(testFile, getCurrentDir())
    echo fmt"Running test: {relPath}"
    
    let status = execShellCmd(fmt"nim c -r {relPath}")
    if status == 0:
      passedTests += 1
      if opts.verbose:
        echo "✓ Test passed: " & relPath
    else:
      failedTests += 1
      echo "✗ Test failed: " & relPath
      if opts.failFast:
        echo "Stopping due to --fail-fast option"
        exitCode = status
        break
    
    if status != 0 and exitCode == 0:
      exitCode = status
  
  echo "Test results:"
  echo fmt" - Passed: {passedTests}"
  echo fmt" - Failed: {failedTests}"
  echo fmt" - Total:  {testFiles.len}"
  
  quit(exitCode)

when isMainModule:
  main()