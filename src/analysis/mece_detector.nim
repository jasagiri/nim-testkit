# MECE (Mutually Exclusive, Collectively Exhaustive) test structure detection
# Zero external dependencies - uses only Nim stdlib

import std/[os, strutils, tables, sets, strformat]
import ../core/types

type
  MECEStructure* = object
    rootPath*: string
    categories*: Table[TestCategory, seq[string]]
    customCategories*: Table[string, seq[string]]
    overlaps*: seq[tuple[file: string, categories: seq[string]]]
    missing*: seq[string]
    
  MECEReport* = object
    isValid*: bool
    structure*: MECEStructure
    violations*: seq[string]
    suggestions*: seq[string]
    stats*: MECEStats
    
  MECEStats* = object
    totalFiles: int
    categorizedFiles: int
    uncategorizedFiles: int
    filesPerCategory: Table[string, int]

# Standard MECE paths for test organization
const
  StandardPaths = {
    tcUnit: @["unit", "units"],
    tcIntegration: @["integration", "integrations"],
    tcSystem: @["system", "systems", "e2e", "end-to-end"],
    tcPerformance: @["performance", "perf", "benchmark", "benchmarks"]
  }.toTable
  
  TestFilePatterns = @["test*.nim", "*test.nim", "*tests.nim", "t_*.nim"]
  SpecDirs = @["spec", "specs", "test", "tests"]

proc initMECEStructure*(rootPath: string): MECEStructure =
  MECEStructure(
    rootPath: rootPath,
    categories: initTable[TestCategory, seq[string]](),
    customCategories: initTable[string, seq[string]](),
    overlaps: @[],
    missing: @[]
  )

proc normalizeCategory(path: string): string =
  # Extract category from path like /tests/spec/unit/test_foo.nim -> unit
  let parts = path.split({'/', '\\'})
  for part in parts:
    for category, patterns in StandardPaths:
      if part.toLowerAscii in patterns:
        return $category
    # Check for custom categories
    if part.startsWith("test") and part.len > 4:
      let custom = part[4..^1].toLowerAscii
      if custom.len > 0 and custom[0].isAlphaAscii:
        return custom
  return ""

proc detectTestFiles(rootPath: string): seq[string] =
  var files: seq[string] = @[]
  
  proc walkTestDirs(dir: string, files: var seq[string]) =
    if not dirExists(dir):
      return
      
    # Check if this is a test directory
    let dirName = dir.splitPath.tail.toLowerAscii
    let isTestDir = dirName in SpecDirs or dirName.startsWith("test")
    
    # Look for test files
    for pattern in TestFilePatterns:
      for file in walkFiles(dir / pattern):
        files.add(file)
    
    # Recurse into subdirectories
    for subdir in walkDirs(dir / "*"):
      walkTestDirs(subdir, files)
  
  walkTestDirs(rootPath, files)
  result = files

proc analyzeStructure*(rootPath: string): MECEStructure =
  result = initMECEStructure(rootPath)
  
  let testFiles = detectTestFiles(rootPath)
  var categorized = initHashSet[string]()
  var categoryFiles = initTable[string, seq[string]]()
  
  # Categorize files
  for file in testFiles:
    let relPath = file.relativePath(rootPath)
    let category = normalizeCategory(relPath)
    
    if category.len > 0:
      if category notin categoryFiles:
        categoryFiles[category] = @[]
      categoryFiles[category].add(file)
      categorized.incl(file)
  
  # Convert to proper structure
  for cat, files in categoryFiles:
    # Try to match standard categories
    var matched = false
    for tc, _ in StandardPaths:
      if cat == $tc:
        result.categories[tc] = files
        matched = true
        break
    
    if not matched:
      result.customCategories[cat] = files
  
  # Find uncategorized files
  for file in testFiles:
    if file notin categorized:
      result.missing.add(file)
  
  # Detect overlaps (files that could belong to multiple categories)
  for file in testFiles:
    let relPath = file.relativePath(rootPath)
    var possibleCategories: seq[string] = @[]
    
    for category, patterns in StandardPaths:
      for pattern in patterns:
        if pattern in relPath.toLowerAscii:
          possibleCategories.add($category)
    
    if possibleCategories.len > 1:
      result.overlaps.add((file: file, categories: possibleCategories))

proc validateMECE*(structure: MECEStructure): MECEReport =
  result.structure = structure
  result.isValid = true
  result.violations = @[]
  result.suggestions = @[]
  result.stats = MECEStats(
    filesPerCategory: initTable[string, int]()
  )
  
  # Calculate stats
  var allFiles = initHashSet[string]()
  
  for cat, files in structure.categories:
    result.stats.filesPerCategory[$cat] = files.len
    for f in files:
      allFiles.incl(f)
  
  for cat, files in structure.customCategories:
    result.stats.filesPerCategory[cat] = files.len
    for f in files:
      allFiles.incl(f)
  
  result.stats.totalFiles = allFiles.len + structure.missing.len
  result.stats.categorizedFiles = allFiles.len
  result.stats.uncategorizedFiles = structure.missing.len
  
  # Check for violations
  if structure.missing.len > 0:
    result.isValid = false
    result.violations.add(fmt"Found {structure.missing.len} uncategorized test files")
    result.suggestions.add("Move test files into category subdirectories (unit/, integration/, system/)")
  
  if structure.overlaps.len > 0:
    result.isValid = false
    result.violations.add(fmt"Found {structure.overlaps.len} files with ambiguous categories")
    for overlap in structure.overlaps:
      result.suggestions.add(fmt"Clarify category for {overlap.file}")
  
  # Check for proper distribution
  if result.stats.categorizedFiles > 0:
    for cat, count in result.stats.filesPerCategory:
      let percentage = count.float / result.stats.categorizedFiles.float * 100
      if percentage > 80:
        result.suggestions.add(fmt"Category '{cat}' contains {percentage:.1f}% of tests - consider more granular organization")
  
  # Check for empty categories
  let expectedCategories = @["unit", "integration", "system"]
  for cat in expectedCategories:
    if cat notin result.stats.filesPerCategory or result.stats.filesPerCategory[cat] == 0:
      result.suggestions.add(fmt"No {cat} tests found - consider adding {cat} tests")

proc printMECEReport*(report: MECEReport) =
  echo "\nMECE Test Structure Analysis"
  echo "=".repeat(60)
  
  echo fmt"Total test files: {report.stats.totalFiles}"
  echo fmt"Categorized: {report.stats.categorizedFiles}"
  echo fmt"Uncategorized: {report.stats.uncategorizedFiles}"
  
  echo "\nCategories:"
  for cat, count in report.stats.filesPerCategory:
    let percentage = count.float / report.stats.totalFiles.float * 100
    echo fmt"  {cat}: {count} files ({percentage:.1f}%)"
  
  if report.violations.len > 0:
    echo "\nViolations:"
    for violation in report.violations:
      echo fmt"  ⚠ {violation}"
  
  if report.suggestions.len > 0:
    echo "\nSuggestions:"
    for suggestion in report.suggestions:
      echo fmt"  → {suggestion}"
  
  echo "\nMECE Compliance: ", if report.isValid: "✓ VALID" else: "✗ INVALID"
  echo "=".repeat(60)

proc generateMECEStructure*(rootPath: string, categories: seq[string] = @["unit", "integration", "system"]) =
  ## Generate a MECE-compliant test directory structure
  let testRoot = rootPath / "tests"
  let specRoot = testRoot / "spec"
  
  # Create base directories
  createDir(testRoot)
  createDir(specRoot)
  
  # Create category directories
  for category in categories:
    createDir(specRoot / category)
  
  # Create support directories
  createDir(testRoot / "support")
  createDir(testRoot / "support" / "fixtures")
  createDir(testRoot / "support" / "helpers")
  createDir(testRoot / "support" / "mocks")
  
  # Create example test files
  for category in categories:
    let exampleFile = specRoot / category / fmt"test_example_{category}.nim"
    if not fileExists(exampleFile):
      writeFile(exampleFile, fmt"""
# Example {category} test
import unittest

suite "{category} tests":
  test "example {category} test":
    check true
""")
  
  echo fmt"Generated MECE test structure at {testRoot}"

# Convenience function
proc analyzeMECE*(path: string = getCurrentDir()): MECEReport =
  let structure = analyzeStructure(path)
  result = validateMECE(structure)