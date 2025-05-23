import unittest
import os
import std/strutils
import ../src/config

suite "Configuration System Tests":
  test "Load default configuration":
    let config = getDefaultConfig()
    check config.sourceDir == "src"
    check config.testsDir == "tests"
    check config.coverageThreshold == 80.0
    check config.parallelTests == false
    check config.colorOutput == true
    
  test "Save and load configuration":
    let testConfig = "test_config.toml"
    
    # Create a test configuration
    var config = getDefaultConfig()
    config.coverageThreshold = 90.0
    config.parallelTests = true
    
    # Save configuration
    saveConfig(config, testConfig)
    check fileExists(testConfig)
    
    # Load configuration
    let loadedConfig = loadConfig(testConfig)
    check loadedConfig.coverageThreshold == 90.0
    check loadedConfig.parallelTests == true
    
    # Cleanup
    removeFile(testConfig)
    
  test "Template placeholder replacement":
    let config = getDefaultConfig()
    check config.testTemplate.contains("$MODULE")
    check config.testTemplate.contains("$MODULE_NAME")
    
  test "Pattern configuration":
    let config = getDefaultConfig()
    check config.includePatterns.len > 0
    check config.excludePatterns.len > 0
    check config.testNamePattern == "${module}_test.nim"