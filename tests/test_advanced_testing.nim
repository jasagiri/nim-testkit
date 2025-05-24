import unittest, os, times, strutils, tables
import ../src/advanced/testing, ../src/platform_support

suite "Advanced Testing Features":
  
  setup:
    echo "Setting up advanced testing test environment"
  
  teardown:
    echo "Cleaning up advanced testing test environment"
  
  test "advanced test configuration loading":
    let config = loadAdvancedTestConfig()
    
    check config.enabled == true
    check ttUnit in config.testTypes
    check ttIntegration in config.testTypes
    check config.mutationConfig.iterations == 100
    check config.fuzzConfig.iterations == 1000
    check config.benchmarkConfig.iterations == 1000
    check config.contractConfig.preconditions == true
  
  test "mutation test generation":
    let mutationTest = generateMutationTest("testFunction", "test code", MutationConfig(
      operators: @["arithmetic", "logical"],
      iterations: 10,
      survivorThreshold: 0.1,
      outputDir: "test_output"
    ))
    
    check mutationTest.len > 0
    check "mutation" in mutationTest.toLower()
    check "testFunction" in mutationTest
    check "MutationResult" in mutationTest
  
  test "fuzz test generation":
    let fuzzTest = generateFuzzTest("testFunction", "proc testFunction()", FuzzConfig(
      iterations: 100,
      timeout: 10,
      inputTypes: @["string", "int"],
      outputDir: "test_output"
    ))
    
    check fuzzTest.len > 0
    check "fuzz" in fuzzTest.toLower()
    check "testFunction" in fuzzTest
    check "generateRandomString" in fuzzTest
  
  test "benchmark test generation":
    let benchmarkTest = generateBenchmarkTest("testFunction", "proc testFunction()", BenchmarkConfig(
      iterations: 100,
      warmupRuns: 5,
      timeLimit: 1.0,
      memoryLimit: 1000000
    ))
    
    check benchmarkTest.len > 0
    check "benchmark" in benchmarkTest.toLower()
    check "testFunction" in benchmarkTest
    check "BenchmarkResult" in benchmarkTest
  
  test "contract test generation":
    let contractTest = generateContractTest("testFunction", "proc testFunction()", ContractConfig(
      preconditions: true,
      postconditions: true,
      invariants: true,
      outputDir: "test_output"
    ))
    
    check contractTest.len > 0
    check "contract" in contractTest.toLower()
    check "testFunction" in contractTest
    check "requires" in contractTest
    check "ensures" in contractTest
  
  test "integration test generation":
    let integrationTest = generateIntegrationTest("TestModule", @["dependency1", "dependency2"])
    
    check integrationTest.len > 0
    check "integration" in integrationTest.toLower()
    check "TestModule" in integrationTest
    check "dependency1" in integrationTest
    check "dependency2" in integrationTest
  
  test "advanced test generation for module":
    let config = AdvancedTestConfig(
      enabled: true,
      testTypes: @[ttMutation, ttFuzz, ttBenchmark],
      mutationConfig: MutationConfig(
        operators: @["arithmetic"],
        iterations: 5,
        survivorThreshold: 0.1,
        outputDir: "test_output"
      ),
      fuzzConfig: FuzzConfig(
        iterations: 10,
        timeout: 5,
        inputTypes: @["string"],
        outputDir: "test_output"
      ),
      benchmarkConfig: BenchmarkConfig(
        iterations: 5,
        warmupRuns: 1,
        timeLimit: 1.0,
        memoryLimit: 1000000
      ),
      contractConfig: ContractConfig(
        preconditions: true,
        postconditions: true,
        invariants: true,
        outputDir: "test_output"
      )
    )
    
    let testFiles = generateAdvancedTests("TestModule", @["func1", "func2"], config)
    
    check testFiles.len > 0
    
    # Should generate mutation, fuzz, and benchmark tests for each function
    let expectedCount = 3 * 2  # 3 test types * 2 functions
    check testFiles.len == expectedCount
    
    # Check filenames contain expected patterns
    var foundMutation = false
    var foundFuzz = false
    var foundBenchmark = false
    
    for (filename, content) in testFiles:
      if "mutation" in filename:
        foundMutation = true
        check "MutationResult" in content
      elif "fuzz" in filename:
        foundFuzz = true
        check "FuzzTestResult" in content
      elif "benchmark" in filename:
        foundBenchmark = true
        check "BenchmarkResult" in content
    
    check foundMutation
    check foundFuzz
    check foundBenchmark

suite "Platform Support Features":
  
  test "platform detection":
    let platform = detectPlatform()
    
    # Should detect a valid platform
    check platform in [Windows, macOS, Linux, WebAssembly]
    
    when defined(windows):
      check platform == Windows
    elif defined(macosx):
      check platform == macOS
    elif defined(linux):
      check platform == Linux
    elif defined(js):
      check platform == WebAssembly
  
  test "default platform configuration":
    let config = createDefaultPlatformConfig()
    
    check config.platforms.len > 0
    check config.defaultPlatform == detectPlatform()
    
    # Should have configurations for major platforms
    var hasWindows, hasMacOS, hasLinux = false
    for platformConfig in config.platforms:
      case platformConfig.target:
      of Windows: hasWindows = true
      of macOS: hasMacOS = true
      of Linux: hasLinux = true
      else: discard
    
    check hasWindows
    check hasMacOS
    check hasLinux
  
  test "Windows PowerShell script generation":
    let commands = @[
      "Write-Info \"Starting test\"",
      "Get-ChildItem *.nim",
      "Write-Info \"Test completed\""
    ]
    
    let script = generateWindowsPowerShellScript("TestScript", commands)
    
    check script.len > 0
    check "TestScript" in script
    check "PowerShell" in script
    check "Write-Info" in script
    check "param(" in script
    check "ErrorActionPreference" in script
    
    # Should contain all commands
    for command in commands:
      check command in script
  
  test "macOS test template generation":
    let macOSTemplate = generateMacOSTestTemplate("TestModule")
    
    check macOSTemplate.len > 0
    check "TestModule" in macOSTemplate
    check "macOS" in macOSTemplate
    check "getSystemVersion" in macOSTemplate
    check "isRunningOnM1" in macOSTemplate
    check "HFS+" in macOSTemplate
    check "bundle" in macOSTemplate
  
  test "mobile test template generation":
    let iOSTemplate = generateMobileTestTemplate("TestModule", iOS)
    
    check iOSTemplate.len > 0
    check "TestModule" in iOSTemplate
    check "iOS" in iOSTemplate
    check "isRunningOnDevice" in iOSTemplate
    check "touch" in iOSTemplate.toLower()
    check "sensor" in iOSTemplate.toLower()
    
    let androidTemplate = generateMobileTestTemplate("TestModule", Android)
    
    check androidTemplate.len > 0
    check "TestModule" in androidTemplate
    check "Android" in androidTemplate
  
  test "WebAssembly test template generation":
    let wasmTemplate = generateWebAssemblyTestTemplate("TestModule")
    
    check wasmTemplate.len > 0
    check "TestModule" in wasmTemplate
    check "WebAssembly" in wasmTemplate
    check "getBrowserInfo" in wasmTemplate
    check "testDOMManipulation" in wasmTemplate
    check "async" in wasmTemplate
  
  test "platform-specific script generation":
    # Test Windows PowerShell script
    let windowsScript = generatePlatformSpecificScript(
      Windows, 
      "TestScript", 
      @["echo 'Hello'", "dir"]
    )
    
    check windowsScript.len > 0
    check "PowerShell" in windowsScript
    check "TestScript" in windowsScript
    check "echo 'Hello'" in windowsScript
    
    # Test Unix shell script
    let unixScript = generatePlatformSpecificScript(
      Linux,
      "TestScript",
      @["echo 'Hello'", "ls"]
    )
    
    check unixScript.len > 0
    check "#!/bin/bash" in unixScript
    check "TestScript" in unixScript
    check "echo 'Hello'" in unixScript
  
  test "platform template creation":
    let config = createDefaultPlatformConfig()
    let platformTemplates = createPlatformTemplates(config)
    
    check len(platformTemplates) > 0
    
    # Should have templates for enabled platforms
    when defined(macosx):
      check platformTemplates.hasKey("macos_test_template")
      let macTemplate = platformTemplates["macos_test_template"]
      check "macOS" in macTemplate
    
    # Check template structure
    for (name, content) in platformTemplates.pairs:
      check content.len > 0
      check "$MODULE" in content  # Should have module placeholder