## Example demonstrating standard project layout usage

import ../src/standard_layout
import std/[os, strformat]

proc demonstrateStandardLayout() =
  echo "=== Nim TestKit Standard Layout Demo ==="
  echo ""
  
  # Detect current project layout
  let currentLayout = detectProjectLayout()
  echo "Current project layout: ", currentLayout
  
  # Get standard paths
  let paths = getStandardPaths()
  echo "\nStandard paths detected:"
  echo "  Source dir: ", paths.sourceDir
  echo "  Tests dir: ", paths.testsDir
  echo "  Build dir: ", paths.buildDir
  echo "  Config file: ", paths.configFile
  
  # Show build artifact paths
  echo "\nBuild artifact examples:"
  echo "  Debug binary: ", getBuildArtifactPath(paths, "myapp", release = false)
  echo "  Release lib: ", getBuildArtifactPath(paths, "mylib.so", release = true)
  echo "  Test results: ", getTestResultsPath(paths, "junit")
  echo "  Coverage: ", getCoveragePath(paths)
  
  # Demonstrate project info detection
  let info = detectProjectInfo()
  echo "\nProject information:"
  echo "  Name: ", info.name
  echo "  Layout: ", info.layout
  if info.version != "":
    echo "  Version: ", info.version
  if info.author != "":
    echo "  Author: ", info.author

proc demonstrateMinimalConfig() =
  echo "\n=== Minimal Configuration ==="
  
  # Show how little config is needed
  echo """
With standard layout, you typically need NO configuration file!

If you do need one, here's a minimal example:

```toml
# nimtestkit.toml - only override what's different
[tests]
parallel = false  # Only if you want sequential tests
```

Everything else is auto-detected from your project structure.
"""

proc demonstrateInitialization() =
  echo "\n=== Project Initialization ==="
  echo """
To create a new project with standard layout:

  nimtestkit_init myproject           # Auto-detect type
  nimtestkit_init -t library mylib    # Library project
  nimtestkit_init -t application app  # Application project
  
This creates:
  - Standard directory structure
  - Minimal config (if needed)
  - .gitignore with build/
  - Example source and test files
  - README.md template
"""

proc demonstrateBuildDirectory() =
  echo "\n=== Build Directory Organization ==="
  
  let exampleTree = """
build/
├── debug/
│   ├── myapp              # Debug binary
│   └── mylib.so          # Debug library
├── release/
│   ├── myapp             # Release binary
│   └── mylib.so         # Release library
├── test-results/
│   ├── test_results_20240124_143022.xml
│   └── test_results_20240124_143022.tap
├── coverage/
│   ├── coverage.html     # HTML report
│   └── coverage.json     # JSON data
├── cache/                # Compilation cache
└── test-summary.txt      # Latest test summary
"""
  
  echo "All build artifacts go into the build/ directory:"
  echo exampleTree
  echo "This keeps your source tree clean and makes cleanup easy!"

proc demonstrateWorkflow() =
  echo "\n=== Typical Workflow ==="
  echo """
1. Initialize project:
   $ nimtestkit_init myproject
   $ cd myproject

2. Write code in src/:
   $ edit src/mylib.nim

3. Run tests (auto-finds them):
   $ nimtestkit_runner
   
4. Generate missing tests:
   $ nimtestkit_generator
   
5. Check coverage:
   $ nimtestkit coverage
   $ open build/coverage/coverage.html
   
6. Clean build artifacts:
   $ rm -rf build/
   
No configuration needed at any step!
"""

when isMainModule:
  demonstrateStandardLayout()
  demonstrateMinimalConfig()
  demonstrateInitialization()
  demonstrateBuildDirectory()
  demonstrateWorkflow()
  
  echo "\n=== Benefits ==="
  echo "✓ Zero configuration for most projects"
  echo "✓ Consistent structure across all projects"
  echo "✓ Clean separation of source and build artifacts"
  echo "✓ Easy cleanup and gitignore management"
  echo "✓ Familiar to developers from other ecosystems"