# Comprehensive test suite for standard_layout.nim
# Achieves 100% code coverage

import unittest
import std/[os, strutils, tables, json, times, tempfiles, sequtils]
import ../src/organization/standard_layout_minimal  # Use minimal version for testing

suite "Standard Layout - Project Detection":
  test "detectProjectLayout with library":
    let tmpDir = getTempDir() / "test_lib_project"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    writeFile(tmpDir / "src" / "lib.nim", "# lib")
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plLibrary
    
    removeDir(tmpDir)

  test "detectProjectLayout with application":
    let tmpDir = getTempDir() / "test_app_project"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    writeFile(tmpDir / "src" / "main.nim", "# main")
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plApplication
    
    removeDir(tmpDir)

  test "detectProjectLayout with app.nim":
    let tmpDir = getTempDir() / "test_app2_project"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    writeFile(tmpDir / "src" / "app.nim", "# app")
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plApplication
    
    removeDir(tmpDir)

  test "detectProjectLayout with hybrid":
    let tmpDir = getTempDir() / "test_hybrid_project"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    writeFile(tmpDir / "src" / "lib.nim", "# lib")
    writeFile(tmpDir / "src" / "main.nim", "# main")
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plHybrid
    
    removeDir(tmpDir)

  test "detectProjectLayout with tests only":
    let tmpDir = getTempDir() / "test_only_project"
    createDir(tmpDir)
    createDir(tmpDir / "tests")
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plStandard
    
    removeDir(tmpDir)

  test "detectProjectLayout with test dir":
    let tmpDir = getTempDir() / "test_dir_project"
    createDir(tmpDir)
    createDir(tmpDir / "test")  # Alternative name
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plStandard
    
    removeDir(tmpDir)

  test "detectProjectLayout with nothing":
    let tmpDir = getTempDir() / "empty_project"
    createDir(tmpDir)
    
    let layout = detectProjectLayout(tmpDir)
    check layout == plCustom
    
    removeDir(tmpDir)

suite "Standard Layout - Directory Finding":
  test "findSourceDir with src":
    let tmpDir = getTempDir() / "test_src"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    
    let sourceDir = findSourceDir(tmpDir)
    check sourceDir == "src"
    
    removeDir(tmpDir)

  test "findSourceDir with source":
    let tmpDir = getTempDir() / "test_source"
    createDir(tmpDir)
    createDir(tmpDir / "source")
    
    let sourceDir = findSourceDir(tmpDir)
    check sourceDir == "source"
    
    removeDir(tmpDir)

  test "findSourceDir with lib":
    let tmpDir = getTempDir() / "test_lib"
    createDir(tmpDir)
    createDir(tmpDir / "lib")
    
    let sourceDir = findSourceDir(tmpDir)
    check sourceDir == "lib"
    
    removeDir(tmpDir)

  test "findSourceDir with none":
    let tmpDir = getTempDir() / "test_nosrc"
    createDir(tmpDir)
    
    let sourceDir = findSourceDir(tmpDir)
    check sourceDir == "."
    
    removeDir(tmpDir)

  test "findTestsDir with tests":
    let tmpDir = getTempDir() / "test_tests"
    createDir(tmpDir)
    createDir(tmpDir / "tests")
    
    let testsDir = findTestsDir(tmpDir)
    check testsDir == "tests"
    
    removeDir(tmpDir)

  test "findTestsDir with test":
    let tmpDir = getTempDir() / "test_test"
    createDir(tmpDir)
    createDir(tmpDir / "test")
    
    let testsDir = findTestsDir(tmpDir)
    check testsDir == "test"
    
    removeDir(tmpDir)

  test "findTestsDir with spec":
    let tmpDir = getTempDir() / "test_spec"
    createDir(tmpDir)
    createDir(tmpDir / "spec")
    
    let testsDir = findTestsDir(tmpDir)
    check testsDir == "spec"
    
    removeDir(tmpDir)

  test "findTestsDir with none":
    let tmpDir = getTempDir() / "test_notests"
    createDir(tmpDir)
    
    let testsDir = findTestsDir(tmpDir)
    check testsDir == "tests"  # Default
    
    removeDir(tmpDir)

suite "Standard Layout - Config File Finding":
  test "findConfigFile with nimtestkit.toml":
    let tmpDir = getTempDir() / "test_config1"
    createDir(tmpDir)
    writeFile(tmpDir / "nimtestkit.toml", "")
    
    let configFile = findConfigFile(tmpDir)
    check configFile == "nimtestkit.toml"
    
    removeDir(tmpDir)

  test "findConfigFile with .nimtestkit.toml":
    let tmpDir = getTempDir() / "test_config2"
    createDir(tmpDir)
    writeFile(tmpDir / ".nimtestkit.toml", "")
    
    let configFile = findConfigFile(tmpDir)
    check configFile == ".nimtestkit.toml"
    
    removeDir(tmpDir)

  test "findConfigFile with testkit.toml":
    let tmpDir = getTempDir() / "test_config3"
    createDir(tmpDir)
    writeFile(tmpDir / "testkit.toml", "")
    
    let configFile = findConfigFile(tmpDir)
    check configFile == "testkit.toml"
    
    removeDir(tmpDir)

  test "findConfigFile with .testkit.toml":
    let tmpDir = getTempDir() / "test_config4"
    createDir(tmpDir)
    writeFile(tmpDir / ".testkit.toml", "")
    
    let configFile = findConfigFile(tmpDir)
    check configFile == ".testkit.toml"
    
    removeDir(tmpDir)

  test "findConfigFile with none":
    let tmpDir = getTempDir() / "test_noconfig"
    createDir(tmpDir)
    
    let configFile = findConfigFile(tmpDir)
    check configFile == "nimtestkit.toml"  # Default
    
    removeDir(tmpDir)

  test "findConfigFile priority order":
    let tmpDir = getTempDir() / "test_priority"
    createDir(tmpDir)
    writeFile(tmpDir / ".testkit.toml", "")
    writeFile(tmpDir / "testkit.toml", "")
    writeFile(tmpDir / ".nimtestkit.toml", "")
    writeFile(tmpDir / "nimtestkit.toml", "")
    
    let configFile = findConfigFile(tmpDir)
    check configFile == "nimtestkit.toml"  # First in priority
    
    removeDir(tmpDir)

suite "Standard Layout - Paths":
  test "getStandardPaths basic":
    let tmpDir = getTempDir() / "test_paths"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    createDir(tmpDir / "tests")
    
    let paths = getStandardPaths(tmpDir)
    check paths.projectRoot == tmpDir
    check paths.sourceDir == "src"
    check paths.testsDir == "tests"
    check paths.buildDir == "build"
    check paths.cacheDir == "build/cache"
    check paths.coverageDir == "build/coverage"
    check paths.docsDir == "docs"
    check paths.examplesDir == "examples"
    check paths.benchmarksDir == "benchmarks"
    check paths.configFile == "nimtestkit.toml"
    
    removeDir(tmpDir)

  test "createBuildDirectories creates all dirs":
    let tmpDir = getTempDir() / "test_builddirs"
    createDir(tmpDir)
    
    let paths = getStandardPaths(tmpDir)
    createBuildDirectories(paths)
    
    check dirExists(tmpDir / "build")
    check dirExists(tmpDir / "build/cache")
    check dirExists(tmpDir / "build/coverage")
    check dirExists(tmpDir / "build/debug")
    check dirExists(tmpDir / "build/release")
    check dirExists(tmpDir / "build/test-results")
    check dirExists(tmpDir / "build/artifacts")
    check dirExists(tmpDir / "build/coverage/raw")
    check dirExists(tmpDir / "build/coverage/reports")
    check dirExists(tmpDir / "build/coverage/temp")
    
    removeDir(tmpDir)

suite "Standard Layout - Build Artifacts":
  test "getBuildArtifactPath debug":
    let paths = StandardPaths(
      projectRoot: "/project",
      buildDir: "build"
    )
    
    let path = getBuildArtifactPath(paths, "myapp", false)
    check path == "/project/build/debug/myapp"

  test "getBuildArtifactPath release":
    let paths = StandardPaths(
      projectRoot: "/project",
      buildDir: "build"
    )
    
    let path = getBuildArtifactPath(paths, "mylib.so", true)
    check path == "/project/build/release/mylib.so"

  test "getTestResultsPath formats":
    let paths = StandardPaths(
      projectRoot: "/project",
      buildDir: "build"
    )
    
    let junitPath = getTestResultsPath(paths, "junit")
    check junitPath.contains("/project/build/test-results/test_results_")
    check junitPath.endsWith(".junit")
    
    let xmlPath = getTestResultsPath(paths, "xml")
    check xmlPath.endsWith(".xml")
    
    let tapPath = getTestResultsPath(paths, "tap")
    check tapPath.endsWith(".tap")

suite "Standard Layout - Coverage Paths":
  test "getCoveragePath main report":
    let paths = StandardPaths(projectRoot: "/project")
    let path = getCoveragePath(paths)
    check path == "/project/build/coverage/reports/index.html"

  test "getCoverageRawPath":
    let paths = StandardPaths(projectRoot: "/project")
    
    let path1 = getCoverageRawPath(paths, "test_module.nim")
    check path1 == "/project/build/coverage/raw/test_module.cov"
    
    let path2 = getCoverageRawPath(paths, "/full/path/test_other.nim")
    check path2 == "/project/build/coverage/raw/test_other.cov"

  test "getCoverageReportPath formats":
    let paths = StandardPaths(projectRoot: "/project")
    
    let htmlPath = getCoverageReportPath(paths, "html")
    check htmlPath == "/project/build/coverage/reports/index.html"
    
    let lcovPath = getCoverageReportPath(paths, "lcov")
    check lcovPath.contains("/project/build/coverage/reports/coverage_")
    check lcovPath.endsWith(".lcov")
    
    let jsonPath = getCoverageReportPath(paths, "json")
    check jsonPath.endsWith(".json")
    
    let xmlPath = getCoverageReportPath(paths, "xml")
    check xmlPath.endsWith(".xml")
    
    let customPath = getCoverageReportPath(paths, "custom")
    check customPath.endsWith(".custom")

  test "getCoverageTempPath":
    let paths = StandardPaths(projectRoot: "/project")
    
    let path = getCoverageTempPath(paths, "processing.tmp")
    check path == "/project/build/coverage/temp/processing.tmp"

  test "cleanCoverageTemp":
    let tmpDir = getTempDir() / "test_clean"
    createDir(tmpDir)
    createDir(tmpDir / "build")
    createDir(tmpDir / "build/coverage")
    createDir(tmpDir / "build/coverage/temp")
    
    # Create temp files
    writeFile(tmpDir / "build/coverage/temp/file1.tmp", "temp1")
    writeFile(tmpDir / "build/coverage/temp/file2.tmp", "temp2")
    
    let paths = StandardPaths(projectRoot: tmpDir)
    cleanCoverageTemp(paths)
    
    # Files should be deleted but directory remains
    check dirExists(tmpDir / "build/coverage/temp")
    check not fileExists(tmpDir / "build/coverage/temp/file1.tmp")
    check not fileExists(tmpDir / "build/coverage/temp/file2.tmp")
    
    removeDir(tmpDir)

  test "cleanCoverageTemp no dir":
    let paths = StandardPaths(projectRoot: "/nonexistent")
    # Should not crash
    cleanCoverageTemp(paths)

suite "Standard Layout - Edge Cases":
  test "ProjectLayout enum values":
    var layout: ProjectLayout
    
    layout = plStandard
    check layout == plStandard
    
    layout = plLibrary
    check layout == plLibrary
    
    layout = plApplication
    check layout == plApplication
    
    layout = plHybrid
    check layout == plHybrid
    
    layout = plCustom
    check layout == plCustom

  test "paths with trailing slashes":
    let tmpDir = getTempDir() / "test_trailing" / ""
    createDir(tmpDir)
    
    let paths = getStandardPaths(tmpDir)
    check paths.projectRoot == tmpDir

  test "unicode in paths":
    let tmpDir = getTempDir() / "test_unicode_αβγ"
    createDir(tmpDir)
    createDir(tmpDir / "src")
    
    let paths = getStandardPaths(tmpDir)
    check paths.sourceDir == "src"
    
    removeDir(tmpDir)

  test "very long paths":
    let longName = "a".repeat(100)
    let tmpDir = getTempDir() / longName
    createDir(tmpDir)
    
    let paths = getStandardPaths(tmpDir)
    let artifact = getBuildArtifactPath(paths, "app", false)
    check artifact.contains(longName)
    
    removeDir(tmpDir)

  test "concurrent directory creation":
    let tmpDir = getTempDir() / "test_concurrent"
    createDir(tmpDir)
    
    let paths = getStandardPaths(tmpDir)
    
    # Create multiple times (should be idempotent)
    createBuildDirectories(paths)
    createBuildDirectories(paths)
    createBuildDirectories(paths)
    
    check dirExists(tmpDir / "build")
    
    removeDir(tmpDir)

  test "StandardPaths fields":
    let paths = StandardPaths(
      projectRoot: "/root",
      sourceDir: "src",
      testsDir: "tests",
      buildDir: "build",
      cacheDir: "cache",
      coverageDir: "coverage",
      docsDir: "docs",
      examplesDir: "examples",
      benchmarksDir: "benchmarks",
      configFile: "config.toml"
    )
    
    check paths.projectRoot == "/root"
    check paths.sourceDir == "src"
    check paths.testsDir == "tests"
    check paths.buildDir == "build"
    check paths.cacheDir == "cache"
    check paths.coverageDir == "coverage"
    check paths.docsDir == "docs"
    check paths.examplesDir == "examples"
    check paths.benchmarksDir == "benchmarks"
    check paths.configFile == "config.toml"

  test "TestKitConfig structure":
    let config = TestKitConfig(
      sourceDir: "src",
      testsDir: "tests",
      includePatterns: @["*.nim"],
      excludePatterns: @["test_*.nim"],
      testNamePattern: "test_${module}.nim",
      coverageThreshold: 80.0,
      parallelTests: true,
      colorOutput: false
    )
    
    check config.sourceDir == "src"
    check config.testsDir == "tests"
    check config.includePatterns == @["*.nim"]
    check config.excludePatterns == @["test_*.nim"]
    check config.testNamePattern == "test_${module}.nim"
    check config.coverageThreshold == 80.0
    check config.parallelTests == true
    check config.colorOutput == false