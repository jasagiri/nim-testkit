import std/[unittest, os, tempfiles, strutils, sequtils, times, tables]
import ../src/refactoring/helper

suite "RefactorHelper - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("refactor_test_", "")
    let projectDir = tempDir / "test_project"
    createDir(projectDir)
    createDir(projectDir / "src")
    createDir(projectDir / "tests")
    createDir(projectDir / "build")
    
  teardown:
    removeDir(tempDir)
    
  test "RefactorHelper initialization":
    let rh = newRefactorHelper(projectDir)
    
    check rh.projectRoot == projectDir
    check not rh.config.dryRun
    check not rh.config.verbose
    check rh.config.backupDir == projectDir / ".refactor-backup"
    check rh.config.autoFixImports
    check rh.config.preserveHistory
    
  test "File analysis and hashing":
    let rh = newRefactorHelper(projectDir)
    
    let testFile = projectDir / "src" / "test.nim"
    writeFile(testFile, "echo \"Hello\"")
    
    let info = rh.analyzeFile(testFile)
    
    check info.path == testFile
    check info.size > 0
    check info.hash != ""
    
    # Check caching
    let info2 = rh.analyzeFile(testFile)
    check info2.hash == info.hash
    
  test "Find duplicate files":
    let rh = newRefactorHelper(projectDir)
    
    # Create duplicate files
    writeFile(projectDir / "src" / "file1.nim", "proc test() = echo 1")
    writeFile(projectDir / "src" / "file2.nim", "proc test() = echo 1")
    writeFile(projectDir / "src" / "file3.nim", "proc test() = echo 2")
    
    let duplicates = rh.findDuplicateFiles()
    
    check duplicates.len == 1  # One group of duplicates
    
    var found = false
    for hash, files in duplicates:
      if files.len == 2:
        check files[0].endsWith("file1.nim") or files[0].endsWith("file2.nim")
        check files[1].endsWith("file1.nim") or files[1].endsWith("file2.nim")
        found = true
    
    check found
    
  test "Find unused files":
    let rh = newRefactorHelper(projectDir)
    
    # Create files with imports
    writeFile(projectDir / "src" / "main.nim", """
import utils
echo "Main"
""")
    
    writeFile(projectDir / "src" / "utils.nim", """
proc helper*() = echo "Helper"
""")
    
    writeFile(projectDir / "src" / "unused.nim", """
proc notUsed*() = echo "Not used"
""")
    
    let unused = rh.findUnusedFiles()
    
    # unused.nim should be in the list
    check unused.anyIt("unused.nim" in it)
    # utils.nim should not be in the list (it's imported)
    check not unused.anyIt("utils.nim" in it)
    # main.nim should not be in the list (it's a main file)
    check not unused.anyIt("main.nim" in it)
    
  test "Find empty directories":
    let rh = newRefactorHelper(projectDir)
    
    # Create empty directories
    createDir(projectDir / "empty1")
    createDir(projectDir / "empty2")
    createDir(projectDir / "notempty")
    writeFile(projectDir / "notempty" / "file.txt", "content")
    
    let emptyDirs = rh.findEmptyDirectories()
    
    check emptyDirs.len >= 2
    check emptyDirs.anyIt("empty1" in it)
    check emptyDirs.anyIt("empty2" in it)
    check not emptyDirs.anyIt("notempty" in it)
    
  test "Clean build artifacts":
    let rh = newRefactorHelper(projectDir)
    
    # Create build artifacts
    createDir(projectDir / "nimcache")
    writeFile(projectDir / "nimcache" / "test.c", "// generated")
    writeFile(projectDir / "program.exe", "binary")
    writeFile(projectDir / "lib.so", "library")
    createDir(projectDir / "build" / "temp")
    writeFile(projectDir / "build" / "artifact.o", "object")
    
    # Test dry run first
    rh.config.dryRun = true
    let dryResult = rh.cleanBuildArtifacts()
    
    check dryResult.removed.len > 0
    check dryResult.bytesFreed == 0  # Dry run doesn't actually remove
    check fileExists(projectDir / "program.exe")  # Still exists
    
    # Test actual cleanup
    rh.config.dryRun = false
    let result = rh.cleanBuildArtifacts()
    
    check result.removed.len > 0
    check result.bytesFreed > 0
    check not fileExists(projectDir / "program.exe")
    check not dirExists(projectDir / "nimcache")
    
  test "Clean unused imports":
    let rh = newRefactorHelper(projectDir)
    
    let testFile = projectDir / "src" / "imports.nim"
    writeFile(testFile, """
import os
import strutils
import sequtils

echo "Only using echo"
""")
    
    let cleaned = rh.cleanUnusedImports(testFile)
    
    # In this simple test, imports might be considered unused
    check cleaned.len > 0
    check "echo" in cleaned
    
  test "Reorganize by type":
    let rh = newRefactorHelper(projectDir)
    
    # Create files in wrong locations
    writeFile(projectDir / "test_something.nim", "# test")
    writeFile(projectDir / "src" / "test_unit.nim", "# unit test")
    writeFile(projectDir / "readme.md", "# Docs")
    writeFile(projectDir / "src" / "config.json", "{}")
    
    let plan = rh.reorganizeByType()
    
    # Should suggest moves
    check plan.moves.len > 0
    
    # Test files should move to tests/
    check plan.moves.anyIt(it.src.endsWith("test_something.nim") and "/tests/" in it.dst)
    
    # Docs should move to docs/
    check plan.moves.anyIt(it.src.endsWith("readme.md") and "/docs/" in it.dst)
    
  test "Consolidate similar files":
    let rh = newRefactorHelper(projectDir)
    
    # Create similar files
    writeFile(projectDir / "src" / "utils.nim", "# utilities")
    writeFile(projectDir / "src" / "utils_helper.nim", "# utilities helper")
    writeFile(projectDir / "src" / "utils_common.nim", "# utilities common")
    
    let plan = rh.consolidateSimilarFiles(0.5)
    
    check plan.warnings.len > 0
    check plan.warnings.anyIt("Similar files" in it)
    
  test "Detect dead code":
    let rh = newRefactorHelper(projectDir)
    
    writeFile(projectDir / "src" / "deadcode.nim", """
proc usedFunc*() = echo "used"
proc unusedFunc*() = echo "never called"

usedFunc()
""")
    
    let deadCode = rh.detectDeadCode()
    
    # Should detect unusedFunc
    check deadCode.len > 0
    check deadCode.anyIt("unusedFunc" in it)
    
  test "Create backup":
    let rh = newRefactorHelper(projectDir)
    
    # Create files to backup
    let file1 = projectDir / "src" / "backup1.nim"
    let file2 = projectDir / "src" / "backup2.nim"
    writeFile(file1, "content1")
    writeFile(file2, "content2")
    
    rh.createBackup(@[file1, file2])
    
    # Check backup exists
    check dirExists(rh.config.backupDir)
    
    # Find backup files
    var backupCount = 0
    for file in walkDirRec(rh.config.backupDir):
      if file.endsWith("backup1.nim") or file.endsWith("backup2.nim"):
        inc backupCount
    
    check backupCount == 2
    
  test "Execute refactor plan - dry run":
    let rh = newRefactorHelper(projectDir)
    rh.config.dryRun = true
    
    # Create test file
    let srcFile = projectDir / "src" / "tomove.nim"
    writeFile(srcFile, "# content")
    
    let plan = RefactorPlan(
      moves: @[(src: srcFile, dst: projectDir / "tests" / "tomove.nim")],
      deletes: @[],
      renames: @[],
      warnings: @[]
    )
    
    let results = rh.executeRefactorPlan(plan)
    
    check results.len > 0
    check results[0].startsWith("[DRY RUN]")
    check fileExists(srcFile)  # Still exists (dry run)
    
  test "Execute refactor plan - actual":
    let rh = newRefactorHelper(projectDir)
    rh.config.dryRun = false
    rh.config.preserveHistory = false  # Skip backup for test
    
    # Create files
    let srcFile = projectDir / "src" / "tomove.nim"
    let renameFile = projectDir / "src" / "torename.nim"
    let deleteFile = projectDir / "src" / "todelete.nim"
    
    createDir(projectDir / "tests")
    writeFile(srcFile, "# move me")
    writeFile(renameFile, "# rename me")
    writeFile(deleteFile, "# delete me")
    
    let plan = RefactorPlan(
      moves: @[(src: srcFile, dst: projectDir / "tests" / "tomove.nim")],
      renames: @[(old: renameFile, new: projectDir / "src" / "renamed.nim")],
      deletes: @[deleteFile],
      warnings: @[]
    )
    
    let results = rh.executeRefactorPlan(plan)
    
    check results.len >= 3
    check not fileExists(srcFile)
    check fileExists(projectDir / "tests" / "tomove.nim")
    check not fileExists(renameFile)
    check fileExists(projectDir / "src" / "renamed.nim")
    check not fileExists(deleteFile)
    
  test "Generate refactor report":
    let rh = newRefactorHelper(projectDir)
    
    # Create some test conditions
    writeFile(projectDir / "src" / "dup1.nim", "duplicate")
    writeFile(projectDir / "src" / "dup2.nim", "duplicate")
    createDir(projectDir / "empty")
    createDir(projectDir / "build")
    writeFile(projectDir / "build" / "artifact.o", "object")
    
    let report = rh.generateRefactorReport()
    
    check "# Refactoring Analysis Report" in report
    check "## Duplicate Files" in report
    check "## Potentially Unused Files" in report
    check "## Empty Directories" in report
    check "## Build Artifacts" in report
    check "## Recommended Actions" in report
    
  test "File pattern matching":
    let rh = newRefactorHelper(projectDir)
    
    # Test exclude patterns
    rh.config.excludePatterns = @[".git/", "vendor/"]
    
    createDir(projectDir / ".git")
    createDir(projectDir / "vendor")
    writeFile(projectDir / ".git" / "config", "git config")
    writeFile(projectDir / "vendor" / "lib.nim", "vendor lib")
    
    let emptyDirs = rh.findEmptyDirectories()
    
    # Should not include .git or vendor
    check not emptyDirs.anyIt(".git" in it)
    check not emptyDirs.anyIt("vendor" in it)
    
  test "RefactorConfig validation":
    let rh = newRefactorHelper(projectDir)
    
    # Test config modifications
    rh.config.dryRun = true
    rh.config.verbose = true
    rh.config.autoFixImports = false
    rh.config.preserveHistory = false
    
    check rh.config.dryRun
    check rh.config.verbose
    check not rh.config.autoFixImports
    check not rh.config.preserveHistory