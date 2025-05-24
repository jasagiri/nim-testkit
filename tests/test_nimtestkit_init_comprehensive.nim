import std/[unittest, os, tempfiles, strutils, json]
import ../src/cli/init
import ../src/organization/standard_layout
import ../src/config/config

suite "NimTestKit Init - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("ntk_init_", "")
    
  teardown:
    removeDir(tempDir)
    
  test "Initialize new project - library":
    let projectDir = tempDir / "my_lib"
    
    let initializer = newProjectInitializer()
    initializer.initProject(projectDir, Library)
    
    # Check directory structure
    check dirExists(projectDir)
    check dirExists(projectDir / "src")
    check dirExists(projectDir / "tests")
    check dirExists(projectDir / "tests" / "unit")
    check dirExists(projectDir / "tests" / "integration")
    check dirExists(projectDir / "build")
    check dirExists(projectDir / "docs")
    
    # Check files
    check fileExists(projectDir / ".gitignore")
    check fileExists(projectDir / "README.md")
    check fileExists(projectDir / "my_lib.nimble")
    check fileExists(projectDir / ".nimtestkit.json")
    
    # Check content
    let gitignore = readFile(projectDir / ".gitignore")
    check "build/" in gitignore
    check "nimcache/" in gitignore
    
  test "Initialize new project - application":
    let projectDir = tempDir / "my_app"
    
    let initializer = newProjectInitializer()
    initializer.initProject(projectDir, Application)
    
    check fileExists(projectDir / "src" / "main.nim")
    
    let mainContent = readFile(projectDir / "src" / "main.nim")
    check "proc main()" in mainContent or "when isMainModule:" in mainContent
    
  test "Initialize new project - hybrid":
    let projectDir = tempDir / "my_hybrid"
    
    let initializer = newProjectInitializer()
    initializer.initProject(projectDir, Hybrid)
    
    check dirExists(projectDir / "src")
    check dirExists(projectDir / "src" / "lib")
    check fileExists(projectDir / "src" / "main.nim")
    
  test "Initialize with custom template":
    let projectDir = tempDir / "custom_project"
    let templateDir = tempDir / "template"
    
    # Create custom template
    createDir(templateDir)
    createDir(templateDir / "{{projectName}}")
    writeFile(templateDir / "{{projectName}}" / "custom.txt", "Hello {{projectName}}!")
    
    let initializer = newProjectInitializer()
    initializer.config.templatePath = templateDir
    initializer.initProject(projectDir, Library)
    
    check fileExists(projectDir / "custom.txt")
    let content = readFile(projectDir / "custom.txt")
    check content == "Hello custom_project!"
    
  test "Initialize with git":
    let projectDir = tempDir / "git_project"
    
    let initializer = newProjectInitializer()
    initializer.config.initGit = true
    initializer.initProject(projectDir, Library)
    
    check dirExists(projectDir / ".git")
    check fileExists(projectDir / ".gitignore")
    
  test "Add nimtestkit to existing project":
    let projectDir = tempDir / "existing_project"
    createDir(projectDir)
    createDir(projectDir / "src")
    writeFile(projectDir / "existing_project.nimble", """
version = "0.1.0"
author = "Test Author"
description = "Existing project"
""")
    
    let initializer = newProjectInitializer()
    initializer.addToExistingProject(projectDir)
    
    check dirExists(projectDir / "tests")
    check fileExists(projectDir / ".nimtestkit.json")
    
    # Check nimble file was updated
    let nimbleContent = readFile(projectDir / "existing_project.nimble")
    check "nimtestkit" in nimbleContent
    
  test "Project type detection":
    let initializer = newProjectInitializer()
    
    # Library detection
    let libDir = tempDir / "lib_project"
    createDir(libDir)
    createDir(libDir / "src")
    writeFile(libDir / "src" / "lib.nim", "# Library code")
    
    check initializer.detectProjectType(libDir) == Library
    
    # Application detection
    let appDir = tempDir / "app_project"
    createDir(appDir)
    createDir(appDir / "src")
    writeFile(appDir / "src" / "main.nim", "# Main entry")
    
    check initializer.detectProjectType(appDir) == Application
    
  test "Configuration file generation":
    let projectDir = tempDir / "config_test"
    
    let initializer = newProjectInitializer()
    initializer.config.testFramework = "unittest"
    initializer.config.coverageTool = "cov"
    initializer.config.parallel = true
    initializer.config.workers = 4
    
    initializer.initProject(projectDir, Library)
    
    let configFile = projectDir / ".nimtestkit.json"
    check fileExists(configFile)
    
    let configData = parseFile(configFile)
    check configData["testFramework"].getStr() == "unittest"
    check configData["coverage"]["tool"].getStr() == "cov"
    check configData["runner"]["parallel"].getBool() == true
    check configData["runner"]["workers"].getInt() == 4
    
  test "Sample test generation":
    let projectDir = tempDir / "sample_tests"
    
    let initializer = newProjectInitializer()
    initializer.config.generateSamples = true
    initializer.initProject(projectDir, Library)
    
    let sampleTest = projectDir / "tests" / "test_example.nim"
    check fileExists(sampleTest)
    
    let content = readFile(sampleTest)
    check "import std/unittest" in content
    check "suite" in content
    check "test" in content
    
  test "GitHub Actions workflow generation":
    let projectDir = tempDir / "github_project"
    
    let initializer = newProjectInitializer()
    initializer.config.githubActions = true
    initializer.initProject(projectDir, Library)
    
    let workflowFile = projectDir / ".github" / "workflows" / "test.yml"
    check fileExists(workflowFile)
    
    let content = readFile(workflowFile)
    check "nim-version" in content
    check "nimble test" in content
    
  test "VSCode configuration":
    let projectDir = tempDir / "vscode_project"
    
    let initializer = newProjectInitializer()
    initializer.config.vscode = true
    initializer.initProject(projectDir, Library)
    
    let tasksFile = projectDir / ".vscode" / "tasks.json"
    check fileExists(tasksFile)
    
    let content = readFile(tasksFile)
    check "\"label\": \"Test\"" in content or "Test" in content
    
  test "Interactive mode simulation":
    let projectDir = tempDir / "interactive"
    
    let initializer = newProjectInitializer()
    # Simulate user choices
    initializer.config.projectName = "my_interactive_lib"
    initializer.config.author = "Test User"
    initializer.config.license = "MIT"
    initializer.config.testFramework = "unittest"
    
    initializer.initProject(projectDir, Library)
    
    let nimbleFile = projectDir / "my_interactive_lib.nimble"
    check fileExists(nimbleFile)
    
    let content = readFile(nimbleFile)
    check "Test User" in content
    check "MIT" in content
    
  test "Makefile generation":
    let projectDir = tempDir / "make_project"
    
    let initializer = newProjectInitializer()
    initializer.config.generateMakefile = true
    initializer.initProject(projectDir, Application)
    
    let makefile = projectDir / "Makefile"
    check fileExists(makefile)
    
    let content = readFile(makefile)
    check "test:" in content
    check "build:" in content
    check "clean:" in content
    
  test "Docker configuration":
    let projectDir = tempDir / "docker_project"
    
    let initializer = newProjectInitializer()
    initializer.config.docker = true
    initializer.initProject(projectDir, Application)
    
    check fileExists(projectDir / "Dockerfile")
    check fileExists(projectDir / ".dockerignore")
    
    let dockerfile = readFile(projectDir / "Dockerfile")
    check "FROM nimlang/nim" in dockerfile
    
  test "Benchmark setup":
    let projectDir = tempDir / "bench_project"
    
    let initializer = newProjectInitializer()
    initializer.config.benchmarks = true
    initializer.initProject(projectDir, Library)
    
    check dirExists(projectDir / "benchmarks")
    check fileExists(projectDir / "benchmarks" / "bench_example.nim")
    
  test "Documentation setup":
    let projectDir = tempDir / "doc_project"
    
    let initializer = newProjectInitializer()
    initializer.config.documentation = true
    initializer.initProject(projectDir, Library)
    
    check dirExists(projectDir / "docs")
    check fileExists(projectDir / "nim.cfg")
    
    let nimCfg = readFile(projectDir / "nim.cfg")
    check "docgen" in nimCfg or "doc" in nimCfg
    
  test "License file generation":
    let projectDir = tempDir / "license_project"
    
    let initializer = newProjectInitializer()
    initializer.config.license = "MIT"
    initializer.config.author = "Test Author"
    initializer.config.year = "2024"
    initializer.initProject(projectDir, Library)
    
    let licenseFile = projectDir / "LICENSE"
    check fileExists(licenseFile)
    
    let content = readFile(licenseFile)
    check "MIT" in content
    check "Test Author" in content
    check "2024" in content
    
  test "Error handling - existing project":
    let projectDir = tempDir / "existing"
    createDir(projectDir)
    writeFile(projectDir / ".nimtestkit.json", "{}")
    
    let initializer = newProjectInitializer()
    let result = initializer.initProject(projectDir, Library)
    
    check not result.success
    check "already initialized" in result.message
    
  test "Custom directory structure":
    let projectDir = tempDir / "custom_structure"
    
    let initializer = newProjectInitializer()
    initializer.config.srcDir = "sources"
    initializer.config.testDir = "test"
    initializer.config.buildDir = "out"
    
    initializer.initProject(projectDir, Library)
    
    check dirExists(projectDir / "sources")
    check dirExists(projectDir / "test")
    check dirExists(projectDir / "out")
    check not dirExists(projectDir / "src")
    check not dirExists(projectDir / "tests")