# Configuration parser for nim-testkit
# Zero external dependencies - uses only Nim stdlib

import std/[os, strutils, tables, parseutils, strformat]
import ../core/types

type
  ConfigError* = object of CatchableError
  
  ConfigValueKind = enum
    cvkString, cvkInt, cvkFloat, cvkBool, cvkSeq
    
  ConfigValue = object
    case kind: ConfigValueKind
    of cvkString: strVal: string
    of cvkInt: intVal: int
    of cvkFloat: floatVal: float
    of cvkBool: boolVal: bool
    of cvkSeq: seqVal: seq[string]

const
  DefaultConfigName = "nimtestkit.toml"
  ConfigSearchPaths = @[
    ".",
    "tests",
    "test",
    ".config"
  ]

proc parseTomlLine(line: string): tuple[key: string, value: ConfigValue, isValid: bool] =
  result.isValid = false
  let trimmed = line.strip()
  
  # Skip empty lines and comments
  if trimmed.len == 0 or trimmed[0] == '#':
    return
  
  # Find key-value separator
  let eqPos = trimmed.find('=')
  if eqPos < 0:
    return
  
  result.key = trimmed[0..<eqPos].strip()
  let valueStr = trimmed[eqPos+1..^1].strip()
  
  # Parse value based on format
  if valueStr.len == 0:
    return
  
  # String (quoted)
  if valueStr[0] == '"' and valueStr[^1] == '"':
    result.value = ConfigValue(kind: cvkString, strVal: valueStr[1..^2])
    result.isValid = true
    return
  
  # Boolean
  if valueStr == "true":
    result.value = ConfigValue(kind: cvkBool, boolVal: true)
    result.isValid = true
    return
  elif valueStr == "false":
    result.value = ConfigValue(kind: cvkBool, boolVal: false)
    result.isValid = true
    return
  
  # Array
  if valueStr[0] == '[' and valueStr[^1] == ']':
    var items: seq[string] = @[]
    let inner = valueStr[1..^2].strip()
    if inner.len > 0:
      for item in inner.split(','):
        let trimItem = item.strip()
        if trimItem.len >= 2 and trimItem[0] == '"' and trimItem[^1] == '"':
          items.add(trimItem[1..^2])
        else:
          items.add(trimItem)
    result.value = ConfigValue(kind: cvkSeq, seqVal: items)
    result.isValid = true
    return
  
  # Try to parse as number
  var intVal: int
  var floatVal: float
  if parseInt(valueStr, intVal) == valueStr.len:
    result.value = ConfigValue(kind: cvkInt, intVal: intVal)
    result.isValid = true
    return
  elif parseFloat(valueStr, floatVal) == valueStr.len:
    result.value = ConfigValue(kind: cvkFloat, floatVal: floatVal)
    result.isValid = true
    return
  
  # Default to string
  result.value = ConfigValue(kind: cvkString, strVal: valueStr)
  result.isValid = true

proc loadTomlConfig(filename: string): Table[string, ConfigValue] =
  result = initTable[string, ConfigValue]()
  
  if not fileExists(filename):
    return
  
  let content = readFile(filename)
  var currentSection = ""
  
  for line in content.splitLines():
    let trimmed = line.strip()
    
    # Skip empty lines and comments
    if trimmed.len == 0 or trimmed[0] == '#':
      continue
    
    # Section header
    if trimmed[0] == '[' and trimmed[^1] == ']':
      currentSection = trimmed[1..^2]
      continue
    
    # Parse key-value
    let (key, value, isValid) = parseTomlLine(line)
    if isValid:
      let fullKey = if currentSection.len > 0: currentSection & "." & key else: key
      result[fullKey] = value

proc findConfigFile(): string =
  # Check environment variable
  let envConfig = getEnv("NIMTESTKIT_CONFIG")
  if envConfig.len > 0 and fileExists(envConfig):
    return envConfig
  
  # Search in standard locations
  for path in ConfigSearchPaths:
    let configPath = path / DefaultConfigName
    if fileExists(configPath):
      return configPath
  
  return ""

proc parseTestConfig*(filename: string = ""): TestConfig =
  result = initTestConfig()
  
  let configFile = if filename.len > 0: filename else: findConfigFile()
  if configFile.len == 0:
    return # Use defaults
  
  let config = loadTomlConfig(configFile)
  
  # Parse output format
  if "output.format" in config and config["output.format"].kind == cvkString:
    case config["output.format"].strVal
    of "text": result.outputFormat = ofText
    of "json": result.outputFormat = ofJson
    of "xml": result.outputFormat = ofXml
    of "tap": result.outputFormat = ofTap
    of "junit": result.outputFormat = ofJunit
    else: discard
  
  # Parse boolean options
  if "output.verbose" in config and config["output.verbose"].kind == cvkBool:
    result.verbose = config["output.verbose"].boolVal
  
  if "runner.parallel" in config and config["runner.parallel"].kind == cvkBool:
    result.parallel = config["runner.parallel"].boolVal
  
  if "runner.failFast" in config and config["runner.failFast"].kind == cvkBool:
    result.failFast = config["runner.failFast"].boolVal
  
  # Parse numeric options
  if "runner.timeout" in config:
    case config["runner.timeout"].kind
    of cvkInt: result.timeout = config["runner.timeout"].intVal.float
    of cvkFloat: result.timeout = config["runner.timeout"].floatVal
    else: discard
  
  if "runner.randomSeed" in config and config["runner.randomSeed"].kind == cvkInt:
    result.randomSeed = config["runner.randomSeed"].intVal
  
  # Parse string options
  if "output.reportFile" in config and config["output.reportFile"].kind == cvkString:
    result.reportFile = config["output.reportFile"].strVal
  
  # Parse filter options
  if "filter.categories" in config and config["filter.categories"].kind == cvkSeq:
    for cat in config["filter.categories"].seqVal:
      case cat
      of "unit": result.filter.categories.add(tcUnit)
      of "integration": result.filter.categories.add(tcIntegration)
      of "system": result.filter.categories.add(tcSystem)
      of "performance": result.filter.categories.add(tcPerformance)
      else: discard
  
  if "filter.tags" in config and config["filter.tags"].kind == cvkSeq:
    result.filter.tags = config["filter.tags"].seqVal
  
  if "filter.patterns" in config and config["filter.patterns"].kind == cvkSeq:
    result.filter.patterns = config["filter.patterns"].seqVal
  
  if "filter.excludePatterns" in config and config["filter.excludePatterns"].kind == cvkSeq:
    result.filter.excludePatterns = config["filter.excludePatterns"].seqVal

proc parseEnvConfig*(config: var TestConfig) =
  ## Override config with environment variables
  
  # Output format
  let envFormat = getEnv("NIMTESTKIT_FORMAT")
  if envFormat.len > 0:
    case envFormat
    of "text": config.outputFormat = ofText
    of "json": config.outputFormat = ofJson
    of "xml": config.outputFormat = ofXml
    of "tap": config.outputFormat = ofTap
    of "junit": config.outputFormat = ofJunit
    else: discard
  
  # Boolean flags
  let envVerbose = getEnv("NIMTESTKIT_VERBOSE")
  if envVerbose.len > 0:
    config.verbose = envVerbose.toLowerAscii in ["true", "1", "yes", "on"]
  
  let envParallel = getEnv("NIMTESTKIT_PARALLEL")
  if envParallel.len > 0:
    config.parallel = envParallel.toLowerAscii in ["true", "1", "yes", "on"]
  
  let envFailFast = getEnv("NIMTESTKIT_FAILFAST")
  if envFailFast.len > 0:
    config.failFast = envFailFast.toLowerAscii in ["true", "1", "yes", "on"]
  
  # Numeric options
  let envTimeout = getEnv("NIMTESTKIT_TIMEOUT")
  if envTimeout.len > 0:
    try:
      config.timeout = parseFloat(envTimeout)
    except ValueError:
      discard
  
  # Filter options
  let envCategories = getEnv("NIMTESTKIT_CATEGORIES")
  if envCategories.len > 0:
    config.filter.categories = @[]
    for cat in envCategories.split(','):
      case cat.strip()
      of "unit": config.filter.categories.add(tcUnit)
      of "integration": config.filter.categories.add(tcIntegration)
      of "system": config.filter.categories.add(tcSystem)
      of "performance": config.filter.categories.add(tcPerformance)
      else: discard
  
  let envTags = getEnv("NIMTESTKIT_TAGS")
  if envTags.len > 0:
    config.filter.tags = @[]
    for tag in envTags.split(','):
      config.filter.tags.add(tag.strip())
  
  let envPattern = getEnv("NIMTESTKIT_PATTERN")
  if envPattern.len > 0:
    config.filter.patterns = @[envPattern]

proc loadConfig*(filename: string = ""): TestConfig =
  ## Load configuration from file and environment
  result = parseTestConfig(filename)
  result.parseEnvConfig()

proc generateDefaultConfig*(): string =
  ## Generate a default nimtestkit.toml configuration
  result = """
# Nim TestKit Configuration

[output]
format = "text"  # Options: text, json, xml, tap, junit
verbose = false
reportFile = ""  # Empty means no file output

[runner]
parallel = false
failFast = false
timeout = 300.0  # Default timeout in seconds (5 minutes)
randomSeed = 0   # 0 means use current time

[filter]
categories = []  # Empty means run all categories
tags = []        # Empty means no tag filtering
patterns = []    # Empty means no pattern filtering
excludePatterns = []  # Patterns to exclude

# Environment variable overrides:
# NIMTESTKIT_CONFIG - Path to config file
# NIMTESTKIT_FORMAT - Output format
# NIMTESTKIT_VERBOSE - Enable verbose output
# NIMTESTKIT_PARALLEL - Enable parallel execution
# NIMTESTKIT_FAILFAST - Stop on first failure
# NIMTESTKIT_TIMEOUT - Global timeout
# NIMTESTKIT_CATEGORIES - Comma-separated categories
# NIMTESTKIT_TAGS - Comma-separated tags
# NIMTESTKIT_PATTERN - Test name pattern
"""

proc saveDefaultConfig*(path: string = DefaultConfigName) =
  writeFile(path, generateDefaultConfig())
  echo fmt"Created default configuration at {path}"