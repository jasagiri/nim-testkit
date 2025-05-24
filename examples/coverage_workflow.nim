## Example demonstrating coverage file management with standard layout

import ../src/standard_layout
import std/[os, strformat, times, json]

proc demonstrateCoverageStructure() =
  echo "=== Coverage File Structure Demo ==="
  
  let paths = getStandardPaths()
  
  echo "\nCoverage directories:"
  echo "  Raw data: ", paths.projectRoot / CoverageRawDir
  echo "  Reports: ", paths.projectRoot / CoverageReportsDir  
  echo "  Temp files: ", paths.projectRoot / CoverageTempDir
  
  echo "\nExample coverage file paths:"
  
  # Raw coverage data for specific tests
  echo "\nRaw coverage data:"
  for testFile in ["test_lib.nim", "test_app.nim", "test_utils.nim"]:
    echo "  ", getCoverageRawPath(paths, testFile)
  
  # Different report formats
  echo "\nGenerated reports:"
  for format in ["html", "json", "lcov", "xml"]:
    echo fmt"  {format}: ", getCoverageReportPath(paths, format)
  
  # Temporary files
  echo "\nTemporary files:"
  echo "  ", getCoverageTempPath(paths, "merged_coverage.tmp")
  echo "  ", getCoverageTempPath(paths, "processing.lock")

proc demonstrateCoverageWorkflow() =
  echo "\n=== Coverage Workflow Demo ==="
  
  let paths = getStandardPaths()
  
  # Step 1: Ensure directories exist
  echo "\n1. Creating coverage directories..."
  createBuildDirectories(paths)
  echo "   ✓ Directories created"
  
  # Step 2: Simulate raw coverage data generation
  echo "\n2. Generating raw coverage data..."
  let testFiles = @["test_core.nim", "test_utils.nim", "test_integration.nim"]
  
  for testFile in testFiles:
    let covPath = getCoverageRawPath(paths, testFile)
    let covData = %*{
      "test": testFile,
      "timestamp": $now(),
      "lines_covered": 42,
      "lines_total": 50,
      "functions_covered": 8,
      "functions_total": 10
    }
    writeFile(covPath, $covData)
    echo fmt"   ✓ Generated {covPath}"
  
  # Step 3: Create temporary processing file
  echo "\n3. Processing coverage data..."
  let tempPath = getCoverageTempPath(paths, "processing.json")
  let tempData = %*{
    "status": "processing",
    "started": $now(),
    "files": testFiles
  }
  writeFile(tempPath, $tempData)
  echo fmt"   ✓ Created temp file: {tempPath}"
  
  # Step 4: Generate reports
  echo "\n4. Generating coverage reports..."
  
  # HTML report
  let htmlPath = getCoverageReportPath(paths, "html")
  let htmlContent = """
<!DOCTYPE html>
<html>
<head><title>Coverage Report</title></head>
<body>
  <h1>Coverage Report</h1>
  <p>Generated: """ & $now() & """</p>
  <p>Coverage: 84.0%</p>
</body>
</html>
"""
  writeFile(htmlPath, htmlContent)
  echo fmt"   ✓ HTML report: {htmlPath}"
  
  # JSON report
  let jsonPath = getCoverageReportPath(paths, "json")
  let jsonReport = %*{
    "timestamp": $now(),
    "overall_coverage": 84.0,
    "files": testFiles.mapIt(%*{"file": it, "coverage": 80.0 + float(it.len)})
  }
  writeFile(jsonPath, $jsonReport)
  echo fmt"   ✓ JSON report: {jsonPath}"
  
  # Step 5: Clean temporary files
  echo "\n5. Cleaning temporary files..."
  cleanCoverageTemp(paths)
  echo "   ✓ Temporary files cleaned"

proc demonstrateCoverageIntegration() =
  echo "\n=== Integration with CI/CD ==="
  
  echo """
The standardized coverage structure integrates well with CI/CD:

1. **GitHub Actions**:
   ```yaml
   - name: Run tests with coverage
     run: nimtestkit coverage
   
   - name: Upload coverage
     uses: actions/upload-artifact@v3
     with:
       name: coverage-report
       path: build/coverage/reports/
   ```

2. **GitLab CI**:
   ```yaml
   test:
     script:
       - nimtestkit coverage
     artifacts:
       reports:
         coverage_report:
           coverage_format: cobertura
           path: build/coverage/reports/coverage_*.xml
   ```

3. **Local Development**:
   ```bash
   # Run coverage
   nimtestkit coverage
   
   # View report
   open build/coverage/reports/index.html
   
   # Check specific test coverage
   jq '.files[] | select(.file == "test_lib.nim")' \
     build/coverage/reports/coverage_*.json
   ```
"""

proc demonstrateBenefits() =
  echo "\n=== Benefits of Standardized Coverage Structure ==="
  
  echo """
✓ **Organized**: Clear separation of raw data, reports, and temp files
✓ **Predictable**: Tools always know where to find coverage data
✓ **Clean**: All artifacts in build/, easy to gitignore
✓ **Incremental**: Raw data preserved for differential coverage
✓ **Multi-format**: Supports HTML, JSON, LCOV, XML formats
✓ **CI-friendly**: Standard paths work with all CI systems
✓ **No config**: Works without any configuration
"""

when isMainModule:
  demonstrateCoverageStructure()
  demonstrateCoverageWorkflow()
  demonstrateCoverageIntegration()
  demonstrateBenefits()