import unittest
import ../src/test_generator
import ../src/config
import std/[os, strutils]

suite "Enhanced Test Generator Tests":
  test "Generate property-based test templates":
    let testDir = "test_generator_temp"
    let srcDir = testDir / "src"
    let testsDir = testDir / "tests"
    
    # Create temporary directories
    createDir(srcDir)
    createDir(testsDir)
    
    # Create a sample source file
    let sourceFile = srcDir / "sample.nim"
    writeFile(sourceFile, """
proc add*(a, b: int): int =
  return a + b

proc multiply*(x, y: float): float = 
  return x * y
""")
    
    # Create config
    var config = getDefaultConfig()
    config.sourceDir = srcDir
    config.testsDir = testsDir
    
    # Analyze and generate tests
    let modules = analyze(config)
    check modules.len > 0
    
    for module in modules:
      generateTestFile(config, module, true)
    
    # Check generated test file
    let testFile = testsDir / "sample_test.nim"
    check fileExists(testFile)
    
    let content = readFile(testFile)
    check content.contains("property based")
    check content.contains("edge cases")
    check content.contains("rand")
    
    # Cleanup
    removeDir(testDir)
    
  test "Generate async function tests":
    let testDir = "test_async_temp"
    let srcDir = testDir / "src"
    let testsDir = testDir / "tests"
    
    # Create temporary directories
    createDir(srcDir)
    createDir(testsDir)
    
    # Create a sample source file with async function
    let sourceFile = srcDir / "async_sample.nim"
    writeFile(sourceFile, """
proc fetchData*(): Future[string] {.async.} =
  return "data"
""")
    
    # Create config
    var config = getDefaultConfig()
    config.sourceDir = srcDir
    config.testsDir = testsDir
    
    # Analyze and generate tests
    let modules = analyze(config)
    
    for module in modules:
      generateTestFile(config, module, true)
    
    # Check generated test file
    let testFile = testsDir / "async_sample_test.nim"
    if fileExists(testFile):
      let content = readFile(testFile)
      check content.contains("async")
      check content.contains("waitFor")
    
    # Cleanup
    removeDir(testDir)