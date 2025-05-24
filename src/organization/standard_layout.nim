## Standard Project Layout for Nim Projects
## Provides convention-over-configuration directory structure

import std/[os, strutils, tables, json]
import ../config/config
import ../integrations/lang/lang_core_integration

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
  CoverageRawDir = "build/coverage/raw"        # Raw coverage data files
  CoverageReportsDir = "build/coverage/reports" # Generated reports
  CoverageTempDir = "build/coverage/temp"      # Temporary/intermediate files
  
  # Standard config file names in priority order
  StandardConfigFiles = [
    "nimtestkit.toml",
    ".nimtestkit.toml",
    "testkit.toml",
    ".testkit.toml"
  ]

  # Minimal default configuration
  MinimalConfig = """
# Minimal nim-testkit configuration
# Most settings are auto-detected from project structure

[build]
output_dir = "build"

[tests]
parallel = true
"""

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

proc loadOrCreateConfig*(paths: StandardPaths): TestKitConfig =
  ## Loads config with smart defaults based on project structure
  let configPath = paths.projectRoot / paths.configFile
  
  if fileExists(configPath):
    result = loadConfig(configPath)
  else:
    # Create config with detected values
    result = TestKitConfig(
      sourceDir: paths.sourceDir,
      testsDir: paths.testsDir,
      includePatterns: @["*.nim"],
      excludePatterns: @["*_test.nim", "test_*.nim"],
      testNamePattern: "test_${module}.nim",
      coverageThreshold: 80.0,
      parallelTests: true,
      colorOutput: true,
      usePowerAssert: true,
      enableJujutsu: false,
      vcs: VCSConfig(git: true),
      testTemplate: getTestTemplate(detectProjectLayout(paths.projectRoot))
    )

proc getTestTemplate*(layout: ProjectLayout): string =
  ## Returns appropriate test template based on project layout
  case layout
  of plLibrary:
    """
import unittest
import ../src/$MODULE

suite "$MODULE_NAME tests":
  test "can import $MODULE_NAME":
    check true
"""
  of plApplication:
    """
import unittest
import ../src/$MODULE

suite "$MODULE_NAME integration tests":
  setup:
    # Setup test environment
    discard
  
  teardown:
    # Cleanup
    discard
  
  test "application starts correctly":
    check true
"""
  else:
    """
import unittest
import $MODULE

suite "$MODULE_NAME tests":
  test "example test":
    check true
"""

proc initStandardProject*(projectPath: string, layout = plStandard) =
  ## Initializes a new project with standard structure
  let paths = getStandardPaths(projectPath)
  
  # Create directory structure
  createDir(projectPath / paths.sourceDir)
  createDir(projectPath / paths.testsDir)
  createBuildDirectories(paths)
  
  # Create minimal config if it doesn't exist
  let configPath = projectPath / paths.configFile
  if not fileExists(configPath):
    writeFile(configPath, MinimalConfig)
  
  # Create .gitignore for build directory
  let gitignorePath = projectPath / ".gitignore"
  if not fileExists(gitignorePath):
    writeFile(gitignorePath, """
# nim-testkit build artifacts
/build/
*.exe
*.dll
*.so
*.dylib

# Nim cache
nimcache/
""")
  
  # Create example source file for library projects
  if layout == plLibrary:
    let libFile = projectPath / paths.sourceDir / "lib.nim"
    if not fileExists(libFile):
      writeFile(libFile, """
## Example library module

proc hello*(name: string): string =
  ## Returns a greeting
  "Hello, " & name & "!"
""")
  
  echo "Initialized ", layout, " project at ", projectPath

proc getBuildArtifactPath*(paths: StandardPaths, artifactName: string, 
                          release = false): string =
  ## Returns path for build artifacts (like Cargo's target directory)
  let buildType = if release: "release" else: "debug"
  paths.projectRoot / paths.buildDir / buildType / artifactName

proc getTestResultsPath*(paths: StandardPaths, format = "junit"): string =
  ## Returns path for test results
  let timestamp = getTime().format("yyyyMMdd_HHmmss")
  paths.projectRoot / paths.buildDir / "test-results" / 
    fmt"test_results_{timestamp}.{format}"

proc getCoveragePath*(paths: StandardPaths): string =
  ## Returns path for main coverage report
  paths.projectRoot / CoverageReportsDir / "index.html"

proc getCoverageRawPath*(paths: StandardPaths, testFile: string): string =
  ## Returns path for raw coverage data for a specific test file
  let baseName = testFile.extractFilename.changeFileExt("")
  paths.projectRoot / CoverageRawDir / fmt"{baseName}.cov"

proc getCoverageReportPath*(paths: StandardPaths, format: string): string =
  ## Returns path for coverage report in specific format
  let timestamp = getTime().format("yyyyMMdd_HHmmss")
  case format
  of "html":
    paths.projectRoot / CoverageReportsDir / "index.html"
  of "lcov":
    paths.projectRoot / CoverageReportsDir / fmt"coverage_{timestamp}.lcov"
  of "json":
    paths.projectRoot / CoverageReportsDir / fmt"coverage_{timestamp}.json"
  of "xml":
    paths.projectRoot / CoverageReportsDir / fmt"coverage_{timestamp}.xml"
  else:
    paths.projectRoot / CoverageReportsDir / fmt"coverage_{timestamp}.{format}"

proc getCoverageTempPath*(paths: StandardPaths, suffix: string): string =
  ## Returns path for temporary coverage files
  paths.projectRoot / CoverageTempDir / suffix

proc cleanCoverageTemp*(paths: StandardPaths) =
  ## Cleans temporary coverage files
  let tempDir = paths.projectRoot / CoverageTempDir
  if dirExists(tempDir):
    for file in walkFiles(tempDir / "*"):
      removeFile(file)

# Configuration presets for common scenarios
proc getPresetConfig*(preset: string): TestKitConfig =
  ## Returns preset configurations for common project types
  case preset
  of "minimal":
    TestKitConfig(
      sourceDir: "src",
      testsDir: "tests",
      includePatterns: @["*.nim"],
      excludePatterns: @["test_*.nim"],
      testNamePattern: "test_${module}.nim",
      coverageThreshold: 0.0,  # No coverage requirement
      parallelTests: false,
      colorOutput: true,
      usePowerAssert: false,
      enableJujutsu: false,
      vcs: VCSConfig(git: false),
      testTemplate: """
import unittest
import $MODULE

test "basic test":
  check true
"""
    )
  of "strict":
    TestKitConfig(
      sourceDir: "src",
      testsDir: "tests",
      includePatterns: @["*.nim"],
      excludePatterns: @["test_*.nim", "*_test.nim"],
      testNamePattern: "test_${module}.nim",
      coverageThreshold: 90.0,  # High coverage requirement
      parallelTests: true,
      colorOutput: true,
      usePowerAssert: true,
      enableJujutsu: false,
      vcs: VCSConfig(git: true),
      testTemplate: getTestTemplate(plStandard)
    )
  else:
    getDefaultConfig()

# Project info detection
type
  ProjectInfo* = object
    name*: string
    version*: string
    author*: string
    description*: string
    layout*: ProjectLayout
    paths*: StandardPaths

proc detectProjectInfo*(root = getCurrentDir()): ProjectInfo =
  ## Detects project information from nimble file and structure
  result.paths = getStandardPaths(root)
  result.layout = detectProjectLayout(root)
  
  # Try to read from nimble file
  for file in walkFiles(root / "*.nimble"):
    let content = readFile(file)
    result.name = file.extractFilename.changeFileExt("")
    
    for line in content.splitLines:
      if line.startsWith("version"):
        result.version = line.split("=")[1].strip.strip('"')
      elif line.startsWith("author"):
        result.author = line.split("=")[1].strip.strip('"')
      elif line.startsWith("description"):
        result.description = line.split("=")[1].strip.strip('"')
    break
  
  # Fallback to directory name
  if result.name == "":
    result.name = root.splitPath.tail