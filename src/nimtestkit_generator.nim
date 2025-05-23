## Nim TestKit Generator Tool
##
## テスト生成を行うスタンドアロンツール

import std/[os, strutils, strformat, parseopt, json, tables]

type
  GeneratorOptions = object
    configPath: string
    modulePattern: string
    force: bool
    verbose: bool

proc parseOptions(): GeneratorOptions =
  result.modulePattern = "*.nim"
  result.force = false
  result.verbose = false
  
  var parser = initOptParser()
  for kind, key, val in parser.getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "config", "c":
        result.configPath = val
      of "pattern", "p":
        result.modulePattern = val
      of "force", "f":
        result.force = true
      of "verbose", "v":
        result.verbose = true
    of cmdArgument:
      if result.modulePattern == "*.nim":
        result.modulePattern = key
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
  
  if not result.hasKey("patterns"):
    result["patterns"] = newJObject()
  
  let patterns = result["patterns"]
  if not patterns.hasKey("include"):
    patterns["include"] = %"*.nim"
  if not patterns.hasKey("exclude"):
    patterns["exclude"] = %"test_*.nim"
  if not patterns.hasKey("test_name"):
    patterns["test_name"] = %"test_${module}.nim"

proc main() =
  # オプションの解析
  let opts = parseOptions()
  
  # 設定の読み込み
  let config = loadConfiguration(opts.configPath)
  let sourceDir = config["directories"]["source"].getStr("src")
  let testsDir = config["directories"]["tests"].getStr("tests")
  let testPattern = config["patterns"]["test_name"].getStr("test_${module}.nim")
  
  echo "Generating tests:"
  echo fmt" - Source directory: {sourceDir}"
  echo fmt" - Tests directory: {testsDir}"
  echo fmt" - Module pattern: {opts.modulePattern}"
  
  # テストディレクトリが存在しなければ作成
  if not dirExists(testsDir):
    createDir(testsDir)
    echo fmt"Created test directory: {testsDir}"
  
  # テスト未作成のモジュールを検索
  var moduleCount = 0
  var generatedCount = 0
  
  for sourceFile in walkFiles(sourceDir / opts.modulePattern):
    let moduleFile = extractFilename(sourceFile)
    let moduleName = moduleFile.splitFile.name
    
    # テストファイル名を生成
    let testFileName = testPattern.replace("${module}", moduleName)
    let testFilePath = testsDir / testFileName
    
    moduleCount += 1
    
    # テストファイルが存在しない、もしくは強制生成オプションがあれば生成
    if not fileExists(testFilePath) or opts.force:
      # ベーシックなテストテンプレートを生成
      let testTemplate = fmt"""import unittest
import "../{sourceDir}/{moduleFile}"

suite "{moduleName} tests":
  test "{moduleName} can be imported":
    # Basic import test
    check true
    
  # TODO: Add more tests here
"""
      
      writeFile(testFilePath, testTemplate)
      generatedCount += 1
      
      echo fmt"Generated test file: {testFilePath}"
  
  echo fmt"Generation complete: {generatedCount} test files generated from {moduleCount} modules"

when isMainModule:
  main()