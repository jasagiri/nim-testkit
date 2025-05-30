## Nim TestKit Configuration Module
##
## Handles loading and parsing of nimtestkit.toml configuration files

import std/[os, strutils, parsecfg, sequtils]
import ../integrations/lang/lang_core_integration

type
  VCSConfig* = object
    git*: bool
    jujutsu*: bool
    mercurial*: bool
    svn*: bool
    fossil*: bool
    
  TestKitConfig* = object
    sourceDir*: string
    testsDir*: string
    includePatterns*: seq[string]
    excludePatterns*: seq[string]
    testNamePattern*: string
    coverageThreshold*: float
    parallelTests*: bool
    colorOutput*: bool
    testTemplate*: string
    usePowerAssert*: bool
    enableJujutsu*: bool  # Deprecated, use vcs.jujutsu
    vcs*: VCSConfig

proc getDefaultConfig*(): TestKitConfig =
  ## Returns the default configuration
  result = TestKitConfig(
    sourceDir: "src",
    testsDir: "tests",
    includePatterns: @["*.nim"],
    excludePatterns: @["*_test.nim", "test_*.nim"],
    testNamePattern: "${module}_test.nim",
    coverageThreshold: 80.0,
    parallelTests: false,
    colorOutput: true,
    usePowerAssert: true,
    enableJujutsu: false,
    vcs: VCSConfig(
      git: true,
      jujutsu: false,
      mercurial: false,
      svn: false,
      fossil: false
    ),
    testTemplate: """
import unittest
import power_assert
import "$MODULE"

suite "$MODULE_NAME Tests":
  test "example test":
    assert true
"""
  )

proc loadConfig*(configPath = "nimtestkit.toml"): TestKitConfig =
  ## Loads configuration from a config file, falling back to defaults
  # Import standard layout for auto-detection
  when compiles(import standard_layout):
    import standard_layout
    # If no config exists, use standard layout detection
    if not fileExists(configPath):
      let paths = getStandardPaths()
      return loadOrCreateConfig(paths)
  
  result = getDefaultConfig()
  
  if not fileExists(configPath):
    return
  
  # Use nim-lang-core's tryOp for safe config loading
  let configResult = tryOp(proc(): Config =
    parsecfg.loadConfig(configPath)
  )
  
  if not configResult.isOk:
    echo "Warning: Failed to load config: ", configResult.error
    return
  
  var cfg = configResult.value
  
  # Parse directories
  result.sourceDir = cfg.getSectionValue("directories", "source", result.sourceDir)
  result.testsDir = cfg.getSectionValue("directories", "tests", result.testsDir)
  
  # Parse patterns using nim-lang-core's pipe functionality
  let includeStr = cfg.getSectionValue("patterns", "include", "")
  if includeStr != "":
    result.includePatterns = pipe(includeStr)
      .map(proc(s: string): seq[string] = s.split(","))
      .map(proc(parts: seq[string]): seq[string] = parts.mapIt(it.strip()))
      .collect()
  
  let excludeStr = cfg.getSectionValue("patterns", "exclude", "")
  if excludeStr != "":
    result.excludePatterns = pipe(excludeStr)
      .map(proc(s: string): seq[string] = s.split(","))
      .map(proc(parts: seq[string]): seq[string] = parts.mapIt(it.strip()))
      .collect()
  
  result.testNamePattern = cfg.getSectionValue("patterns", "test_name", result.testNamePattern)
  
  # Parse coverage settings
  let thresholdStr = cfg.getSectionValue("coverage", "threshold", "80.0")
  result.coverageThreshold = parseFloat(thresholdStr)
  
  # Parse test settings
  let parallelStr = cfg.getSectionValue("tests", "parallel", "false")
  result.parallelTests = parseBool(parallelStr)
  
  let colorStr = cfg.getSectionValue("tests", "color", "true")  
  result.colorOutput = parseBool(colorStr)
  
  let powerAssertStr = cfg.getSectionValue("tests", "power_assert", "true")
  result.usePowerAssert = parseBool(powerAssertStr)
  
  # Parse Jujutsu settings (deprecated)
  let jujutsuStr = cfg.getSectionValue("jujutsu", "enabled", "false")
  result.enableJujutsu = parseBool(jujutsuStr)
  
  # Parse VCS settings
  let gitStr = cfg.getSectionValue("vcs", "git", "true")
  result.vcs.git = parseBool(gitStr)
  
  let jjStr = cfg.getSectionValue("vcs", "jujutsu", $result.enableJujutsu)
  result.vcs.jujutsu = parseBool(jjStr)
  
  let hgStr = cfg.getSectionValue("vcs", "mercurial", "false")
  result.vcs.mercurial = parseBool(hgStr)
  
  let svnStr = cfg.getSectionValue("vcs", "svn", "false")
  result.vcs.svn = parseBool(svnStr)
  
  let fossilStr = cfg.getSectionValue("vcs", "fossil", "false")
  result.vcs.fossil = parseBool(fossilStr)
  
  # Parse templates
  let templateStr = cfg.getSectionValue("templates", "test", result.testTemplate)
  result.testTemplate = templateStr.replace("\\n", "\n")

proc validateConfig*(config: TestKitConfig): CoreResult[bool, string] =
  ## Validates configuration using nim-lang-core's Result type
  if config.sourceDir == "":
    return err("Source directory cannot be empty", bool)
  if config.testsDir == "":
    return err("Tests directory cannot be empty", bool)
  if config.coverageThreshold < 0 or config.coverageThreshold > 100:
    return err("Coverage threshold must be between 0 and 100", bool)
  if config.includePatterns.len == 0:
    return err("At least one include pattern is required", bool)
  return ok(true, string)

proc saveConfig*(config: TestKitConfig, configPath = "nimtestkit.toml") =
  ## Saves configuration to a config file  
  # Validate config before saving
  let validationResult = validateConfig(config)
  if not validationResult.isOk:
    raise newException(ValueError, validationResult.error)
  
  var content = """
[directories]
source = $1
tests = $2

[patterns]
include = $3
exclude = $4
test_name = $5

[coverage]
threshold = $6

[tests]
parallel = $7
color = $8
power_assert = $9

[jujutsu]
enabled = $10

[vcs]
git = $11
jujutsu = $12
mercurial = $13
svn = $14
fossil = $15

[templates]
test = $16
"""
  
  content = content % [
    config.sourceDir,
    config.testsDir,
    config.includePatterns.join(","),
    config.excludePatterns.join(","),
    config.testNamePattern,
    $config.coverageThreshold,
    $config.parallelTests,
    $config.colorOutput,
    $config.usePowerAssert,
    $config.enableJujutsu,
    $config.vcs.git,
    $config.vcs.jujutsu,
    $config.vcs.mercurial,
    $config.vcs.svn,
    $config.vcs.fossil,
    config.testTemplate.replace("\n", "\\n")
  ]
  
  writeFile(configPath, content)

proc createDefaultConfigFile*(path = "nimtestkit.toml") =
  ## Creates a default configuration file
  let defaultConfig = getDefaultConfig()
  saveConfig(defaultConfig, path)