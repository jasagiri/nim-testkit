import std/[unittest, os, tempfiles, strutils, sequtils, tables, json]
import ../src/analysis/coverage
import ../src/organization/standard_layout

suite "CoverageHelper - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("coverage_", "")
    let projectDir = tempDir / "test_project"
    createDir(projectDir)
    createDir(projectDir / "src")
    createDir(projectDir / "tests")
    createDir(projectDir / "build" / "coverage")
    
  teardown:
    removeDir(tempDir)
    
  test "Coverage data collection - basic":
    let helper = newCoverageHelper(projectDir)
    
    # Simulate coverage data
    let coverageData = """
    src/main.nim:
      Lines: 10/20 (50%)
      Functions: 3/5 (60%)
    src/utils.nim:
      Lines: 15/15 (100%)
      Functions: 4/4 (100%)
    """
    
    writeFile(projectDir / "build" / "coverage" / "coverage.txt", coverageData)
    let report = helper.parseCoverageData()
    
    check report.files.len == 2
    check report.totalCoverage == 75.0  # Average of 50% and 100%
    
  test "Coverage data collection - lcov format":
    let helper = newCoverageHelper(projectDir)
    helper.config.format = LcovFormat
    
    let lcovData = """
    TN:
    SF:src/main.nim
    FN:1,main
    FN:5,processArgs
    FNDA:1,main
    FNDA:0,processArgs
    FNF:2
    FNH:1
    DA:1,1
    DA:2,1
    DA:3,0
    DA:4,0
    DA:5,0
    LF:5
    LH:2
    end_of_record
    """
    
    writeFile(projectDir / "build" / "coverage" / "coverage.lcov", lcovData)
    let report = helper.parseLcovData()
    
    check report.files["src/main.nim"].lineCoverage == 40.0  # 2/5 lines
    check report.files["src/main.nim"].functionCoverage == 50.0  # 1/2 functions
    
  test "Coverage report generation - HTML":
    let helper = newCoverageHelper(projectDir)
    helper.config.outputFormat = HtmlReport
    
    var report = CoverageReport()
    report.files["src/app.nim"] = FileCoverage(
      path: "src/app.nim",
      lineCoverage: 85.5,
      functionCoverage: 90.0,
      branchCoverage: 75.0,
      coveredLines: 85,
      totalLines: 100
    )
    
    helper.generateHtmlReport(report)
    
    let htmlFile = projectDir / "build" / "coverage" / "index.html"
    check fileExists(htmlFile)
    
    let content = readFile(htmlFile)
    check "<html>" in content
    check "85.5%" in content
    check "src/app.nim" in content
    
  test "Coverage report generation - JSON":
    let helper = newCoverageHelper(projectDir)
    helper.config.outputFormat = JsonReport
    
    var report = CoverageReport()
    report.totalCoverage = 92.3
    report.files["src/lib.nim"] = FileCoverage(
      path: "src/lib.nim",
      lineCoverage: 92.3,
      functionCoverage: 95.0,
      branchCoverage: 88.0
    )
    
    helper.generateJsonReport(report)
    
    let jsonFile = projectDir / "build" / "coverage" / "coverage.json"
    check fileExists(jsonFile)
    
    let data = parseFile(jsonFile)
    check data["summary"]["total"].getFloat() == 92.3
    check data["files"]["src/lib.nim"]["line_coverage"].getFloat() == 92.3
    
  test "Coverage report generation - Markdown":
    let helper = newCoverageHelper(projectDir)
    helper.config.outputFormat = MarkdownReport
    
    var report = CoverageReport()
    report.files["src/core.nim"] = FileCoverage(
      path: "src/core.nim",
      lineCoverage: 100.0,
      coveredLines: 50,
      totalLines: 50
    )
    report.files["src/helpers.nim"] = FileCoverage(
      path: "src/helpers.nim",
      lineCoverage: 80.0,
      coveredLines: 40,
      totalLines: 50
    )
    
    helper.generateMarkdownReport(report)
    
    let mdFile = projectDir / "build" / "coverage" / "coverage.md"
    check fileExists(mdFile)
    
    let content = readFile(mdFile)
    check "# Coverage Report" in content
    check "| File | Coverage |" in content
    check "| src/core.nim | 100.0% |" in content
    
  test "Coverage thresholds":
    let helper = newCoverageHelper(projectDir)
    helper.config.thresholds.global = 80.0
    helper.config.thresholds.perFile = 70.0
    
    var report = CoverageReport()
    report.totalCoverage = 85.0
    report.files["src/good.nim"] = FileCoverage(lineCoverage: 90.0)
    report.files["src/bad.nim"] = FileCoverage(lineCoverage: 65.0)
    
    let result = helper.checkThresholds(report)
    
    check result.passed  # Global threshold met
    check result.failedFiles.len == 1
    check "src/bad.nim" in result.failedFiles
    
  test "Coverage merging":
    let helper = newCoverageHelper(projectDir)
    
    # Create multiple coverage files
    writeFile(projectDir / "build" / "coverage" / "unit.lcov", """
    SF:src/main.nim
    DA:1,1
    DA:2,1
    DA:3,0
    end_of_record
    """)
    
    writeFile(projectDir / "build" / "coverage" / "integration.lcov", """
    SF:src/main.nim
    DA:1,1
    DA:2,1
    DA:3,1
    DA:4,0
    end_of_record
    """)
    
    let merged = helper.mergeCoverageFiles(@[
      projectDir / "build" / "coverage" / "unit.lcov",
      projectDir / "build" / "coverage" / "integration.lcov"
    ])
    
    check merged.files["src/main.nim"].coveredLines == 3  # Lines 1, 2, 3
    check merged.files["src/main.nim"].totalLines == 4
    
  test "Coverage exclusions":
    let helper = newCoverageHelper(projectDir)
    helper.config.exclude = @["tests/", "vendor/", "*.test.nim"]
    
    var report = CoverageReport()
    report.files["src/app.nim"] = FileCoverage(lineCoverage: 80.0)
    report.files["tests/test_app.nim"] = FileCoverage(lineCoverage: 100.0)
    report.files["vendor/lib.nim"] = FileCoverage(lineCoverage: 50.0)
    
    let filtered = helper.filterReport(report)
    
    check filtered.files.len == 1
    check "src/app.nim" in filtered.files
    check "tests/test_app.nim" notin filtered.files
    
  test "Coverage badges generation":
    let helper = newCoverageHelper(projectDir)
    helper.config.generateBadge = true
    
    var report = CoverageReport()
    report.totalCoverage = 87.5
    
    helper.generateBadge(report)
    
    let badgeFile = projectDir / "build" / "coverage" / "badge.svg"
    check fileExists(badgeFile)
    
    let content = readFile(badgeFile)
    check "<svg" in content
    check "87.5%" in content or "87%" in content
    
  test "Coverage history tracking":
    let helper = newCoverageHelper(projectDir)
    helper.config.trackHistory = true
    
    # Add coverage entries
    helper.addHistoryEntry(85.0, "2024-01-01")
    helper.addHistoryEntry(87.5, "2024-01-02")
    helper.addHistoryEntry(90.0, "2024-01-03")
    
    let history = helper.loadHistory()
    
    check history.len == 3
    check history[^1].coverage == 90.0
    check helper.getCoverageTrend() == Improving
    
  test "Coverage by module":
    let helper = newCoverageHelper(projectDir)
    
    var report = CoverageReport()
    report.files["src/core/engine.nim"] = FileCoverage(lineCoverage: 95.0)
    report.files["src/core/parser.nim"] = FileCoverage(lineCoverage: 88.0)
    report.files["src/utils/helpers.nim"] = FileCoverage(lineCoverage: 100.0)
    report.files["src/utils/logger.nim"] = FileCoverage(lineCoverage: 75.0)
    
    let byModule = helper.groupByModule(report)
    
    check byModule["core"].averageCoverage == 91.5
    check byModule["utils"].averageCoverage == 87.5
    
  test "Uncovered lines report":
    let helper = newCoverageHelper(projectDir)
    
    let lcovData = """
    SF:src/example.nim
    DA:1,1
    DA:2,1
    DA:3,0
    DA:4,0
    DA:5,1
    DA:6,0
    DA:7,1
    DA:8,1
    DA:9,0
    DA:10,1
    end_of_record
    """
    
    writeFile(projectDir / "build" / "coverage" / "coverage.lcov", lcovData)
    let uncovered = helper.getUncoveredLines("src/example.nim")
    
    check uncovered == @[3, 4, 6, 9]
    
  test "Coverage annotations":
    let helper = newCoverageHelper(projectDir)
    
    let sourceFile = projectDir / "src" / "annotated.nim"
    writeFile(sourceFile, """
proc example(x: int): int =
  if x > 0:
    return x * 2
  else:
    return -x
""")
    
    let coverage = FileCoverage(
      path: "src/annotated.nim",
      lineHits: {2: 5, 3: 5, 4: 0, 5: 0}.toTable
    )
    
    helper.generateAnnotatedSource(sourceFile, coverage)
    
    let annotatedFile = projectDir / "build" / "coverage" / "annotated" / "src" / "annotated.nim.html"
    check fileExists(annotatedFile)
    
    let content = readFile(annotatedFile)
    check "class=\"covered\"" in content  # For covered lines
    check "class=\"uncovered\"" in content  # For uncovered lines
    
  test "Coverage diff between runs":
    let helper = newCoverageHelper(projectDir)
    
    var oldReport = CoverageReport()
    oldReport.files["src/app.nim"] = FileCoverage(lineCoverage: 80.0)
    oldReport.files["src/lib.nim"] = FileCoverage(lineCoverage: 90.0)
    
    var newReport = CoverageReport()
    newReport.files["src/app.nim"] = FileCoverage(lineCoverage: 85.0)
    newReport.files["src/lib.nim"] = FileCoverage(lineCoverage: 88.0)
    newReport.files["src/new.nim"] = FileCoverage(lineCoverage: 95.0)
    
    let diff = helper.compareCoverage(oldReport, newReport)
    
    check diff.improved == @["src/app.nim"]
    check diff.regressed == @["src/lib.nim"]
    check diff.added == @["src/new.nim"]
    
  test "Integration with CI systems":
    let helper = newCoverageHelper(projectDir)
    helper.config.ciMode = true
    
    var report = CoverageReport()
    report.totalCoverage = 75.0  # Below typical threshold
    
    # Should format for CI
    let output = helper.formatForCI(report)
    check "::warning::" in output or "Coverage below threshold" in output
    
  test "Coverage configuration loading":
    let configFile = projectDir / ".coverage.json"
    writeFile(configFile, """
    {
      "format": "lcov",
      "output": "html",
      "threshold": {
        "global": 85,
        "perFile": 80
      },
      "exclude": ["tests/", "vendor/"],
      "badge": true
    }
    """)
    
    let helper = newCoverageHelper(projectDir)
    helper.loadConfig()
    
    check helper.config.format == LcovFormat
    check helper.config.outputFormat == HtmlReport
    check helper.config.thresholds.global == 85.0
    check helper.config.exclude == @["tests/", "vendor/"]
    check helper.config.generateBadge == true
    
  test "Error handling - missing coverage data":
    let helper = newCoverageHelper(projectDir)
    
    let report = helper.parseCoverageData()
    check report.files.len == 0
    check report.totalCoverage == 0.0
    
  test "Error handling - corrupted data":
    let helper = newCoverageHelper(projectDir)
    
    writeFile(projectDir / "build" / "coverage" / "coverage.lcov", """
    Invalid LCOV data
    This is not proper format
    """)
    
    let report = helper.parseLcovData()
    check report.files.len == 0