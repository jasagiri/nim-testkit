## Nim TestKit Project Initializer
## Creates standard project structure with minimal configuration

import std/[os, strutils, parseopt, terminal]
import ../organization/standard_layout, ../config/config
import ../integrations/lang/lang_core_integration

proc printHelp() =
  echo """
Nim TestKit Project Initializer

Usage: nimtestkit_init [options] [project_path]

Options:
  -t, --type TYPE      Project type: library, application, hybrid (default: auto-detect)
  -p, --preset PRESET  Configuration preset: minimal, standard, strict (default: standard)
  --no-git            Don't create .gitignore file
  --no-build          Don't create build directories
  --force             Overwrite existing configuration
  -h, --help          Show this help

Examples:
  nimtestkit_init                    # Initialize current directory
  nimtestkit_init myproject          # Create and initialize new project
  nimtestkit_init -t library mylib   # Create new library project
  nimtestkit_init --preset minimal   # Use minimal configuration
"""

proc main() =
  var
    projectPath = getCurrentDir()
    projectType = plStandard
    preset = "standard"
    createGitignore = true
    createBuildDirs = true
    force = false
    autoDetect = true
  
  # Parse command line arguments
  var p = initOptParser()
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "t", "type":
        autoDetect = false
        case p.val.toLowerAscii
        of "library", "lib": projectType = plLibrary
        of "application", "app": projectType = plApplication
        of "hybrid": projectType = plHybrid
        else:
          echo "Unknown project type: ", p.val
          quit(1)
      of "p", "preset":
        preset = p.val.toLowerAscii
      of "no-git":
        createGitignore = false
      of "no-build":
        createBuildDirs = false
      of "force":
        force = true
      of "h", "help":
        printHelp()
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      projectPath = p.key
  
  # Ensure project directory exists
  if not dirExists(projectPath):
    echo "Creating project directory: ", projectPath
    createDir(projectPath)
  
  # Auto-detect project type if not specified
  if autoDetect:
    projectType = detectProjectLayout(projectPath)
    if projectType == plCustom:
      projectType = plStandard  # Default for new projects
  
  # Get standard paths
  let paths = getStandardPaths(projectPath)
  
  # Check for existing configuration
  let configPath = projectPath / paths.configFile
  if fileExists(configPath) and not force:
    echo "Configuration already exists at: ", configPath
    echo "Use --force to overwrite"
    quit(1)
  
  # Initialize project structure
  echo "Initializing ", projectType, " project in: ", projectPath
  
  # Create directories
  echo "Creating directory structure..."
  createDir(projectPath / paths.sourceDir)
  createDir(projectPath / paths.testsDir)
  
  if createBuildDirs:
    createBuildDirectories(paths)
    echo "✓ Created build directories"
  
  # Create configuration based on preset
  echo "Creating configuration (preset: ", preset, ")..."
  var config: TestKitConfig
  
  case preset
  of "minimal":
    config = getPresetConfig("minimal")
  of "strict":
    config = getPresetConfig("strict")
  else:
    config = loadOrCreateConfig(paths)
  
  # Override with detected paths
  config.sourceDir = paths.sourceDir
  config.testsDir = paths.testsDir
  
  # Save configuration
  saveConfig(config, configPath)
  echo "✓ Created ", paths.configFile
  
  # Create .gitignore
  if createGitignore:
    let gitignorePath = projectPath / ".gitignore"
    if not fileExists(gitignorePath):
      writeFile(gitignorePath, """
# Nim TestKit build artifacts
/build/
nimcache/

# Test results
*.xml
*.html
coverage/

# Binary files
*.exe
*.dll
*.so
*.dylib

# Editor files
.vscode/
.idea/
*.swp
""")
      echo "✓ Created .gitignore"
  
  # Create example files based on project type
  case projectType
  of plLibrary:
    let libFile = projectPath / paths.sourceDir / "lib.nim"
    if not fileExists(libFile):
      writeFile(libFile, """
## Main library module

proc greet*(name: string): string =
  ## Returns a personalized greeting
  result = "Hello, " & name & "!"

proc add*(a, b: int): int =
  ## Adds two numbers
  result = a + b
""")
      echo "✓ Created example library file"
    
    let testFile = projectPath / paths.testsDir / "test_lib.nim"
    if not fileExists(testFile):
      writeFile(testFile, """
import unittest
import ../src/lib

suite "Library tests":
  test "greet returns correct greeting":
    check greet("World") == "Hello, World!"
  
  test "add returns correct sum":
    check add(2, 3) == 5
    check add(-1, 1) == 0
""")
      echo "✓ Created example test file"
  
  of plApplication:
    let appFile = projectPath / paths.sourceDir / "main.nim"
    if not fileExists(appFile):
      writeFile(appFile, """
## Main application entry point

import os

proc main() =
  echo "Welcome to your Nim application!"
  
  if paramCount() > 0:
    echo "Arguments: ", commandLineParams()

when isMainModule:
  main()
""")
      echo "✓ Created example application file"
  
  else:
    discard
  
  # Create README if it doesn't exist
  let readmePath = projectPath / "README.md"
  if not fileExists(readmePath):
    let info = detectProjectInfo(projectPath)
    writeFile(readmePath, fmt"""
# {info.name}

{info.description}

## Getting Started

This project uses nim-testkit for automated testing.

### Running Tests

```bash
# Run all tests
nimtestkit_runner

# Run specific test
nimtestkit_runner -p test_name

# Generate missing tests
nimtestkit_generator
```

### Project Structure

```
{info.name}/
├── {paths.sourceDir}/          # Source code
├── {paths.testsDir}/           # Test files
├── {paths.buildDir}/           # Build artifacts (git-ignored)
│   ├── debug/      # Debug builds
│   ├── release/    # Release builds
│   ├── coverage/   # Coverage reports
│   └── test-results/ # Test results
└── {paths.configFile}  # TestKit configuration
```

### Configuration

The project uses minimal configuration in `{paths.configFile}`.
Most settings are automatically detected from the project structure.
""")
    echo "✓ Created README.md"
  
  # Show summary
  echo ""
  styledEcho fgGreen, "✓ Project initialized successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. cd ", projectPath
  echo "  2. nimtestkit_runner    # Run tests"
  echo "  3. nimtestkit_generator # Generate missing tests"
  echo ""
  echo "Build artifacts will be placed in: ", paths.buildDir, "/"
  echo "Test results will be saved to: ", paths.buildDir, "/test-results/"
  echo "Coverage reports will be in: ", paths.buildDir, "/coverage/"

when isMainModule:
  main()