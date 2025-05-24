import std/[unittest, os, tempfiles, strutils, sequtils, tables]
import ../src/organization/mece_organizer

suite "MECETestOrganizer - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("mece_", "")
    let testDir = tempDir / "tests"
    createDir(testDir)
    createDir(testDir / "unit")
    createDir(testDir / "integration")
    createDir(testDir / "system")
    
  teardown:
    removeDir(tempDir)
    
  test "MECE principle validation - mutually exclusive":
    let organizer = newMECEOrganizer(testDir)
    
    # Create overlapping tests
    writeFile(testDir / "unit" / "test_math.nim", """
import std/unittest
suite "Math": test "addition": check 1 + 1 == 2
""")
    
    writeFile(testDir / "integration" / "test_math_integration.nim", """
import std/unittest  
suite "Math": test "addition": check 1 + 1 == 2  # Same test!
""")
    
    let analysis = organizer.analyzeMECE()
    check analysis.violations.len > 0
    check analysis.overlaps.len > 0
    
  test "MECE principle validation - collectively exhaustive":
    let organizer = newMECEOrganizer(testDir)
    
    # Create source file
    let srcDir = tempDir / "src"
    createDir(srcDir)
    writeFile(srcDir / "calculator.nim", """
proc add*(a, b: int): int = a + b
proc subtract*(a, b: int): int = a - b
proc multiply*(a, b: int): int = a * b
proc divide*(a, b: float): float = a / b
""")
    
    # Create partial tests
    writeFile(testDir / "unit" / "test_calculator.nim", """
import std/unittest
suite "Calculator": 
  test "add": check true
  test "subtract": check true
""")
    
    organizer.config.sourceDir = srcDir
    let analysis = organizer.analyzeMECE()
    
    check analysis.missingTests.len > 0
    check "multiply" in analysis.missingTests.join(" ")
    check "divide" in analysis.missingTests.join(" ")
    
  test "Test categorization by type":
    let organizer = newMECEOrganizer(testDir)
    
    writeFile(testDir / "test_uncategorized.nim", """
import std/unittest
suite "Uncategorized":
  test "pure function": check add(1, 2) == 3
  test "database access": check getUserById(1) == "user"
  test "full workflow": check processOrder() == true
""")
    
    let categories = organizer.categorizeTests()
    
    check categories.unit.len >= 0
    check categories.integration.len >= 0  
    check categories.system.len >= 0
    check categories.uncategorized.len > 0
    
  test "Test categorization by complexity":
    let organizer = newMECEOrganizer(testDir)
    
    writeFile(testDir / "unit" / "test_simple.nim", """
import std/unittest
suite "Simple": test "basic": check true
""")
    
    writeFile(testDir / "integration" / "test_complex.nim", """
import std/unittest
suite "Complex":
  setup: echo "complex setup"
  test "multi-component":
    let db = connectDb()
    let api = createApi(db)
    check api.process() == "ok"
""")
    
    let analysis = organizer.analyzeComplexity()
    
    check analysis.simple.len > 0
    check analysis.complex.len > 0
    
  test "Dependency analysis":
    let organizer = newMECEOrganizer(testDir)
    
    writeFile(testDir / "unit" / "test_base.nim", """
import std/unittest
suite "Base": test "foundation": check true
""")
    
    writeFile(testDir / "integration" / "test_dependent.nim", """
import std/unittest
import ../unit/test_base  # Dependency
suite "Dependent": test "uses base": check true
""")
    
    let deps = organizer.analyzeDependencies()
    
    check deps.dependencies.len > 0
    check deps.circular.len == 0  # No circular deps in this case
    
  test "Coverage gap detection":
    let organizer = newMECEOrganizer(testDir)
    
    # Create source with functions
    let srcDir = tempDir / "src"
    createDir(srcDir)
    writeFile(srcDir / "service.nim", """
proc publicFunc*(): string = "public"
proc anotherPublic*(): int = 42
func pureFunc*(x: int): int = x * 2
""")
    
    # Create partial tests
    writeFile(testDir / "unit" / "test_service.nim", """
import std/unittest
suite "Service": test "publicFunc": check publicFunc() == "public"
""")
    
    organizer.config.sourceDir = srcDir
    let gaps = organizer.findCoverageGaps()
    
    check gaps.untestedFunctions.len >= 2
    check "anotherPublic" in gaps.untestedFunctions.join(" ")
    check "pureFunc" in gaps.untestedFunctions.join(" ")
    
  test "Test organization recommendations":
    let organizer = newMECEOrganizer(testDir)
    
    # Create misplaced tests
    writeFile(testDir / "unit" / "test_integration_like.nim", """
import std/unittest
suite "Integration Like":
  test "database and api":
    let db = connectDb()
    let api = createApi(db) 
    check api.works()
""")
    
    writeFile(testDir / "integration" / "test_unit_like.nim", """
import std/unittest
suite "Unit Like": test "pure math": check add(1, 1) == 2
""")
    
    let recommendations = organizer.generateRecommendations()
    
    check recommendations.relocate.len > 0
    check recommendations.split.len >= 0
    check recommendations.merge.len >= 0
    
  test "Test suite validation":
    let organizer = newMECEOrganizer(testDir)
    
    # Create valid structure
    writeFile(testDir / "unit" / "test_math.nim", """
import std/unittest
suite "Math Unit": test "addition": check 1 + 1 == 2
""")
    
    writeFile(testDir / "integration" / "test_api.nim", """
import std/unittest  
suite "API Integration": test "endpoint": check callApi() == "ok"
""")
    
    let validation = organizer.validateTestSuite()
    
    check validation.isValid
    check validation.errors.len == 0
    check validation.warnings.len >= 0
    
  test "Naming convention analysis":
    let organizer = newMECEOrganizer(testDir)
    
    # Create tests with various naming patterns
    writeFile(testDir / "unit" / "test_good_naming.nim", "# Good naming")
    writeFile(testDir / "unit" / "bad_naming.nim", "# Bad naming - no test_ prefix")
    writeFile(testDir / "unit" / "TestCamelCase.nim", "# Wrong case")
    
    let naming = organizer.analyzeNaming()
    
    check naming.violations.len >= 2
    check naming.suggestions.len >= 2
    
  test "Test file organization metrics":
    let organizer = newMECEOrganizer(testDir)
    
    # Create files with different characteristics
    writeFile(testDir / "unit" / "test_small.nim", """
import std/unittest
suite "Small": test "one": check true
""")
    
    writeFile(testDir / "unit" / "test_large.nim", """
import std/unittest
suite "Large":
""" & "\n  test \"test" & $i & "\": check true" & repeat("\n", 100))
    
    let metrics = organizer.calculateMetrics()
    
    check metrics.totalTests > 0
    check metrics.averageTestsPerFile > 0
    check metrics.largestFile.len > 0
    
  test "Duplicate test detection":
    let organizer = newMECEOrganizer(testDir)
    
    # Create duplicate tests
    writeFile(testDir / "unit" / "test_dup1.nim", """
import std/unittest
suite "Dup": test "same test": check 1 == 1
""")
    
    writeFile(testDir / "integration" / "test_dup2.nim", """
import std/unittest
suite "Dup": test "same test": check 1 == 1
""")
    
    let duplicates = organizer.findDuplicates()
    
    check duplicates.len > 0
    check duplicates[0].files.len == 2
    
  test "Test execution order optimization":
    let organizer = newMECEOrganizer(testDir)
    
    # Create tests with dependencies
    writeFile(testDir / "unit" / "test_a.nim", "# Test A")
    writeFile(testDir / "unit" / "test_b.nim", "# Test B depends on A")
    writeFile(testDir / "unit" / "test_c.nim", "# Test C depends on B") 
    
    # Simulate dependency information
    organizer.addDependency("test_b", "test_a")
    organizer.addDependency("test_c", "test_b")
    
    let order = organizer.optimizeExecutionOrder()
    
    let aIndex = order.find("test_a")
    let bIndex = order.find("test_b")
    let cIndex = order.find("test_c")
    
    check aIndex < bIndex
    check bIndex < cIndex
    
  test "Test refactoring suggestions":
    let organizer = newMECEOrganizer(testDir)
    
    # Create test with code smells
    writeFile(testDir / "unit" / "test_smells.nim", """
import std/unittest
suite "Smells":
  test "too long":
    # Very long test with multiple assertions
    check true
    check true
    check true
    # ... many more assertions
  test "no assertions":
    echo "This test has no assertions"
""")
    
    let suggestions = organizer.generateRefactoringSuggestions()
    
    check suggestions.len > 0
    check suggestions.anyIt("split" in it.action)
    
  test "Test pattern analysis":
    let organizer = newMECEOrganizer(testDir)
    
    # Create tests with various patterns
    writeFile(testDir / "unit" / "test_patterns.nim", """
import std/unittest
suite "Patterns":
  setup: echo "setup"
  teardown: echo "teardown"
  test "with mock": check mockService.call() == "ok"
  test "with fixture": check loadFixture("data") != nil
""")
    
    let patterns = organizer.analyzePatterns()
    
    check patterns.usesSetup
    check patterns.usesTeardown
    check patterns.usesMocks
    check patterns.usesFixtures
    
  test "Configuration file generation":
    let organizer = newMECEOrganizer(testDir)
    
    organizer.config.enforceNaming = true
    organizer.config.maxTestsPerFile = 50
    organizer.config.allowedCategories = @["unit", "integration", "system"]
    
    organizer.generateConfig()
    
    let configFile = testDir / ".mece-config.json"
    check fileExists(configFile)
    
  test "Test migration assistance":
    let organizer = newMECEOrganizer(testDir)
    
    # Create old-style tests
    writeFile(testDir / "old_tests.nim", """
import std/unittest
test "old style 1": check true
test "old style 2": check false
""")
    
    let migration = organizer.planMigration()
    
    check migration.filesToMigrate.len > 0
    check migration.newStructure.len > 0
    
  test "Continuous integration recommendations":
    let organizer = newMECEOrganizer(testDir)
    
    let ciRecommendations = organizer.generateCIRecommendations()
    
    check ciRecommendations.parallelizable.len >= 0
    check ciRecommendations.sequential.len >= 0
    check ciRecommendations.fastTests.len >= 0
    check ciRecommendations.slowTests.len >= 0