# Unit test generation for nim-testkit
# Zero external dependencies - uses only Nim stdlib

import std/[os, strutils, strformat]
import ../core/types

type
  UnitTestTemplate* = object
    moduleName*: string
    functionName*: string
    category*: TestCategory
    imports*: seq[string]
    setupCode*: string
    teardownCode*: string
    testCases*: seq[TestCase]

  TestCase* = object
    name*: string
    description*: string
    code*: string
    expectedResult*: string

proc generateUnitTest*(tmpl: UnitTestTemplate): string =
  ## Generate a unit test file from template
  result = "# Unit tests for " & tmpl.functionName & "\n"
  result.add "# Generated by nim-testkit\n\n"
  
  # Add imports
  if tmpl.imports.len > 0:
    for imp in tmpl.imports:
      result.add fmt"import {imp}" & "\n"
    result.add "\n"
  
  # Add test suite
  result.add fmt"""suite "{tmpl.functionName} tests":""" & "\n"
  
  # Add setup if needed
  if tmpl.setupCode.len > 0:
    result.add "  setup:\n"
    for line in tmpl.setupCode.splitLines():
      if line.len > 0:
        result.add "    " & line & "\n"
    result.add "\n"
  
  # Add teardown if needed
  if tmpl.teardownCode.len > 0:
    result.add "  teardown:\n"
    for line in tmpl.teardownCode.splitLines():
      if line.len > 0:
        result.add "    " & line & "\n"
    result.add "\n"
  
  # Add test cases
  for testCase in tmpl.testCases:
    result.add fmt"""  test "{testCase.name}":""" & "\n"
    if testCase.description.len > 0:
      result.add fmt"    # {testCase.description}" & "\n"
    
    # Add test code
    for line in testCase.code.splitLines():
      if line.len > 0:
        result.add "    " & line & "\n"
    
    # Add expected result check
    if testCase.expectedResult.len > 0:
      result.add fmt"    check result == {testCase.expectedResult}" & "\n"
    
    result.add "\n"

proc generateKernelFunctionTest*(funcName: string, modulePath: string): UnitTestTemplate =
  ## Generate test template for kernel functions
  result.moduleName = modulePath.extractFilename()
  result.functionName = funcName
  result.category = tcUnit
  result.imports = @[modulePath]
  
  # Add basic test cases
  result.testCases = @[
    TestCase(
      name: fmt"{funcName} with valid input",
      description: "Test normal operation",
      code: fmt"let result = {funcName}(validInput)",
      expectedResult: "expectedOutput"
    ),
    TestCase(
      name: fmt"{funcName} with invalid input",
      description: "Test error handling",
      code: fmt"""
expect ValueError:
  discard {funcName}(invalidInput)""",
      expectedResult: ""
    ),
    TestCase(
      name: fmt"{funcName} edge case",
      description: "Test boundary conditions",
      code: fmt"let result = {funcName}(edgeCase)",
      expectedResult: "edgeOutput"
    )
  ]

proc generateMemoryManagementTest*(funcName: string): UnitTestTemplate =
  ## Generate specialized tests for memory management functions
  result = generateKernelFunctionTest(funcName, "kernel/memory")
  result.setupCode = """
var allocator = initTestAllocator()
var initialMemory = getCurrentMemoryUsage()"""
  
  result.teardownCode = """
let finalMemory = getCurrentMemoryUsage()
check finalMemory <= initialMemory # No memory leaks"""
  
  # Add memory-specific test cases
  result.testCases.add TestCase(
    name: fmt"{funcName} memory leak test",
    description: "Ensure no memory leaks",
    code: fmt"""
for i in 0..<1000:
  let ptr = {funcName}(1024)
  check ptr != nil
  deallocate(ptr)""",
    expectedResult: ""
  )

proc generateCapabilityTest*(funcName: string): UnitTestTemplate =
  ## Generate tests for capability-based security functions
  result = generateKernelFunctionTest(funcName, "kernel/security/capabilities")
  
  # Add capability-specific test cases
  result.testCases = @[
    TestCase(
      name: fmt"{funcName} with valid capability",
      description: "Test authorized access",
      code: fmt"""
let cap = createCapability(READ_WRITE)
let result = {funcName}(cap, resource)""",
      expectedResult: "true"
    ),
    TestCase(
      name: fmt"{funcName} with invalid capability",
      description: "Test unauthorized access",
      code: fmt"""
let cap = createCapability(READ_ONLY)
expect CapabilityError:
  discard {funcName}(cap, resource)""",
      expectedResult: ""
    ),
    TestCase(
      name: fmt"{funcName} with revoked capability",
      description: "Test revoked access",
      code: fmt"""
let cap = createCapability(READ_WRITE)
revokeCapability(cap)
expect CapabilityError:
  discard {funcName}(cap, resource)""",
      expectedResult: ""
    )
  ]

proc saveUnitTest*(tmpl: UnitTestTemplate, outputDir: string) =
  ## Save generated test to appropriate directory
  let categoryDir = outputDir / "spec" / $tmpl.category
  createDir(categoryDir)
  
  let filename = categoryDir / fmt"test_{tmpl.functionName}.nim"
  let content = generateUnitTest(tmpl)
  writeFile(filename, content)
  
  echo fmt"Generated unit test: {filename}"

# Helper functions for analyzing functions to test
proc extractFunctionSignature*(code: string, funcName: string): tuple[params: seq[string], returnType: string] =
  ## Extract function parameters and return type from source code
  # Simple implementation - can be enhanced
  result.params = @[]
  result.returnType = "auto"
  
  # Look for proc definition
  let pattern = fmt"proc {funcName}\*?\("
  let startPos = code.find(pattern)
  if startPos >= 0:
    let endPos = code.find(")", startPos)
    if endPos > startPos:
      let paramsStr = code[startPos + pattern.len ..< endPos]
      # Parse parameters (simplified)
      for param in paramsStr.split(","):
        let parts = param.strip().split(":")
        if parts.len >= 1:
          result.params.add(parts[0].strip())

proc scanModuleForFunctions*(modulePath: string): seq[string] =
  ## Scan a module for testable functions
  result = @[]
  if fileExists(modulePath):
    let content = readFile(modulePath)
    for line in content.splitLines():
      if line.contains("proc ") and line.contains("*("):
        # Extract function name
        let startPos = line.find("proc ") + 5
        let endPos = line.find("*", startPos)
        if endPos > startPos:
          let funcName = line[startPos..<endPos].strip()
          result.add(funcName)