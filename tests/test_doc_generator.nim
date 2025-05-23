import unittest, os, strutils
import "../src/doc_generator"
import "../src/config"

suite "Documentation Generator Tests":
  test "extractTestDocs extracts test information":
    # Create a temporary test file
    let tempDir = getTempDir() / "docgen_test"
    createDir(tempDir)
    
    let testContent = """
import unittest

suite "Sample Suite":
  test "sample test case":
    # This is a test description
    # It spans multiple lines
    check true
    
  test "another test case":
    # Different description
    check 1 == 1
"""
    
    let testFile = tempDir / "sample_test.nim"
    writeFile(testFile, testContent)
    
    # Test extraction
    let docs = extractTestDocs(testFile)
    check docs.len == 2
    check docs[0].name == "sample test case"
    check docs[0].description.contains("This is a test description")
    check docs[0].description.contains("It spans multiple lines")
    check docs[1].name == "another test case"
    check docs[1].description.contains("Different description")
    
    # Cleanup
    removeDir(tempDir)
    
  test "generateMarkdownDocs creates markdown file":
    # Create a temporary directory
    let tempDir = getTempDir() / "markdown_test"
    createDir(tempDir)
    
    # Generate docs
    let config = TestKitConfig()
    let result = generateMarkdownDocs(config, tempDir)
    
    # Verify files were created
    check fileExists(tempDir / "test-docs.md")
    check fileExists(tempDir / "coverage.md")
    check fileExists(tempDir / "index.md")
    
    # Verify content
    let indexContent = readFile(tempDir / "index.md")
    check indexContent.contains("Nim TestKit Documentation")
    
    # Cleanup
    removeDir(tempDir)
    
  test "generateCoverageMarkdown generates report":
    let config = TestKitConfig()
    let markdown = generateCoverageMarkdown(config)
    
    check markdown.len > 0
    check markdown.startsWith("# Coverage Report")
    
  test "generateTestBadges creates SVG badges":
    # Create a temporary directory for badges
    let tempDir = getTempDir() / "badge_test"
    createDir(tempDir)
    
    # Generate badges
    generateTestBadges(TestKitConfig(), tempDir)
    
    # Check badge files
    check fileExists(tempDir / "tests.svg")
    check fileExists(tempDir / "coverage.svg")
    
    # Check content
    let testBadge = readFile(tempDir / "tests.svg")
    check testBadge.contains("tests")
    check testBadge.contains("passing")
    
    # Cleanup
    removeDir(tempDir)
    
  test "generateAPIDocs generates API documentation":
    # Create a temporary directory for docs
    let tempDir = getTempDir() / "api_docs_test"
    createDir(tempDir)
    
    # Create a temporary source file
    let srcDir = tempDir / "src"
    createDir(srcDir)
    
    let srcContent = """
## Module documentation
## This is a test module

proc testFunction*(x: int): int =
  ## This function does something
  ## Returns x * 2
  return x * 2
"""
    
    writeFile(srcDir / "test_module.nim", srcContent)
    
    # Create a test config
    var config = TestKitConfig()
    config.sourceDir = srcDir
    config.includePatterns = @["*.nim"]  # Make sure the pattern matches our test file
    
    # Create API docs directory
    let apiDir = tempDir / "api"
    createDir(apiDir)
    
    # Generate API docs
    generateAPIDocs(config, apiDir)
    
    # Check file exists
    check fileExists(apiDir / "test_module.md")
    
    # Check content
    let content = readFile(apiDir / "test_module.md")
    check content.contains("test_module API")
    check content.contains("Functions")
    
    # Cleanup
    removeDir(tempDir)
    
  test "integrationWithNimDoc handles nim doc command":
    # This just tests the function exists and returns a string
    let result = integrationWithNimDoc("test.nim")
    check result.len > 0