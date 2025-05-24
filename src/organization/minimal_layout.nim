## Standard Project Layout for Nim Projects (Minimal version)
## Provides convention-over-configuration directory structure

import std/[os, strutils, tables, json, times]

type
  ProjectLayout* = enum
    plStandard    # Standard Nim project layout
    plLibrary     # Library project layout
    plApplication # Application project layout
    plHybrid      # Mixed lib/app project
    plCustom      # Custom layout

  StandardPaths* = object
    projectRoot*: string
    sourceDir*: string
    testsDir*: string
    buildDir*: string
    cacheDir*: string
    coverageDir*: string
    docsDir*: string
    examplesDir*: string
    benchmarksDir*: string
    configFile*: string

  # Minimal TestKitConfig for standalone use
  TestKitConfig* = object
    sourceDir*: string
    testsDir*: string
    includePatterns*: seq[string]
    excludePatterns*: seq[string]
    testNamePattern*: string
    coverageThreshold*: float
    parallelTests*: bool
    colorOutput*: bool

const
  # Standard directory names following Nim conventions
  StandardSourceDirs = ["src", "source", "lib"]
  StandardTestDirs = ["tests", "test", "spec"]
  StandardBuildDir = "build"
  StandardCacheDir = "build/cache"
  StandardCoverageDir = "build/coverage"
  StandardDocsDir = "docs"
  StandardExamplesDir = "examples"
  StandardBenchmarksDir = "benchmarks"
  
  # Coverage specific subdirectories
  CoverageRawDir* = "build/coverage/raw"
  CoverageReportsDir* = "build/coverage/reports"
  CoverageTempDir* = "build/coverage/temp"
  
  # Standard config file names in priority order
  StandardConfigFiles = [
    "nimtestkit.toml",
    ".nimtestkit.toml",
    "testkit.toml",
    ".testkit.toml"
  ]

proc detectProjectLayout*(root = getCurrentDir()): ProjectLayout =
  ## Detects the project layout based on directory structure
  let hasLib = dirExists(root / "src") or dirExists(root / "lib")
  let hasApp = fileExists(root / "src" / "main.nim") or 
               fileExists(root / "src" / "app.nim")
  let hasTests = dirExists(root / "tests") or dirExists(root / "test")
  
  if hasLib and hasApp:
    plHybrid
  elif hasLib:
    plLibrary
  elif hasApp:
    plApplication
  elif hasTests:
    plStandard
  else:
    plCustom

proc findSourceDir*(root = getCurrentDir()): string =
  ## Auto-detects source directory
  for dir in StandardSourceDirs:
    let path = root / dir
    if dirExists(path):
      return dir
  # Fallback: if no standard dir exists, use root for simple projects
  return "."

proc findTestsDir*(root = getCurrentDir()): string =
  ## Auto-detects tests directory
  for dir in StandardTestDirs:
    let path = root / dir
    if dirExists(path):
      return dir
  return "tests" # Default if none exists

proc findConfigFile*(root = getCurrentDir()): string =
  ## Finds existing config file or returns default name
  for configName in StandardConfigFiles:
    let path = root / configName
    if fileExists(path):
      return configName
  return StandardConfigFiles[0] # Default to first option

proc getStandardPaths*(root = getCurrentDir()): StandardPaths =
  ## Returns standard paths for the project
  StandardPaths(
    projectRoot: root,
    sourceDir: findSourceDir(root),
    testsDir: findTestsDir(root),
    buildDir: StandardBuildDir,
    cacheDir: StandardCacheDir,
    coverageDir: StandardCoverageDir,
    docsDir: StandardDocsDir,
    examplesDir: StandardExamplesDir,
    benchmarksDir: StandardBenchmarksDir,
    configFile: findConfigFile(root)
  )

proc createBuildDirectories*(paths: StandardPaths) =
  ## Creates build directory structure like Cargo
  createDir(paths.projectRoot / paths.buildDir)
  createDir(paths.projectRoot / paths.cacheDir)
  createDir(paths.projectRoot / paths.coverageDir)
  createDir(paths.projectRoot / paths.buildDir / "debug")
  createDir(paths.projectRoot / paths.buildDir / "release")
  createDir(paths.projectRoot / paths.buildDir / "test-results")
  createDir(paths.projectRoot / paths.buildDir / "artifacts")
  
  # Create coverage subdirectories
  createDir(paths.projectRoot / CoverageRawDir)
  createDir(paths.projectRoot / CoverageReportsDir)
  createDir(paths.projectRoot / CoverageTempDir)

proc getBuildArtifactPath*(paths: StandardPaths, artifactName: string, 
                          release = false): string =
  ## Returns path for build artifacts (like Cargo's target directory)
  let buildType = if release: "release" else: "debug"
  paths.projectRoot / paths.buildDir / buildType / artifactName

proc getTestResultsPath*(paths: StandardPaths, format = "junit"): string =
  ## Returns path for test results
  let timestamp = getTime().format("yyyyMMdd_HHmmss")
  paths.projectRoot / paths.buildDir / "test-results" / 
    "test_results_" & timestamp & "." & format

proc getCoveragePath*(paths: StandardPaths): string =
  ## Returns path for main coverage report
  paths.projectRoot / CoverageReportsDir / "index.html"

proc getCoverageRawPath*(paths: StandardPaths, testFile: string): string =
  ## Returns path for raw coverage data for a specific test file
  let baseName = testFile.extractFilename.changeFileExt("")
  paths.projectRoot / CoverageRawDir / baseName & ".cov"

proc getCoverageReportPath*(paths: StandardPaths, format: string): string =
  ## Returns path for coverage report in specific format
  let timestamp = getTime().format("yyyyMMdd_HHmmss")
  case format
  of "html":
    paths.projectRoot / CoverageReportsDir / "index.html"
  of "lcov":
    paths.projectRoot / CoverageReportsDir / "coverage_" & timestamp & ".lcov"
  of "json":
    paths.projectRoot / CoverageReportsDir / "coverage_" & timestamp & ".json"
  of "xml":
    paths.projectRoot / CoverageReportsDir / "coverage_" & timestamp & ".xml"
  else:
    paths.projectRoot / CoverageReportsDir / "coverage_" & timestamp & "." & format

proc getCoverageTempPath*(paths: StandardPaths, suffix: string): string =
  ## Returns path for temporary coverage files
  paths.projectRoot / CoverageTempDir / suffix

proc cleanCoverageTemp*(paths: StandardPaths) =
  ## Cleans temporary coverage files
  let tempDir = paths.projectRoot / CoverageTempDir
  if dirExists(tempDir):
    for file in walkFiles(tempDir / "*"):
      removeFile(file)