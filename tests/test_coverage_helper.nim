import unittest, os
import ../src/analysis/coverage
import ../src/config/config

suite "Coverage Helper Tests":
  test "Coverage helper imports correctly":
    # Just test that the module can be imported
    check true
    
  test "getProjectRootDir returns a valid directory":
    let rootDir = getProjectRootDir()
    check rootDir.len > 0
    check dirExists(rootDir)
    # Either we're in project root or we should have the nimble file
    check fileExists(rootDir / "nimtestkit.nimble")
    
  test "generateCoverage can be called":
    # This ensures the generateCoverage function is accessible
    check compiles(generateCoverage())
    
  test "TestKitConfig defaults to reasonable values":
    let config = loadConfig() 
    check config.sourceDir == "src"
    check config.testsDir == "tests"
    check config.coverageThreshold == 80.0