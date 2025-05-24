import std/[unittest, os, tempfiles, strutils, sequtils, tables, json]
import ../src/generation/generator
import ../src/config/config
import ../src/organization/standard_layout
import ../src/integrations/lang/design_patterns_integration

suite "TestGenerator - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("test_gen_", "")
    let projectDir = tempDir / "test_project"
    createDir(projectDir)
    createDir(projectDir / "src")
    createDir(projectDir / "tests")
    
  teardown:
    removeDir(tempDir)
    
  test "Generate test for simple module":
    let sourceFile = projectDir / "src" / "math_utils.nim"
    writeFile(sourceFile, """
proc add*(a, b: int): int = a + b
proc multiply*(a, b: int): int = a * b
func divide*(a, b: float): float = a / b
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check testFile != ""
    check "import math_utils" in testFile or "import ../src/math_utils" in testFile
    check "test \"add" in testFile
    check "test \"multiply" in testFile
    check "test \"divide" in testFile
    
  test "Generate test for module with types":
    let sourceFile = projectDir / "src" / "types.nim"
    writeFile(sourceFile, """
type
  Point* = object
    x*, y*: float
  
  Color* = enum
    Red, Green, Blue
    
proc newPoint*(x, y: float): Point =
  Point(x: x, y: y)
  
proc distance*(p1, p2: Point): float =
  sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2)
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check "Point" in testFile
    check "test \"newPoint" in testFile
    check "test \"distance" in testFile
    
  test "Generate test with edge cases":
    let sourceFile = projectDir / "src" / "validator.nim"
    writeFile(sourceFile, """
proc isPositive*(n: int): bool = n > 0
proc isEmail*(s: string): bool = "@" in s and "." in s
proc clamp*(val, min, max: float): float =
  if val < min: min
  elif val > max: max
  else: val
""")
    
    let generator = newTestGenerator()
    generator.config.includeEdgeCases = true
    let testFile = generator.generateTest(sourceFile)
    
    check "test \"isPositive with zero" in testFile
    check "test \"isPositive with negative" in testFile
    check "test \"isEmail with empty string" in testFile
    check "test \"clamp with value below min" in testFile
    check "test \"clamp with value above max" in testFile
    
  test "Generate test with mocks":
    let sourceFile = projectDir / "src" / "service.nim"
    writeFile(sourceFile, """
import db_connector

type
  UserService* = object
    db: DbConn
    
proc getUser*(s: UserService, id: int): string =
  s.db.query("SELECT name FROM users WHERE id = ?", id)
  
proc saveUser*(s: var UserService, name: string): bool =
  s.db.exec("INSERT INTO users (name) VALUES (?)", name)
""")
    
    let generator = newTestGenerator()
    generator.config.generateMocks = true
    let testFile = generator.generateTest(sourceFile)
    
    check "MockDbConn" in testFile
    check "test \"getUser" in testFile
    check "test \"saveUser" in testFile
    
  test "Generate property-based tests":
    let sourceFile = projectDir / "src" / "properties.nim"
    writeFile(sourceFile, """
proc reverse*[T](s: seq[T]): seq[T] =
  result = newSeq[T](s.len)
  for i in 0..<s.len:
    result[i] = s[s.len - 1 - i]
    
proc sort*[T](s: seq[T]): seq[T] =
  result = s
  result.sort()
""")
    
    let generator = newTestGenerator()
    generator.config.propertyTesting = true
    let testFile = generator.generateTest(sourceFile)
    
    check "property \"reverse twice returns original" in testFile
    check "property \"sort is idempotent" in testFile
    check "forAll" in testFile
    
  test "Generate benchmark tests":
    let sourceFile = projectDir / "src" / "performance.nim"
    writeFile(sourceFile, """
proc fibonacci*(n: int): int =
  if n <= 1: n
  else: fibonacci(n-1) + fibonacci(n-2)
  
proc fibonacciMemo*(n: int): int =
  var cache = initTable[int, int]()
  proc fib(n: int): int =
    if n in cache: return cache[n]
    if n <= 1: return n
    result = fib(n-1) + fib(n-2)
    cache[n] = result
  fib(n)
""")
    
    let generator = newTestGenerator()
    generator.config.generateBenchmarks = true
    let testFile = generator.generateTest(sourceFile)
    
    check "benchmark \"fibonacci performance" in testFile
    check "benchmark \"fibonacciMemo performance" in testFile
    check "measure" in testFile or "bench" in testFile
    
  test "Generate test with custom template":
    let templateContent = """
# Custom test template
import std/unittest
import $module

suite "$moduleName tests":
  setup:
    echo "Custom setup"
    
  teardown:
    echo "Custom teardown"
    
  $tests
"""
    
    let sourceFile = projectDir / "src" / "custom.nim"
    writeFile(sourceFile, "proc greet*(name: string): string = \"Hello, \" & name")
    
    let generator = newTestGenerator()
    generator.config.testTemplate = templateContent
    let testFile = generator.generateTest(sourceFile)
    
    check "Custom setup" in testFile
    check "Custom teardown" in testFile
    check "custom tests" in testFile
    
  test "Generate tests for generic procedures":
    let sourceFile = projectDir / "src" / "generics.nim"
    writeFile(sourceFile, """
proc swap*[T](a, b: var T) =
  let temp = a
  a = b
  b = temp
  
proc max*[T](a, b: T): T =
  if a > b: a else: b
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check "test \"swap with int" in testFile
    check "test \"swap with string" in testFile
    check "test \"max with" in testFile
    
  test "Generate tests for async procedures":
    let sourceFile = projectDir / "src" / "async_ops.nim"
    writeFile(sourceFile, """
import std/asyncdispatch

proc fetchData*(url: string): Future[string] {.async.} =
  await sleepAsync(100)
  return "data from " & url
  
proc processAsync*(items: seq[string]): Future[seq[string]] {.async.} =
  result = @[]
  for item in items:
    let data = await fetchData(item)
    result.add(data)
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check "asyncTest \"fetchData" in testFile or "test \"fetchData" in testFile
    check "waitFor" in testFile or "await" in testFile
    
  test "Generate tests with fixtures":
    let sourceFile = projectDir / "src" / "file_ops.nim"
    writeFile(sourceFile, """
proc readConfig*(path: string): string =
  readFile(path)
  
proc writeConfig*(path: string, content: string) =
  writeFile(path, content)
  
proc appendLog*(path: string, message: string) =
  let f = open(path, fmAppend)
  f.writeLine(message)
  f.close()
""")
    
    let generator = newTestGenerator()
    generator.config.generateFixtures = true
    let testFile = generator.generateTest(sourceFile)
    
    check "fixture" in testFile or "setup" in testFile
    check "tempfile" in testFile.toLower or "tempdir" in testFile.toLower
    check "removeFile" in testFile or "cleanup" in testFile
    
  test "Skip private procedures":
    let sourceFile = projectDir / "src" / "private.nim"
    writeFile(sourceFile, """
proc publicProc*(x: int): int = x * 2
proc privateProc(x: int): int = x + 1
func publicFunc*(s: string): int = s.len
template privateTemplate(body: untyped) = body
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check "test \"publicProc" in testFile
    check "test \"publicFunc" in testFile
    check not ("test \"privateProc" in testFile)
    check not ("privateTemplate" in testFile)
    
  test "Handle module with imports":
    let utilsFile = projectDir / "src" / "utils.nim"
    writeFile(utilsFile, "proc double*(x: int): int = x * 2")
    
    let sourceFile = projectDir / "src" / "calculator.nim"
    writeFile(sourceFile, """
import utils
import std/[strutils, sequtils]

proc calculate*(expr: string): int =
  let parts = expr.split(" ")
  case parts[1]:
  of "+": parseInt(parts[0]) + parseInt(parts[2])
  of "*": double(parseInt(parts[0])) * parseInt(parts[2])
  else: 0
""")
    
    let generator = newTestGenerator()
    let testFile = generator.generateTest(sourceFile)
    
    check "import" in testFile
    check "calculate" in testFile
    
  test "Generate tests with tables/matrices":
    let sourceFile = projectDir / "src" / "table_ops.nim"
    writeFile(sourceFile, """
proc isValidMove*(board: array[3, array[3, char]], row, col: int): bool =
  row in 0..2 and col in 0..2 and board[row][col] == ' '
""")
    
    let generator = newTestGenerator()
    generator.config.tableTests = true
    let testFile = generator.generateTest(sourceFile)
    
    check "testTable" in testFile or "parameterized" in testFile or "data-driven" in testFile
    
  test "Generate documentation tests":
    let sourceFile = projectDir / "src" / "documented.nim"
    writeFile(sourceFile, """
## This module provides math operations

proc square*(x: int): int =
  ## Returns the square of x
  ## 
  ## Example:
  ##   doAssert square(5) == 25
  ##   doAssert square(-3) == 9
  x * x
""")
    
    let generator = newTestGenerator()
    generator.config.extractDocTests = true
    let testFile = generator.generateTest(sourceFile)
    
    check "test \"square doc example" in testFile or "doAssert square(5) == 25" in testFile
    
  test "Test file organization":
    let sourceFile = projectDir / "src" / "domain" / "user.nim"
    createDir(projectDir / "src" / "domain")
    writeFile(sourceFile, "proc getName*(id: int): string = \"User \" & $id")
    
    let generator = newTestGenerator()
    let testPath = generator.getTestPath(sourceFile)
    
    check "tests" in testPath
    check "domain" in testPath
    check testPath.endsWith("test_user.nim")
    
  test "Batch test generation":
    createDir(projectDir / "src" / "models")
    writeFile(projectDir / "src" / "models" / "user.nim", "type User* = object")
    writeFile(projectDir / "src" / "models" / "post.nim", "type Post* = object")
    writeFile(projectDir / "src" / "api.nim", "proc getApi*(): string = \"v1\"")
    
    let generator = newTestGenerator()
    let results = generator.generateTestsForDirectory(projectDir / "src")
    
    check results.len >= 3
    check results.anyIt(it.sourcePath.endsWith("user.nim"))
    check results.anyIt(it.sourcePath.endsWith("post.nim"))
    check results.anyIt(it.sourcePath.endsWith("api.nim"))
    
  test "Update existing test file":
    let sourceFile = projectDir / "src" / "updater.nim"
    writeFile(sourceFile, """
proc oldFunc*(x: int): int = x
proc newFunc*(y: string): string = y & "!"
""")
    
    let testFile = projectDir / "tests" / "test_updater.nim"
    writeFile(testFile, """
import std/unittest
import ../src/updater

suite "updater":
  test "oldFunc":
    check oldFunc(5) == 5
""")
    
    let generator = newTestGenerator()
    generator.config.updateMode = true
    let updated = generator.updateTest(sourceFile, testFile)
    
    check "test \"oldFunc" in updated
    check "test \"newFunc" in updated
    
  test "Generate with test categorization":
    let sourceFile = projectDir / "src" / "mixed.nim"
    writeFile(sourceFile, """
proc calculate*(x, y: int): int = x + y  # Unit testable
proc fetchFromDb*(id: int): string = "data"  # Integration test
proc complexWorkflow*(): bool = true  # System test
""")
    
    let generator = newTestGenerator()
    generator.config.categorizeTests = true
    let categories = generator.categorizeTests(sourceFile)
    
    check categories.unit.len >= 1
    check categories.integration.len >= 1
    check categories.system.len >= 0
    
  test "Generate with error handling tests":
    let sourceFile = projectDir / "src" / "errors.nim"
    writeFile(sourceFile, """
proc divide*(a, b: int): int =
  if b == 0:
    raise newException(DivByZeroDefect, "Division by zero")
  a div b
  
proc parseValue*(s: string): int =
  try:
    parseInt(s)
  except ValueError:
    -1
""")
    
    let generator = newTestGenerator()
    generator.config.testExceptions = true
    let testFile = generator.generateTest(sourceFile)
    
    check "expect(DivByZeroDefect)" in testFile or "assertRaises" in testFile
    check "test \"parseValue with invalid input" in testFile
    
  test "Configuration validation":
    let generator = newTestGenerator()
    
    # Valid config
    generator.config.outputDir = projectDir / "tests"
    generator.config.testFramework = "unittest"
    check generator.validateConfig()
    
    # Invalid config
    generator.config.outputDir = ""
    check not generator.validateConfig()