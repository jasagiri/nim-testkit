# Core types for nim-testkit
# Zero external dependencies - uses only Nim stdlib

type
  TestStatus* = enum
    tsUnknown = "unknown"
    tsPending = "pending"
    tsRunning = "running"
    tsPassed = "passed"
    tsFailed = "failed"
    tsSkipped = "skipped"
    tsError = "error"

  TestCategory* = enum
    tcUnit = "unit"
    tcIntegration = "integration"
    tcSystem = "system"
    tcPerformance = "performance"
    tcCustom = "custom"

  TestResult* = object
    name*: string
    category*: TestCategory
    status*: TestStatus
    startTime*: float
    endTime*: float
    duration*: float
    message*: string
    stackTrace*: string
    file*: string
    line*: int
    
  TestCase* = object
    name*: string
    category*: TestCategory
    file*: string
    line*: int
    testProc*: proc() {.nimcall.}
    setupProc*: proc() {.nimcall.}
    teardownProc*: proc() {.nimcall.}
    tags*: seq[string]
    timeout*: float # in seconds, 0 = no timeout
    
  TestSuite* = object
    name*: string
    category*: TestCategory
    tests*: seq[TestCase]
    setupSuite*: proc() {.nimcall.}
    teardownSuite*: proc() {.nimcall.}
    parallel*: bool
    
  TestReport* = object
    suites*: seq[TestSuite]
    results*: seq[TestResult]
    totalTests*: int
    passed*: int
    failed*: int
    skipped*: int
    errors*: int
    startTime*: float
    endTime*: float
    duration*: float

  TestFilter* = object
    categories*: seq[TestCategory]
    tags*: seq[string]
    patterns*: seq[string]
    excludePatterns*: seq[string]

  TestConfig* = object
    outputFormat*: OutputFormat
    verbose*: bool
    parallel*: bool
    failFast*: bool
    filter*: TestFilter
    timeout*: float
    reportFile*: string
    randomSeed*: int
    
  OutputFormat* = enum
    ofText = "text"
    ofJson = "json"
    ofXml = "xml"
    ofTap = "tap"
    ofJunit = "junit"

# Helper functions
proc initTestResult*(name: string, category: TestCategory = tcUnit): TestResult =
  result = TestResult(
    name: name,
    category: category,
    status: tsPending,
    startTime: 0.0,
    endTime: 0.0,
    duration: 0.0,
    message: "",
    stackTrace: "",
    file: "",
    line: 0
  )

proc initTestCase*(name: string, testProc: proc() {.nimcall.}, 
                   category: TestCategory = tcUnit): TestCase =
  result = TestCase(
    name: name,
    category: category,
    file: "",
    line: 0,
    testProc: testProc,
    setupProc: nil,
    teardownProc: nil,
    tags: @[],
    timeout: 0.0
  )

proc initTestSuite*(name: string, category: TestCategory = tcUnit): TestSuite =
  result = TestSuite(
    name: name,
    category: category,
    tests: @[],
    setupSuite: nil,
    teardownSuite: nil,
    parallel: false
  )

proc initTestReport*(): TestReport =
  result = TestReport(
    suites: @[],
    results: @[],
    totalTests: 0,
    passed: 0,
    failed: 0,
    skipped: 0,
    errors: 0,
    startTime: 0.0,
    endTime: 0.0,
    duration: 0.0
  )

proc initTestConfig*(): TestConfig =
  result = TestConfig(
    outputFormat: ofText,
    verbose: false,
    parallel: false,
    failFast: false,
    filter: TestFilter(
      categories: @[],
      tags: @[],
      patterns: @[],
      excludePatterns: @[]
    ),
    timeout: 300.0, # 5 minutes default
    reportFile: "",
    randomSeed: 0
  )

# Category helpers
proc isUnitTest*(test: TestCase): bool =
  test.category == tcUnit

proc isIntegrationTest*(test: TestCase): bool =
  test.category == tcIntegration

proc isSystemTest*(test: TestCase): bool =
  test.category == tcSystem

# Status helpers
proc isPassed*(testResult: TestResult): bool =
  testResult.status == tsPassed

proc isFailed*(testResult: TestResult): bool =
  testResult.status == tsFailed

proc isError*(testResult: TestResult): bool =
  testResult.status == tsError

proc isSkipped*(testResult: TestResult): bool =
  testResult.status == tsSkipped