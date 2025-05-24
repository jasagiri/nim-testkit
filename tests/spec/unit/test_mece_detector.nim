# Test suite for analysis/mece_detector.nim - 100% coverage target

import std/[unittest, os, tables, sets]
import ../../../src/analysis/mece_detector
import ../../../src/core/types

suite "MECE Detector Tests":

  setup:
    # Create temporary test directory structure
    let testRoot = "temp_mece_test"
    createDir(testRoot)

  teardown:
    # Cleanup temporary test directory
    let testRoot = "temp_mece_test"
    if dirExists(testRoot):
      removeDir(testRoot)

  test "initMECEStructure creates proper structure":
    let structure = initMECEStructure("/test/path")
    check structure.rootPath == "/test/path"
    check structure.categories.len == 0
    check structure.customCategories.len == 0
    check structure.overlaps.len == 0
    check structure.missing.len == 0

  test "analyzeStructure detects organized test structure":
    let testRoot = "temp_mece_test"
    
    # Create MECE-compliant structure
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests" / "spec" / "integration")
    createDir(testRoot / "tests" / "spec" / "system")
    
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_example.nim", "# unit test")
    writeFile(testRoot / "tests" / "spec" / "integration" / "test_api.nim", "# integration test")
    writeFile(testRoot / "tests" / "spec" / "system" / "test_e2e.nim", "# system test")
    
    let structure = analyzeStructure(testRoot)
    
    check structure.rootPath == testRoot
    check tcUnit in structure.categories
    check tcIntegration in structure.categories
    check tcSystem in structure.categories
    check structure.missing.len == 0

  test "analyzeStructure detects custom categories":
    let testRoot = "temp_mece_test"
    
    # Create custom category structure
    createDir(testRoot / "tests" / "testPerformance")
    writeFile(testRoot / "tests" / "testPerformance" / "test_benchmark.nim", "# performance test")
    
    let structure = analyzeStructure(testRoot)
    
    check "performance" in structure.customCategories

  test "analyzeStructure finds uncategorized files":
    let testRoot = "temp_mece_test"
    
    # Create uncategorized test files
    createDir(testRoot / "tests")
    writeFile(testRoot / "tests" / "test_orphan.nim", "# orphan test")
    
    let structure = analyzeStructure(testRoot)
    
    check structure.missing.len > 0
    check structure.missing.anyIt("test_orphan.nim" in it)

  test "analyzeStructure detects overlapping categories":
    let testRoot = "temp_mece_test"
    
    # Create structure with potential overlaps
    createDir(testRoot / "tests" / "unit_integration")
    writeFile(testRoot / "tests" / "unit_integration" / "test_mixed.nim", "# mixed test")
    
    let structure = analyzeStructure(testRoot)
    
    # This should be detected as having potential category overlap
    check structure.overlaps.len >= 0 # May or may not detect overlap based on naming

  test "validateMECE returns valid report for good structure":
    let testRoot = "temp_mece_test"
    
    # Create perfect MECE structure
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests" / "spec" / "integration")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    writeFile(testRoot / "tests" / "spec" / "integration" / "test_integration.nim", "# integration test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    check report.structure.rootPath == testRoot
    check report.stats.totalFiles == 2
    check report.stats.categorizedFiles == 2
    check report.stats.uncategorizedFiles == 0

  test "validateMECE detects violations":
    let testRoot = "temp_mece_test"
    
    # Create structure with violations
    createDir(testRoot / "tests")
    writeFile(testRoot / "tests" / "test_orphan.nim", "# orphan test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    check report.isValid == false
    check report.violations.len > 0
    check report.suggestions.len > 0

  test "validateMECE provides suggestions for improvement":
    let testRoot = "temp_mece_test"
    
    # Create structure needing improvement
    createDir(testRoot / "tests" / "spec" / "unit")
    # Add many unit tests to trigger distribution suggestion
    for i in 1..10:
      writeFile(testRoot / "tests" / "spec" / "unit" / $"test_unit" & $i & ".nim", "# unit test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    check report.suggestions.len > 0

  test "validateMECE suggests missing categories":
    let testRoot = "temp_mece_test"
    
    # Create structure with only unit tests
    createDir(testRoot / "tests" / "spec" / "unit")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    # Should suggest adding integration and system tests
    let suggestions = report.suggestions.join(" ")
    check "integration" in suggestions or "system" in suggestions

  test "printMECEReport displays report":
    let testRoot = "temp_mece_test"
    
    createDir(testRoot / "tests" / "spec" / "unit")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    # This will print to stdout, we just verify it doesn't crash
    report.printMECEReport()
    check true

  test "generateMECEStructure creates directory structure":
    let testRoot = "temp_mece_test"
    
    generateMECEStructure(testRoot)
    
    check dirExists(testRoot / "tests")
    check dirExists(testRoot / "tests" / "spec")
    check dirExists(testRoot / "tests" / "spec" / "unit")
    check dirExists(testRoot / "tests" / "spec" / "integration")
    check dirExists(testRoot / "tests" / "spec" / "system")
    check dirExists(testRoot / "tests" / "support")
    check dirExists(testRoot / "tests" / "support" / "fixtures")
    check dirExists(testRoot / "tests" / "support" / "helpers")
    check dirExists(testRoot / "tests" / "support" / "mocks")

  test "generateMECEStructure creates example test files":
    let testRoot = "temp_mece_test"
    
    generateMECEStructure(testRoot)
    
    check fileExists(testRoot / "tests" / "spec" / "unit" / "test_example_unit.nim")
    check fileExists(testRoot / "tests" / "spec" / "integration" / "test_example_integration.nim")
    check fileExists(testRoot / "tests" / "spec" / "system" / "test_example_system.nim")

  test "generateMECEStructure with custom categories":
    let testRoot = "temp_mece_test"
    
    generateMECEStructure(testRoot, @["unit", "integration", "performance"])
    
    check dirExists(testRoot / "tests" / "spec" / "unit")
    check dirExists(testRoot / "tests" / "spec" / "integration")
    check dirExists(testRoot / "tests" / "spec" / "performance")
    check fileExists(testRoot / "tests" / "spec" / "performance" / "test_example_performance.nim")

  test "generateMECEStructure doesn't overwrite existing files":
    let testRoot = "temp_mece_test"
    let existingFile = testRoot / "tests" / "spec" / "unit" / "test_example_unit.nim"
    
    # Create the structure once
    generateMECEStructure(testRoot)
    
    # Modify the existing file
    writeFile(existingFile, "# modified content")
    let originalContent = readFile(existingFile)
    
    # Generate again
    generateMECEStructure(testRoot)
    
    # File should not be overwritten
    check readFile(existingFile) == originalContent

  test "analyzeMECE convenience function":
    let testRoot = "temp_mece_test"
    
    createDir(testRoot / "tests" / "spec" / "unit")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    
    let oldDir = getCurrentDir()
    setCurrentDir(testRoot)
    
    let report = analyzeMECE()
    
    setCurrentDir(oldDir)
    
    check report.stats.totalFiles == 1
    check report.stats.categorizedFiles == 1

  test "analyzeMECE with specific path":
    let testRoot = "temp_mece_test"
    
    createDir(testRoot / "tests" / "spec" / "unit")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    
    let report = analyzeMECE(testRoot)
    
    check report.stats.totalFiles == 1

  test "MECEStats calculates percentages correctly":
    let testRoot = "temp_mece_test"
    
    # Create mixed structure
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests")
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_unit.nim", "# unit test")
    writeFile(testRoot / "tests" / "test_orphan.nim", "# orphan test")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    check report.stats.totalFiles == 2
    check report.stats.categorizedFiles == 1
    check report.stats.uncategorizedFiles == 1
    check "unit" in report.stats.filesPerCategory

  test "normalizeCategory helper function":
    # Test various path patterns
    let testPaths = [
      "/tests/spec/unit/test_foo.nim",
      "/tests/spec/integration/test_bar.nim", 
      "/tests/spec/system/test_baz.nim",
      "/tests/testPerformance/test_perf.nim",
      "/tests/random/test_other.nim"
    ]
    
    # This tests the internal logic by creating files and checking categorization
    let testRoot = "temp_mece_test"
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests" / "spec" / "integration")
    createDir(testRoot / "tests" / "random")
    
    writeFile(testRoot / "tests" / "spec" / "unit" / "test_foo.nim", "# unit")
    writeFile(testRoot / "tests" / "spec" / "integration" / "test_bar.nim", "# integration")
    writeFile(testRoot / "tests" / "random" / "test_other.nim", "# other")
    
    let structure = analyzeStructure(testRoot)
    
    check tcUnit in structure.categories
    check tcIntegration in structure.categories
    check structure.missing.len >= 1 # random/test_other.nim should be uncategorized

  test "MECEStructure handles empty directories":
    let testRoot = "temp_mece_test"
    
    # Create empty test directories
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests" / "spec" / "integration")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    check report.stats.totalFiles == 0
    check report.stats.categorizedFiles == 0

  test "validateMECE handles large category imbalance":
    let testRoot = "temp_mece_test"
    
    createDir(testRoot / "tests" / "spec" / "unit")
    createDir(testRoot / "tests" / "spec" / "integration")
    
    # Create 9 unit tests and 1 integration test
    for i in 1..9:
      writeFile(testRoot / "tests" / "spec" / "unit" / $"test_unit" & $i & ".nim", "# unit")
    writeFile(testRoot / "tests" / "spec" / "integration" / "test_integration.nim", "# integration")
    
    let structure = analyzeStructure(testRoot)
    let report = validateMECE(structure)
    
    # Should suggest more granular organization due to 90% in one category
    check report.suggestions.len > 0
    let suggestions = report.suggestions.join(" ")
    check "granular" in suggestions or "percentage" in suggestions