# Environment detection for nim-testkit
# Detects build context and adjusts accordingly

import std/[os, strutils]

type
  BuildEnvironment* = enum
    beUserSpace = "userspace"
    beKernel = "kernel"
    beMixed = "mixed"
    beUnknown = "unknown"

  EnvironmentInfo* = object
    environment*: BuildEnvironment
    memoryModel*: string
    targetOS*: string
    targetCPU*: string
    compilerFlags*: seq[string]
    isStandalone*: bool
    hasMalloc*: bool
    hasThreads*: bool
    optimizationLevel*: string

proc detectFromNimCfg(path: string): EnvironmentInfo =
  ## Detect environment from nim.cfg file
  result.environment = beUnknown
  result.memoryModel = "orc"  # Default
  result.targetOS = "unix"
  result.targetCPU = hostCPU
  result.compilerFlags = @[]
  result.isStandalone = false
  result.hasMalloc = true
  result.hasThreads = true
  result.optimizationLevel = "speed"
  
  if fileExists(path):
    let content = readFile(path)
    for line in content.splitLines():
      let trimmed = line.strip()
      
      # Skip comments and empty lines
      if trimmed.len == 0 or trimmed.startsWith("#"):
        continue
      
      # Parse directives
      if trimmed.startsWith("--mm:"):
        result.memoryModel = trimmed[5..^1]
      elif trimmed.startsWith("--os:"):
        let os = trimmed[5..^1]
        result.targetOS = os
        if os == "standalone":
          result.isStandalone = true
          result.environment = beKernel
      elif trimmed.startsWith("--cpu:"):
        result.targetCPU = trimmed[6..^1]
      elif trimmed.startsWith("--threads:"):
        result.hasThreads = trimmed[10..^1] == "on"
      elif trimmed.startsWith("--gc:"):
        let gc = trimmed[5..^1]
        if gc == "none":
          result.environment = beKernel
      elif trimmed.startsWith("--define:useMalloc"):
        result.hasMalloc = trimmed.contains("true") or not trimmed.contains("false")
      elif trimmed.startsWith("--opt:"):
        result.optimizationLevel = trimmed[6..^1]
      elif trimmed.startsWith("--"):
        # Collect other flags
        result.compilerFlags.add(trimmed)

proc detectEnvironment*(): EnvironmentInfo =
  ## Detect current build environment
  result = EnvironmentInfo()
  
  # Check parent directories for nim.cfg
  var checkDir = getCurrentDir()
  var foundKernelConfig = false
  
  for i in 0..5:  # Check up to 5 levels
    let nimCfg = checkDir / "nim.cfg"
    if fileExists(nimCfg):
      let info = detectFromNimCfg(nimCfg)
      if info.isStandalone or info.environment == beKernel:
        foundKernelConfig = true
        result = info
        break
    
    let parentDir = checkDir.parentDir()
    if parentDir == checkDir:
      break
    checkDir = parentDir
  
  # Additional detection based on directory structure
  if not foundKernelConfig:
    if dirExists("src/kernel") or dirExists("kernel"):
      result.environment = beKernel
    elif dirExists("src/userspace") or dirExists("userspace"):
      result.environment = beUserSpace
    else:
      result.environment = beUnknown

proc getTestCompilerFlags*(env: EnvironmentInfo): seq[string] =
  ## Get appropriate compiler flags for testing in the detected environment
  result = @[]
  
  case env.environment
  of beKernel:
    # For kernel tests, override some settings
    result.add("--os:unix")  # Use standard OS for testing
    result.add("--gc:orc")   # Use ORC for testing
    result.add("--threads:on")
    result.add("--define:useMalloc:false")
    result.add("--panics:off")
  of beUserSpace:
    # Standard userspace settings
    result.add("--mm:" & env.memoryModel)
    result.add("--opt:" & env.optimizationLevel)
  of beMixed:
    # Need to handle both contexts
    result.add("--mm:orc")
    result.add("--threads:on")
  else:
    # Default safe settings
    result.add("--mm:orc")
  
  # Add skip flags to avoid inheriting parent configs
  result.add("--skipCfg")
  result.add("--skipParentCfg")
  result.add("--skipProjCfg")

proc generateTestConfig*(env: EnvironmentInfo, outputPath: string) =
  ## Generate appropriate test configuration file
  var content = "# Auto-generated test configuration\n"
  content.add "# Environment: " & $env.environment & "\n\n"
  
  case env.environment
  of beKernel:
    content.add """
# Kernel test configuration
--mm:arc
--threads:off
--panics:off
--stackTrace:off
--lineTrace:off

# But override for testing
--define:testing
--assertions:on
--checks:on
"""
  of beUserSpace:
    content.add """
# Userspace test configuration
--mm:orc
--threads:on
--assertions:on
--checks:on
--stackTrace:on
--lineTrace:on
--opt:speed
"""
  else:
    content.add """
# Default test configuration
--mm:orc
--threads:on
--assertions:on
--checks:on
--opt:speed
"""
  
  writeFile(outputPath, content)

proc createIsolatedTestEnvironment*(testDir: string): string =
  ## Create an isolated test environment
  let isolatedDir = testDir / ".isolated"
  createDir(isolatedDir)
  
  # Create isolated nim.cfg
  let env = detectEnvironment()
  generateTestConfig(env, isolatedDir / "nim.cfg")
  
  result = isolatedDir

proc getEnvironmentSpecificTemplate*(env: EnvironmentInfo, testType: string): string =
  ## Get environment-specific test template
  case env.environment
  of beKernel:
    case testType
    of "unit":
      result = """
# Kernel unit test template
import std/unittest

suite "$MODULE tests":
  test "basic functionality":
    # Kernel-specific test
    check true
    
  test "no allocation":
    # Verify no dynamic allocation
    check true
"""
    of "integration":
      result = """
# Kernel integration test template
import std/unittest

suite "$MODULE integration":
  test "component interaction":
    # Test kernel components
    check true
"""
    else:
      result = ""
  
  of beUserSpace:
    case testType
    of "unit":
      result = """
# Userspace unit test template
import std/unittest

suite "$MODULE tests":
  test "basic functionality":
    check true
    
  test "error handling":
    expect CatchableError:
      raise newException(ValueError, "test")
"""
    else:
      result = ""
  
  else:
    result = """
# Generic test template
import std/unittest

suite "$MODULE tests":
  test "basic test":
    check true
"""

# Command-line tool
when isMainModule:
  import std/parseopt
  
  var action = "detect"
  var outputPath = ""
  
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "generate", "g":
        action = "generate"
      of "output", "o":
        outputPath = p.val
      of "isolate", "i":
        action = "isolate"
      else: discard
    of cmdArgument:
      outputPath = p.key
  
  case action
  of "detect":
    let env = detectEnvironment()
    echo fmt"Environment: {env.environment}"
    echo fmt"Memory Model: {env.memoryModel}"
    echo fmt"Target OS: {env.targetOS}"
    echo fmt"Is Standalone: {env.isStandalone}"
    echo fmt"Has Threads: {env.hasThreads}"
    echo "\nRecommended test flags:"
    for flag in getTestCompilerFlags(env):
      echo "  " & flag
  
  of "generate":
    if outputPath.len == 0:
      outputPath = "test.nim.cfg"
    let env = detectEnvironment()
    generateTestConfig(env, outputPath)
    echo fmt"Generated test config: {outputPath}"
  
  of "isolate":
    if outputPath.len == 0:
      outputPath = getCurrentDir()
    let isolated = createIsolatedTestEnvironment(outputPath)
    echo fmt"Created isolated environment: {isolated}"