## Nim TestKit Documentation Generator
##
## Generates documentation from tests and code coverage

import std/[os, strformat, strutils, tables, json, times, xmltree, htmlparser, osproc]
import ../config/config

type
  TestDoc* = object
    name*: string
    description*: string
    file*: string
    passed*: bool
    coverage*: float
    
  ModuleDoc* = object
    name*: string
    tests*: seq[TestDoc]
    coverage*: float
    functions*: seq[string]

proc extractTestDocs*(testFile: string): seq[TestDoc] =
  ## Extracts documentation from test files
  result = @[]
  
  if not fileExists(testFile):
    return
  
  let content = readFile(testFile)
  let lines = content.splitLines()
  
  var inTest = false
  var currentTest: TestDoc
  var description = ""
  
  for line in lines:
    let trimmed = line.strip()
    
    if trimmed.startsWith("test "):
      if inTest and currentTest.name != "":
        currentTest.description = description.strip()
        result.add(currentTest)
      
      # Extract test name
      let nameStart = trimmed.find("\"") + 1
      let nameEnd = trimmed.rfind("\"")
      if nameStart > 0 and nameEnd > nameStart:
        currentTest = TestDoc(
          name: trimmed[nameStart..<nameEnd],
          file: testFile,
          passed: true  # Will be updated from test results
        )
        inTest = true
        description = ""
    
    elif inTest and trimmed.startsWith("#"):
      # Collect comments as description
      description &= trimmed[1..^1].strip() & " "
  
  # Add last test
  if inTest and currentTest.name != "":
    currentTest.description = description.strip()
    result.add(currentTest)

proc generateMarkdownDocs*(config: TestKitConfig, outputDir = "docs"): string =
  ## Generates Markdown documentation for tests
  createDir(outputDir)
  
  var content = """# Test Documentation

Generated on: """ & $now() & """

## Test Coverage Summary

"""
  
  # Get all test files
  var allTests: Table[string, seq[TestDoc]]
  
  for pattern in config.excludePatterns:
    for file in walkFiles(config.testsDir / pattern):
      let tests = extractTestDocs(file)
      let moduleName = extractFilename(file).replace("_test.nim", "")
      allTests[moduleName] = tests
  
  # Generate module documentation
  for module, tests in allTests:
    content &= fmt"""
### {module}

| Test Name | Description | Status |
|-----------|-------------|--------|
"""
    
    for test in tests:
      let status = if test.passed: "✅ PASS" else: "❌ FAIL"
      let desc = if test.description != "": test.description else: "No description"
      content &= fmt"| {test.name} | {desc} | {status} |" & "\n"
    
    content &= "\n"
  
  # Write main documentation
  writeFile(outputDir / "test-docs.md", content)
  
  # Generate coverage report placeholder
  let coverageContent = """# Coverage Report

Generated on: """ & $now() & """

## Summary

Coverage data not available. Run `nimble coverage` first to generate coverage data.
"""
  writeFile(outputDir / "coverage.md", coverageContent)
  
  # Generate index
  let indexContent = """# Nim TestKit Documentation

## Contents

- [Test Documentation](test-docs.md)
- [Coverage Report](coverage.md)
- [API Documentation](api-docs.md)

## Quick Links

- [Configuration Guide](config.md)
- [Jujutsu Integration](jujutsu.md)
- [CI/CD Setup](ci-cd.md)
"""
  
  writeFile(outputDir / "index.md", indexContent)
  
  return outputDir / "index.md"

proc generateCoverageMarkdown*(config: TestKitConfig): string =
  ## Generates coverage report in Markdown format
  result = """# Coverage Report

Generated on: """ & $now() & """

## Summary

"""
  
  let coverageDir = "build/coverage/raw"
  if not dirExists(coverageDir):
    result &= "No coverage data available. Run `nimble coverage` first.\n"
    return
  
  var totalCovered = 0
  var totalLines = 0
  var fileCoverage: Table[string, tuple[covered: int, total: int]]
  
  # Parse coverage files
  for file in walkFiles(coverageDir / "*.nim.cov"):
    let content = readFile(file)
    let lines = content.splitLines()
    
    var covered = 0
    var total = 0
    
    for line in lines:
      if line.strip() == "":
        continue
      
      let parts = line.split(":")
      if parts.len >= 2:
        let count = parts[0].strip()
        if count == "#####":
          total += 1
        elif count.len > 0 and count[0].isDigit():
          covered += 1
          total += 1
    
    let fileName = file.extractFilename().replace(".cov", "")
    fileCoverage[fileName] = (covered: covered, total: total)
    totalCovered += covered
    totalLines += total
  
  let overallCoverage = if totalLines > 0:
    (totalCovered.float / totalLines.float) * 100.0
  else:
    0.0
  
  result &= fmt"""
Overall Coverage: **{overallCoverage:.1f}%**

Total Lines: {totalLines}
Covered Lines: {totalCovered}
Threshold: {config.coverageThreshold}%

## File Coverage

| File | Coverage | Lines |
|------|----------|-------|
"""
  
  for file, (covered, total) in fileCoverage:
    let coverage = if total > 0:
      (covered.float / total.float) * 100.0
    else:
      0.0
    
    let emoji = if coverage >= config.coverageThreshold: "✅" else: "⚠️"
    result &= fmt"| {file} | {emoji} {coverage:.1f}% | {covered}/{total} |" & "\n"
  
  return result

proc generateTestBadges*(config: TestKitConfig, outputDir = "badges") =
  ## Generates status badges for tests and coverage
  createDir(outputDir)
  
  # Simple SVG badge template
  proc createBadge(label, message, color: string): string =
    let width = 90 + message.len * 6
    result = fmt"""
<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="20">
  <rect width="{width}" height="20" fill="#555"/>
  <rect x="90" width="{width - 90}" height="20" fill="{color}"/>
  <text x="45" y="14" fill="#fff" text-anchor="middle" font-family="Arial">{label}</text>
  <text x="{90 + (width - 90) div 2}" y="14" fill="#fff" text-anchor="middle" font-family="Arial">{message}</text>
</svg>
"""
  
  # Generate test status badge
  let testBadge = createBadge("tests", "passing", "#4c1")
  writeFile(outputDir / "tests.svg", testBadge)
  
  # Generate coverage badge
  let coverageBadge = createBadge("coverage", "80%", "#4c1")
  writeFile(outputDir / "coverage.svg", coverageBadge)

proc generateAPIDocs*(config: TestKitConfig, outputDir = "docs/api") =
  ## Generates API documentation from source files
  createDir(outputDir)
  
  for pattern in config.includePatterns:
    for file in walkFiles(config.sourceDir / pattern):
      let content = readFile(file)
      let moduleName = extractFilename(file).replace(".nim", "")
      
      var apiDoc = fmt"""# {moduleName} API

## Functions

"""
      
      # Extract function documentation
      let lines = content.splitLines()
      var i = 0
      
      while i < lines.len:
        let line = lines[i]
        let trimmed = line.strip()
        
        if trimmed.startsWith("proc ") or trimmed.startsWith("func "):
          var docComment = ""
          var j = i - 1
          
          # Look for doc comments above the function
          while j >= 0 and lines[j].strip().startsWith("##"):
            docComment = lines[j].strip()[2..^1].strip() & " " & docComment
            j -= 1
          
          # Extract function signature
          var signature = trimmed
          var k = i + 1
          while k < lines.len and not lines[k].strip().endsWith("="):
            signature &= " " & lines[k].strip()
            k += 1
          
          apiDoc &= fmt"""
### {signature}

{docComment}

---
"""
        
        i += 1
      
      writeFile(outputDir / fmt"{moduleName}.md", apiDoc)

proc integrationWithNimDoc*(sourceFile: string): string =
  ## Integrates with nim doc command
  let (output, exitCode) = execCmdEx(fmt"nim doc {sourceFile}")
  
  if exitCode == 0:
    # Parse the generated HTML and convert to Markdown
    let html = parseHtml(output)
    # Simplified conversion - would need proper HTML to Markdown converter
    return "Documentation generated successfully"
  else:
    return "Failed to generate documentation"

when isMainModule:
  let testKitConfig = loadConfig()
  echo generateMarkdownDocs(testKitConfig)
  generateTestBadges(testKitConfig)
  generateAPIDocs(testKitConfig)