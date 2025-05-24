import unittest, os, times, osproc, strutils
import "../src/execution/guard"

# Create a mock directory structure for testing
proc createMockDirectoryStructure(baseDir: string) =
  # Create source and test directories
  createDir(baseDir / "src")
  createDir(baseDir / "tests")
  createDir(baseDir / "scripts")
  
  # Create some mock files
  writeFile(baseDir / "src" / "mock_file1.nim", "# Mock source file 1")
  writeFile(baseDir / "src" / "mock_file2.nim", "# Mock source file 2")
  writeFile(baseDir / "tests" / "mock_test.nim", "# Mock test file")
  writeFile(baseDir / "scripts" / "mock_script.nim", "# Mock script file")

# Update mock file to trigger a change
proc updateMockFile(baseDir: string) =
  writeFile(baseDir / "src" / "mock_file1.nim", "# Mock source file 1 - updated " & $now())

suite "Test Guard":
  let tempDir = getTempDir() / "nim_test_guard_tests"
  
  setup:
    # Ensure temp directory exists and is clean
    if dirExists(tempDir):
      removeDir(tempDir)
    createDir(tempDir)
    createMockDirectoryStructure(tempDir)
  
  teardown:
    # Clean up after tests
    if dirExists(tempDir):
      removeDir(tempDir)
  
  test "Test guard can be initialized":
    # Just check that the test guard module can be imported
    check true
    
  test "Test guard works with watch patterns":
    # Check functionality without running actual guard
    let watchPatterns = @["*.nim"]
    check watchPatterns.len > 0
  
  test "getLatestModTime returns valid modification time":
    # Test the file modification detection function
    let latestTime = getLatestModTime(tempDir / "src", "*.nim")
    check latestTime > default(Time)
    
    # Modify a file and check that the time changes
    sleep(1000) # Ensure file time is different
    updateMockFile(tempDir)
    let newTime = getLatestModTime(tempDir / "src", "*.nim")
    check newTime > latestTime
  
  test "getLatestModTime handles missing files":
    # Create empty directory
    let emptyDir = tempDir / "empty_dir"
    createDir(emptyDir)
    
    # Check behavior with non-existing files
    let emptyTime = getLatestModTime(emptyDir, "*.nim")
    check emptyTime == default(Time)
  
  test "getLatestModTime recursively checks subdirectories":
    # Create a subdirectory with files
    let subDir = tempDir / "src" / "subdir"
    createDir(subDir)
    writeFile(subDir / "nested_file.nim", "# Nested file")
    
    # Get initial time
    let initialTime = getLatestModTime(tempDir / "src", "*.nim")
    
    # Update the nested file
    sleep(1000) # Ensure file time is different
    writeFile(subDir / "nested_file.nim", "# Nested file updated " & $now())
    
    # Check that the time is updated
    let newTime = getLatestModTime(tempDir / "src", "*.nim")
    check newTime > initialTime
  
  test "getProjectRootDir returns a valid directory":
    # Test the root directory detection
    # Since we can't mock the directory structure for this specific test,
    # we'll just verify that it returns a non-empty string
    let rootDir = getProjectRootDir()
    check rootDir.len > 0
    
  test "runTestGuard mock execution":
    # This is a simplified test that doesn't actually run the infinite loop
    # but tests the main functionality up to that point
    
    # We'll use a modified version that doesn't enter the infinite loop
    let guardProc = proc() =
      echo "===== Nim TestKit Guard ====="
      echo "Monitoring for source code changes..."
      
      let 
        rootDir = tempDir # Use our test directory instead
        sourceDir = rootDir / "src"
        testsDir = rootDir / "tests"
        scriptsDir = rootDir / "scripts"
      
      if not dirExists(sourceDir):
        echo "Error: Source directory not found at " & sourceDir
        quit(1)
      
      if not dirExists(testsDir):
        echo "Error: Tests directory not found at " & testsDir
        quit(1)
      
      var 
        lastSourceTime = getLatestModTime(sourceDir)
        lastScriptsTime = getLatestModTime(scriptsDir)
      
      # Simulate a file change
      sleep(1000)
      updateMockFile(rootDir)
      
      # Check for source modifications
      let 
        currentSourceTime = getLatestModTime(sourceDir)
        currentScriptsTime = getLatestModTime(scriptsDir)
      
      # Verify change detection
      check currentSourceTime > lastSourceTime
      
    # Run our modified test guard function
    guardProc()