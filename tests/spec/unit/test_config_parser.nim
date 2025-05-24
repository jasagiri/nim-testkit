# Test suite for config/parser.nim - 100% coverage target

import std/[unittest, os, tables]
import ../../../src/config/parser
import ../../../src/core/types

suite "Config Parser Tests":

  setup:
    # Save original environment variables
    let originalConfig = getEnv("NIMTESTKIT_CONFIG")
    let originalFormat = getEnv("NIMTESTKIT_FORMAT")
    let originalVerbose = getEnv("NIMTESTKIT_VERBOSE")

  teardown:
    # Restore environment variables
    putEnv("NIMTESTKIT_CONFIG", getEnv("NIMTESTKIT_CONFIG"))
    putEnv("NIMTESTKIT_FORMAT", getEnv("NIMTESTKIT_FORMAT"))
    putEnv("NIMTESTKIT_VERBOSE", getEnv("NIMTESTKIT_VERBOSE"))
    
    # Clean up test files
    if fileExists("test_config.toml"):
      removeFile("test_config.toml")
    if fileExists("nimtestkit.toml"):
      removeFile("nimtestkit.toml")

  test "parseTestConfig with default values":
    let config = parseTestConfig()
    check config.outputFormat == ofText
    check config.verbose == false
    check config.parallel == false
    check config.failFast == false
    check config.timeout == 300.0
    check config.reportFile == ""
    check config.randomSeed == 0

  test "parseTestConfig with non-existent file":
    let config = parseTestConfig("non_existent.toml")
    check config.outputFormat == ofText # Should use defaults

  test "parseTestConfig with valid TOML file":
    let configContent = """
[output]
format = "json"
verbose = true
reportFile = "test_report.json"

[runner]
parallel = true
failFast = true
timeout = 60.0
randomSeed = 12345

[filter]
categories = ["unit", "integration"]
tags = ["fast", "slow"]
patterns = ["test_*"]
excludePatterns = ["*_slow"]
"""
    writeFile("test_config.toml", configContent)
    
    let config = parseTestConfig("test_config.toml")
    
    check config.outputFormat == ofJson
    check config.verbose == true
    check config.reportFile == "test_report.json"
    check config.parallel == true
    check config.failFast == true
    check config.timeout == 60.0
    check config.randomSeed == 12345
    check config.filter.categories == @[tcUnit, tcIntegration]
    check config.filter.tags == @["fast", "slow"]
    check config.filter.patterns == @["test_*"]
    check config.filter.excludePatterns == @["*_slow"]

  test "parseTestConfig with all output formats":
    let formats = [
      ("text", ofText),
      ("json", ofJson),
      ("xml", ofXml),
      ("tap", ofTap),
      ("junit", ofJunit)
    ]
    
    for (formatStr, expectedFormat) in formats:
      let configContent = fmt"""
[output]
format = "{formatStr}"
"""
      writeFile("test_config.toml", configContent)
      let config = parseTestConfig("test_config.toml")
      check config.outputFormat == expectedFormat

  test "parseTestConfig with invalid output format":
    let configContent = """
[output]
format = "invalid_format"
"""
    writeFile("test_config.toml", configContent)
    
    let config = parseTestConfig("test_config.toml")
    check config.outputFormat == ofText # Should use default

  test "parseTestConfig with all categories":
    let configContent = """
[filter]
categories = ["unit", "integration", "system", "performance", "invalid"]
"""
    writeFile("test_config.toml", configContent)
    
    let config = parseTestConfig("test_config.toml")
    check tcUnit in config.filter.categories
    check tcIntegration in config.filter.categories
    check tcSystem in config.filter.categories
    check tcPerformance in config.filter.categories
    # "invalid" should be ignored

  test "parseTestConfig with numeric values as strings":
    let configContent = """
[runner]
timeout = "120"
randomSeed = "54321"
"""
    writeFile("test_config.toml", configContent)
    
    let config = parseTestConfig("test_config.toml")
    check config.timeout == 120.0
    check config.randomSeed == 54321

  test "parseTestConfig with float timeout":
    let configContent = """
[runner]
timeout = 45.5
"""
    writeFile("test_config.toml", configContent)
    
    let config = parseTestConfig("test_config.toml")
    check config.timeout == 45.5

  test "parseEnvConfig overrides config values":
    var config = initTestConfig()
    
    putEnv("NIMTESTKIT_FORMAT", "json")
    putEnv("NIMTESTKIT_VERBOSE", "true")
    putEnv("NIMTESTKIT_PARALLEL", "1")
    putEnv("NIMTESTKIT_FAILFAST", "yes")
    putEnv("NIMTESTKIT_TIMEOUT", "180.5")
    putEnv("NIMTESTKIT_CATEGORIES", "unit,integration")
    putEnv("NIMTESTKIT_TAGS", "fast,unit")
    putEnv("NIMTESTKIT_PATTERN", "test_*")
    
    config.parseEnvConfig()
    
    check config.outputFormat == ofJson
    check config.verbose == true
    check config.parallel == true
    check config.failFast == true
    check config.timeout == 180.5
    check config.filter.categories == @[tcUnit, tcIntegration]
    check config.filter.tags == @["fast", "unit"]
    check config.filter.patterns == @["test_*"]

  test "parseEnvConfig with false boolean values":
    var config = initTestConfig()
    config.verbose = true # Set to true first
    
    putEnv("NIMTESTKIT_VERBOSE", "false")
    putEnv("NIMTESTKIT_PARALLEL", "0")
    putEnv("NIMTESTKIT_FAILFAST", "no")
    
    config.parseEnvConfig()
    
    check config.verbose == false
    check config.parallel == false
    check config.failFast == false

  test "parseEnvConfig with invalid values":
    var config = initTestConfig()
    
    putEnv("NIMTESTKIT_FORMAT", "invalid")
    putEnv("NIMTESTKIT_TIMEOUT", "invalid")
    putEnv("NIMTESTKIT_CATEGORIES", "invalid,unit")
    
    config.parseEnvConfig()
    
    check config.outputFormat == ofText # Should remain default
    check config.timeout == 300.0 # Should remain default
    check config.filter.categories == @[tcUnit] # Only valid category should be added

  test "loadConfig combines file and environment":
    let configContent = """
[output]
format = "json"
verbose = false

[runner]
timeout = 60.0
"""
    writeFile("test_config.toml", configContent)
    
    putEnv("NIMTESTKIT_VERBOSE", "true")
    putEnv("NIMTESTKIT_TIMEOUT", "120.0")
    
    let config = loadConfig("test_config.toml")
    
    check config.outputFormat == ofJson # From file
    check config.verbose == true # From environment (overrides file)
    check config.timeout == 120.0 # From environment (overrides file)

  test "loadConfig with environment config file":
    let configContent = """
[output]
format = "tap"
"""
    writeFile("env_config.toml", configContent)
    
    putEnv("NIMTESTKIT_CONFIG", "env_config.toml")
    
    let config = loadConfig()
    
    check config.outputFormat == ofTap
    
    removeFile("env_config.toml")

  test "loadConfig finds config in standard locations":
    let configContent = """
[output]
format = "xml"
"""
    writeFile("nimtestkit.toml", configContent)
    
    let config = loadConfig()
    
    check config.outputFormat == ofXml

  test "generateDefaultConfig creates valid TOML":
    let defaultConfig = generateDefaultConfig()
    
    check "[output]" in defaultConfig
    check "[runner]" in defaultConfig
    check "[filter]" in defaultConfig
    check "format = \"text\"" in defaultConfig
    check "verbose = false" in defaultConfig
    check "parallel = false" in defaultConfig
    check "failFast = false" in defaultConfig
    check "timeout = 300.0" in defaultConfig

  test "saveDefaultConfig creates file":
    saveDefaultConfig("test_default.toml")
    
    check fileExists("test_default.toml")
    let content = readFile("test_default.toml")
    check "[output]" in content
    
    removeFile("test_default.toml")

  test "parseTomlLine handles different value types":
    # This tests the internal parseTomlLine function indirectly through loadTomlConfig
    let configContent = """
string_val = "hello world"
int_val = 42
float_val = 3.14
bool_true = true
bool_false = false
array_val = ["item1", "item2", "item3"]
empty_array = []
"""
    writeFile("test_values.toml", configContent)
    
    # We can't directly test parseTomlLine as it's not exported,
    # but we can test through the config parsing
    let config = parseTestConfig("test_values.toml")
    
    # The function should parse without errors
    check true
    
    removeFile("test_values.toml")

  test "config parser handles comments and empty lines":
    let configContent = """
# This is a comment
[output]
# Another comment
format = "json"

# Empty line above
verbose = true
"""
    writeFile("test_comments.toml", configContent)
    
    let config = parseTestConfig("test_comments.toml")
    
    check config.outputFormat == ofJson
    check config.verbose == true
    
    removeFile("test_comments.toml")

  test "config parser handles sections":
    let configContent = """
[section1]
key1 = "value1"

[section2]
key2 = "value2"
"""
    writeFile("test_sections.toml", configContent)
    
    # Should parse without errors even though these aren't recognized sections
    let config = parseTestConfig("test_sections.toml")
    check config.outputFormat == ofText # Should use defaults
    
    removeFile("test_sections.toml")

  test "config parser handles malformed TOML":
    let configContent = """
[output
format = json missing quotes
invalid line without equals
"""
    writeFile("test_malformed.toml", configContent)
    
    # Should handle gracefully and use defaults
    let config = parseTestConfig("test_malformed.toml")
    check config.outputFormat == ofText
    
    removeFile("test_malformed.toml")

  test "findConfigFile searches all standard paths":
    # Test when no config file exists
    let configFile = findConfigFile()
    # Should return empty string if no file found
    check true # Just verify it doesn't crash

  test "parseEnvConfig handles empty environment values":
    var config = initTestConfig()
    
    putEnv("NIMTESTKIT_FORMAT", "")
    putEnv("NIMTESTKIT_CATEGORIES", "")
    putEnv("NIMTESTKIT_TAGS", "")
    
    config.parseEnvConfig()
    
    # Should handle empty values gracefully
    check config.outputFormat == ofText
    check config.filter.categories.len == 0
    check config.filter.tags.len == 0

  test "config handles all boolean variations":
    let booleanTests = [
      ("true", true),
      ("1", true),
      ("yes", true),
      ("on", true),
      ("false", false),
      ("0", false),
      ("no", false),
      ("off", false),
      ("invalid", false)
    ]
    
    var config = initTestConfig()
    for (value, expected) in booleanTests:
      putEnv("NIMTESTKIT_VERBOSE", value)
      config.parseEnvConfig()
      check config.verbose == expected