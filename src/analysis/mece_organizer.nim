## MECE Test Organizer for Nim TestKit
##
## Provides MECE (Mutually Exclusive, Collectively Exhaustive) test organization
## capabilities. Automatically categorizes tests and detects organizational issues.

import std/[os, strutils, sequtils, tables, sets, algorithm, strformat]

type
  TestCategory* = enum
    ## MECE test categories
    tcUnit = "unit"           # Single function/module tests
    tcIntegration = "integration"  # Multi-module interaction tests
    tcSystem = "system"       # End-to-end system tests
    tcPerformance = "performance"  # Benchmark and performance tests
    tcSecurity = "security"   # Security-specific tests
    tcRegression = "regression"    # Regression prevention tests
    tcSmoke = "smoke"         # Quick sanity check tests
    tcAcceptance = "acceptance"    # User acceptance tests
    tcContract = "contract"   # API contract tests
    tcProperty = "property"   # Property-based tests
    tcUncategorized = "uncategorized"  # Fallback category

  TestFile* = object
    path*: string
    category*: TestCategory
    confidence*: float  # 0.0-1.0 confidence in categorization
    reasons*: seq[string]  # Why it was categorized this way
    dependencies*: seq[string]  # Detected dependencies
    functions*: seq[string]  # Test function names
    
  MECEAnalysis* = object
    categories*: Table[TestCategory, seq[TestFile]]
    violations*: seq[string]  # MECE violations found
    suggestions*: seq[string]  # Improvement suggestions
    coverage*: Table[TestCategory, int]  # Count per category
    duplicates*: seq[tuple[file1, file2: string, reason: string]]
    gaps*: seq[string]  # Missing coverage areas

proc detectTestCategory*(filePath: string): tuple[category: TestCategory, confidence: float, reasons: seq[string]] =
  ## Detects the most likely category for a test file
  let content = readFile(filePath)
  let fileName = extractFilename(filePath).toLowerAscii()
  let baseName = fileName.replace("_test.nim", "").replace("test_", "")
  
  var scores: Table[TestCategory, float]
  var reasons: Table[TestCategory, seq[string]]
  
  # Initialize scores
  for category in TestCategory:
    scores[category] = 0.0
    reasons[category] = @[]
  
  # File name patterns
  if "unit" in fileName:
    scores[tcUnit] += 0.8
    reasons[tcUnit].add("filename contains 'unit'")
  elif "integration" in fileName:
    scores[tcIntegration] += 0.8
    reasons[tcIntegration].add("filename contains 'integration'")
  elif "system" in fileName:
    scores[tcSystem] += 0.8
    reasons[tcSystem].add("filename contains 'system'")
  elif "performance" in fileName or "bench" in fileName:
    scores[tcPerformance] += 0.8
    reasons[tcPerformance].add("filename suggests performance testing")
  elif "security" in fileName or "sec" in fileName:
    scores[tcSecurity] += 0.8
    reasons[tcSecurity].add("filename suggests security testing")
  elif "regression" in fileName:
    scores[tcRegression] += 0.8
    reasons[tcRegression].add("filename contains 'regression'")
  elif "smoke" in fileName:
    scores[tcSmoke] += 0.8
    reasons[tcSmoke].add("filename contains 'smoke'")
  elif "acceptance" in fileName or "accept" in fileName:
    scores[tcAcceptance] += 0.8
    reasons[tcAcceptance].add("filename suggests acceptance testing")
  elif "contract" in fileName:
    scores[tcContract] += 0.8
    reasons[tcContract].add("filename contains 'contract'")
  elif "property" in fileName or "prop" in fileName:
    scores[tcProperty] += 0.8
    reasons[tcProperty].add("filename suggests property-based testing")
  
  # Content analysis
  let lines = content.splitLines()
  for line in lines:
    let trimmed = line.strip().toLowerAscii()
    
    # Import patterns suggest scope
    if trimmed.startsWith("import ") and " / " in trimmed:
      scores[tcIntegration] += 0.3
      reasons[tcIntegration].add("imports multiple modules")
    elif trimmed.startsWith("import ") and ("unittest" in trimmed or "std/unittest" in trimmed):
      scores[tcUnit] += 0.2
      reasons[tcUnit].add("uses unittest framework")
    
    # Test naming patterns
    if "benchmark" in trimmed or "bench_" in trimmed:
      scores[tcPerformance] += 0.4
      reasons[tcPerformance].add("contains benchmark tests")
    elif "test_single" in trimmed or "test_isolated" in trimmed:
      scores[tcUnit] += 0.3
      reasons[tcUnit].add("tests isolated functionality")
    elif "test_end_to_end" in trimmed or "test_e2e" in trimmed:
      scores[tcSystem] += 0.4
      reasons[tcSystem].add("contains end-to-end tests")
    elif "test_interaction" in trimmed or "test_communication" in trimmed:
      scores[tcIntegration] += 0.4
      reasons[tcIntegration].add("tests component interactions")
    
    # Process/command execution suggests system tests
    if "execCmd" in trimmed or "osproc" in trimmed:
      scores[tcSystem] += 0.3
      reasons[tcSystem].add("executes external commands")
    
    # Network/file operations suggest integration
    if "http" in trimmed or "socket" in trimmed or "network" in trimmed:
      scores[tcIntegration] += 0.3
      reasons[tcIntegration].add("involves network operations")
    
    # Performance-related keywords
    let perfKeywords = ["time", "duration", "speed", "memory", "cpu"]
    if perfKeywords.anyIt(it in trimmed):
      scores[tcPerformance] += 0.2
      reasons[tcPerformance].add("measures performance metrics")
    
    # Security-related keywords
    let secKeywords = ["auth", "permission", "secure", "crypto", "hash"]
    if secKeywords.anyIt(it in trimmed):
      scores[tcSecurity] += 0.3
      reasons[tcSecurity].add("tests security features")
  
  # Path-based hints
  let pathParts = filePath.split(DirSep)
  for part in pathParts:
    case part.toLowerAscii():
    of "unit":
      scores[tcUnit] += 0.5
      reasons[tcUnit].add("located in unit test directory")
    of "integration":
      scores[tcIntegration] += 0.5
      reasons[tcIntegration].add("located in integration test directory")
    of "system":
      scores[tcSystem] += 0.5
      reasons[tcSystem].add("located in system test directory")
    of "performance", "bench", "benchmarks":
      scores[tcPerformance] += 0.5
      reasons[tcPerformance].add("located in performance test directory")
    of "security":
      scores[tcSecurity] += 0.5
      reasons[tcSecurity].add("located in security test directory")
  
  # Find best category
  let maxScore = max(toSeq(scores.values()))
  if maxScore < 0.1:
    return (tcUncategorized, 0.0, @["no clear category indicators found"])
  
  for category, score in scores.pairs():
    if score == maxScore:
      return (category, score, reasons[category])
  
  return (tcUncategorized, 0.0, @["classification failed"])

proc extractTestFunctions*(content: string): seq[string] =
  ## Extracts test function names from file content
  result = @[]
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("test ") and trimmed.endsWith(":"):
      let testName = trimmed[5..^2].strip()
      if testName.len > 0:
        result.add(testName)
    elif trimmed.startsWith("proc test") and "(" in trimmed:
      let procName = trimmed.split("(")[0].replace("proc ", "").strip()
      if procName.len > 0:
        result.add(procName)

proc detectDependencies*(content: string): seq[string] =
  ## Detects module dependencies from imports
  result = @[]
  for line in content.splitLines():
    let trimmed = line.strip()
    if trimmed.startsWith("import "):
      let imports = trimmed[7..^1].split(",")
      for imp in imports:
        let clean = imp.strip()
        if clean.len > 0 and not clean.startsWith("std/"):
          result.add(clean)

proc analyzeTestFile*(filePath: string): TestFile =
  ## Performs complete analysis of a test file
  let content = readFile(filePath)
  let (category, confidence, reasons) = detectTestCategory(filePath)
  
  result = TestFile(
    path: filePath,
    category: category,
    confidence: confidence,
    reasons: reasons,
    dependencies: detectDependencies(content),
    functions: extractTestFunctions(content)
  )

proc findMECEViolations*(testFiles: seq[TestFile]): seq[string] =
  ## Finds MECE principle violations
  result = @[]
  var functionNames: Table[string, seq[string]]  # function -> files
  var pathOverlaps: Table[string, seq[TestFile]]  # base name -> files
  
  # Check for duplicate test functions (non-exclusive)
  for file in testFiles:
    for funcName in file.functions:
      if funcName notin functionNames:
        functionNames[funcName] = @[]
      functionNames[funcName].add(file.path)
  
  for funcName, files in functionNames.pairs():
    if files.len > 1:
      let joinedFiles = files.join(", ")
      result.add(fmt"Duplicate test function '{funcName}' found in: {joinedFiles}")
  
  # Check for path overlaps
  for file in testFiles:
    let baseName = extractFilename(file.path).replace("_test.nim", "").replace("test_", "")
    if baseName notin pathOverlaps:
      pathOverlaps[baseName] = @[]
    pathOverlaps[baseName].add(file)
  
  for baseName, files in pathOverlaps.pairs():
    if files.len > 1:
      let paths = files.mapIt(it.path)
      let joinedPaths = paths.join(", ")
      result.add(fmt"Multiple test files for '{baseName}': {joinedPaths} - may violate mutual exclusivity")
  
  # Check for uncategorized tests
  let uncategorized = testFiles.filterIt(it.category == tcUncategorized)
  if uncategorized.len > 0:
    let uncategorizedPaths = uncategorized.mapIt(it.path).join(", ")
    result.add(fmt"{uncategorized.len} test files are uncategorized: {uncategorizedPaths}")

proc generateMECESuggestions*(analysis: MECEAnalysis): seq[string] =
  ## Generates suggestions for improving MECE compliance
  result = @[]
  
  # Suggest reorganization for large uncategorized groups
  let uncategorizedCount = analysis.coverage.getOrDefault(tcUncategorized, 0)
  if uncategorizedCount > 3:
    result.add(fmt"Consider organizing {uncategorizedCount} uncategorized tests into proper categories")
  
  # Suggest missing categories
  let presentCategories = toSeq(analysis.coverage.keys()).filterIt(analysis.coverage[it] > 0)
  if tcUnit notin presentCategories:
    result.add("Consider adding unit tests for individual function testing")
  if tcIntegration notin presentCategories:
    result.add("Consider adding integration tests for module interactions")
  if tcSystem notin presentCategories and presentCategories.len > 2:
    result.add("Consider adding system tests for end-to-end verification")
  
  # Suggest balance improvements
  let totalTests = toSeq(analysis.coverage.values()).foldl(a + b, 0)
  let unitTests = analysis.coverage.getOrDefault(tcUnit, 0)
  if totalTests > 0 and float(unitTests) / float(totalTests) < 0.3:
    result.add("Consider adding more unit tests (currently < 30% of total)")
  
  # Suggest duplicate resolution
  if analysis.duplicates.len > 0:
    result.add(fmt"Resolve {analysis.duplicates.len} duplicate test issues for better organization")

proc performMECEAnalysis*(testDirectory: string): MECEAnalysis =
  ## Performs complete MECE analysis on a test directory
  result = MECEAnalysis()
  result.categories = initTable[TestCategory, seq[TestFile]]()
  result.coverage = initTable[TestCategory, int]()
  
  # Initialize categories
  for category in TestCategory:
    result.categories[category] = @[]
    result.coverage[category] = 0
  
  # Find and analyze all test files
  var allTestFiles: seq[TestFile] = @[]
  for file in walkDirRec(testDirectory):
    if file.endsWith(".nim") and ("test" in extractFilename(file).toLowerAscii()):
      let analyzed = analyzeTestFile(file)
      allTestFiles.add(analyzed)
      result.categories[analyzed.category].add(analyzed)
      result.coverage[analyzed.category] += 1
  
  # Find violations
  result.violations = findMECEViolations(allTestFiles)
  
  # Generate suggestions
  result.suggestions = generateMECESuggestions(result)
  
  # Find duplicates (more detailed analysis)
  result.duplicates = @[]
  for i, file1 in allTestFiles:
    for j in (i+1)..<allTestFiles.len:
      let file2 = allTestFiles[j]
      # Check for potential duplicates
      let commonFunctions = toSeq(file1.functions.toHashSet() * file2.functions.toHashSet())
      if commonFunctions.len > 0:
        let joinedFunctions = commonFunctions.join(", ")
        result.duplicates.add((file1.path, file2.path, fmt"Common functions: {joinedFunctions}"))
  
  # Identify gaps (simplified)
  result.gaps = @[]
  if result.coverage[tcUnit] == 0:
    result.gaps.add("No unit tests found")
  if result.coverage[tcIntegration] == 0 and result.coverage[tcUnit] > 0:
    result.gaps.add("No integration tests found despite having unit tests")

proc printMECEReport*(analysis: MECEAnalysis) =
  ## Prints a formatted MECE analysis report
  echo "===== MECE Test Organization Analysis ====="
  echo ""
  
  # Category distribution
  echo "Test Category Distribution:"
  for category in TestCategory:
    let count = analysis.coverage[category]
    if count > 0:
      echo fmt"  {category}: {count} tests"
      for file in analysis.categories[category]:
        let confidence = fmt"{file.confidence:.1f}"
        echo fmt"    - {file.path} (confidence: {confidence})"
  echo ""
  
  # Violations
  if analysis.violations.len > 0:
    echo "MECE Violations Found:"
    for violation in analysis.violations:
      echo fmt"  ⚠ {violation}"
    echo ""
  
  # Duplicates
  if analysis.duplicates.len > 0:
    echo "Potential Duplicates:"
    for (file1, file2, reason) in analysis.duplicates:
      echo fmt"  🔄 {file1} ↔ {file2}: {reason}"
    echo ""
  
  # Gaps
  if analysis.gaps.len > 0:
    echo "Coverage Gaps:"
    for gap in analysis.gaps:
      echo fmt"  📋 {gap}"
    echo ""
  
  # Suggestions
  if analysis.suggestions.len > 0:
    echo "Improvement Suggestions:"
    for suggestion in analysis.suggestions:
      echo fmt"  💡 {suggestion}"
    echo ""
  
  echo "===== End of MECE Analysis ====="

proc createMECEDirectoryStructure*(baseDir: string) =
  ## Creates a MECE-compliant directory structure for tests
  let dirs = [
    baseDir / "spec" / "unit",
    baseDir / "spec" / "integration", 
    baseDir / "spec" / "system",
    baseDir / "spec" / "performance",
    baseDir / "spec" / "security",
    baseDir / "spec" / "regression",
    baseDir / "spec" / "smoke",
    baseDir / "spec" / "acceptance",
    baseDir / "spec" / "contract",
    baseDir / "spec" / "property",
    baseDir / "support" / "fixtures",
    baseDir / "support" / "helpers",
    baseDir / "support" / "mocks",
    baseDir / "_config",
    baseDir / "_archive"
  ]
  
  for dir in dirs:
    createDir(dir)
    echo fmt"Created: {dir}"

proc suggestTestReorganization*(analysis: MECEAnalysis, targetDir: string): seq[string] =
  ## Suggests specific file moves for better MECE organization
  result = @[]
  
  for category in TestCategory:
    if category == tcUncategorized:
      continue
      
    let targetSubdir = targetDir / "spec" / $category
    for file in analysis.categories[category]:
      let fileName = extractFilename(file.path)
      let newPath = targetSubdir / fileName
      if file.confidence > 0.5:  # Only suggest confident moves
        let reasonsStr = file.reasons.join("; ")
        result.add(fmt"mv {file.path} {newPath}  # {reasonsStr}")

when isMainModule:
  import std/parseopt
  
  var testDir = "tests"
  var createStructure = false
  var showHelp = false
  
  for kind, key, value in getopt():
    case kind:
    of cmdArgument:
      testDir = key
    of cmdLongOption, cmdShortOption:
      case key:
      of "dir", "d":
        testDir = value
      of "create", "c":
        createStructure = true
      of "help", "h":
        showHelp = true
      else:
        echo "Unknown option: " & key
        quit(1)
    of cmdEnd:
      break
  
  if showHelp:
    echo """MECE Test Organizer

Usage: mece_test_organizer [options] [test_directory]

Options:
  -d, --dir DIR     Test directory to analyze (default: tests)
  -c, --create      Create MECE directory structure
  -h, --help        Show this help

Examples:
  mece_test_organizer                    # Analyze tests/ directory
  mece_test_organizer my_tests           # Analyze my_tests/ directory  
  mece_test_organizer -c tests           # Create MECE structure in tests/
"""
    quit(0)
  
  if createStructure:
    echo "Creating MECE directory structure..."
    createMECEDirectoryStructure(testDir)
    echo "MECE structure created successfully!"
  else:
    if not dirExists(testDir):
      echo fmt"Error: Test directory '{testDir}' not found"
      quit(1)
    
    echo fmt"Analyzing test directory: {testDir}"
    let analysis = performMECEAnalysis(testDir)
    printMECEReport(analysis)
    
    echo ""
    echo "Reorganization suggestions:"
    let suggestions = suggestTestReorganization(analysis, testDir)
    for suggestion in suggestions:
      echo suggestion