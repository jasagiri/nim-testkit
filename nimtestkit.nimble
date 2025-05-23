# Package

version       = "0.0.0"
author        = "jasagiri"
description   = "Generic automated test toolkit for Nim projects"
license       = "MIT"
packageName   = "nimtestkit"
srcDir        = "src"
installExt    = @["nim"]
binDir        = "bin"
bin           = @["test_generator", "test_runner", "test_guard", "coverage_helper", "nimtestkit_setup", "nimtestkit_generator", "nimtestkit_runner"]

# ビルド設定
let
  debugDir = "build/debug"
  releaseDir = "build/release"

# インストール対象ディレクトリ
installDirs   = @["templates"]

# Dependencies

requires "nim >= 1.6.0"
requires "cligen >= 1.5.0"
requires "checksums >= 0.1.0"
requires "https://github.com/jasagiri/nim-power-assert"
requires "https://github.com/jasagiri/mcp-jujutsu"

# Tasks

task generate, "Generate tests for missing functions":
  when defined(windows):
    exec "scripts\\generate\\generate.bat"
  else:
    exec "scripts/generate/generate.sh"

task guard, "Start test guard for continuous testing":
  when defined(windows):
    exec "scripts\\guard\\guard.bat"
  else:
    exec "scripts/guard/guard.sh"

task tests, "Run all automated tests":
  when defined(windows):
    exec "scripts\\run\\run.bat"
  else:
    exec "scripts/run/run.sh"

task coverage, "Generate code coverage data":
  when defined(windows):
    exec "scripts\\coverage\\coverage.bat"
  else:
    exec "scripts/coverage/coverage.sh"
    
task docs, "Generate documentation":
  echo "Generating documentation..."
  let docDir = "docs/api"
  if not dirExists(docDir):
    mkDir(docDir)
  exec "nim doc --project -o:" & docDir & " src/config.nim"
  exec "nim doc --project -o:" & docDir & " src/test_generator.nim"
  exec "nim doc --project -o:" & docDir & " src/test_runner.nim"
  exec "nim doc --project -o:" & docDir & " src/test_guard.nim"
  exec "nim doc --project -o:" & docDir & " src/jujutsu_test_integration.nim"
  exec "nim doc --project -o:" & docDir & " src/mcp/jujutsu.nim"
  exec "nim doc --project -o:" & docDir & " src/coverage_helper.nim"
  exec "nim doc --project -o:" & docDir & " src/doc_generator.nim"
  exec "nim doc --project -o:" & docDir & " src/nimtestkit_setup.nim"
  exec "nim doc --project -o:" & docDir & " src/nimtestkit_generator.nim"
  exec "nim doc --project -o:" & docDir & " src/nimtestkit_runner.nim"
  echo "Documentation generated in " & docDir

task install_hooks, "Install VCS hooks for auto testing":
  when defined(windows):
    exec "scripts\\hooks\\install_hooks.bat"
  else:
    if fileExists("scripts/hooks/install_vcs_hooks.sh"):
      exec "scripts/hooks/install_vcs_hooks.sh"
    else:
      exec "scripts/hooks/install_hooks.sh"

task readme, "Generate README.md":
  when defined(windows):
    if fileExists("scripts\\readme\\readme.bat"):
      exec "scripts\\readme\\readme.bat"
    else:
      echo "README generator not found"
  else:
    if fileExists("scripts/readme/readme.sh"):
      exec "scripts/readme/readme.sh"
    else:
      echo "README generator not found"

task test, "Run toolkit self-tests":
  # Compile and run the basic test
  echo "Running basic structure tests..."
  exec "nim c -r tests/test_basic.nim"
  
  # Run Unix-specific tests if on Unix
  when not defined(windows):
    echo "Running Unix-specific executable permission tests..."
    exec "nim c -r tests/test_unix_specific.nim"
  
  # Run new tests
  echo "Running configuration tests..."
  exec "nim c -r tests/test_config.nim"
  
  echo "Running Jujutsu integration tests..."
  exec "nim c -r tests/test_jujutsu.nim"
  
  echo "Running enhanced generator tests..."
  exec "nim c -r tests/test_enhanced_generator.nim"
  
  echo "Running enhanced runner tests..."
  exec "nim c -r tests/test_runner_simple.nim"
  
  echo "Running test for guard..."
  exec "nim c -r tests/test_guard.nim"
  
  echo "Running test for coverage helper..."
  exec "nim c -r tests/test_coverage_helper.nim"
  
  echo "Running VCS commands tests..."
  exec "nim c -r tests/test_vcs_commands.nim"
  
  echo "Running MCP integration tests..."
  exec "nim c -r tests/test_mcp_integration.nim"
  
  echo "Running documentation generator tests..."
  exec "nim c -r tests/test_doc_generator.nim"
  
  echo "Running test generator tests..."
  exec "nim c -r tests/test_generator.nim"
  
  # If we get here, all tests succeeded
  echo "All tests completed successfully!"

# ビルド関連のタスク
task build_debug, "Build debug version":
  # 必要なディレクトリを作成
  let archDir = 
    when defined(windows): "windows"
    elif defined(macosx): "macos"
    elif defined(linux): "linux"
    else: "unknown"
  
  let targetDir = debugDir & "/" & archDir
  if not dirExists(targetDir):
    mkDir(targetDir)

  # すべての実行ファイルをビルド
  for binFile in bin:
    echo "Building " & binFile & " (debug)..."
    exec "nim c -o:" & targetDir & "/" & binFile & " src/" & binFile & ".nim"
  
  echo "Debug build complete. Binaries are in " & targetDir

task build_release, "Build release version":
  # 必要なディレクトリを作成
  let archDir = 
    when defined(windows): "windows"
    elif defined(macosx): "macos"
    elif defined(linux): "linux"
    else: "unknown"
  
  let targetDir = releaseDir & "/" & archDir
  if not dirExists(targetDir):
    mkDir(targetDir)

  # すべての実行ファイルをリリースモードでビルド
  for binFile in bin:
    echo "Building " & binFile & " (release)..."
    exec "nim c -d:release -o:" & targetDir & "/" & binFile & " src/" & binFile & ".nim"
  
  echo "Release build complete. Binaries are in " & targetDir

task dist, "Create distribution binaries":
  # リリースビルドを実行
  exec "nimble build_release"
  
  # binディレクトリが存在しなければ作成
  if not dirExists(binDir):
    mkDir(binDir)
  
  # リリースビルドからbinディレクトリにコピー
  let archDir = 
    when defined(windows): "windows"
    elif defined(macosx): "macos"
    elif defined(linux): "linux"
    else: "unknown"
  
  let sourceDir = releaseDir & "/" & archDir
  echo "Copying binaries from " & sourceDir & " to " & binDir & "..."
  
  for binFile in bin:
    let source = sourceDir & "/" & binFile
    let dest = binDir & "/" & binFile
    echo "  " & source & " -> " & dest
    cpFile(source, dest)
  
  echo "Distribution binaries created in " & binDir

# セットアップタスク
task setup, "Setup TestKit in a project":
  if paramCount() < 3:
    echo "Usage: nimble setup <project_dir>"
    quit(1)
  
  let projectDir = paramStr(3)
  exec "nimtestkit_setup " & projectDir

# MCP Integration Tasks
task mcp_setup, "Set up MCP integration for VCS operations":
  exec "nim c --hints:off -r -d:mcp_setup src/mcp_commands.nim"

task mcp_status, "Show MCP server status":
  exec "nim c --hints:off -r -d:mcp_status src/mcp_commands.nim"

task mcp_stop, "Stop all MCP servers":
  exec "nim c --hints:off -r -d:mcp_stop src/mcp_commands.nim"

task mcp_list_tools, "List available MCP tools":
  exec "nim c --hints:off -r -d:mcp_list_tools src/mcp_commands.nim"

task mcp_git, "Execute Git operations via MCP":
  exec "nim c --hints:off -r -d:mcp_git src/mcp_commands.nim"

task mcp_github, "Execute GitHub operations via MCP":
  exec "nim c --hints:off -r -d:mcp_github src/mcp_commands.nim"

task mcp_gitlab, "Execute GitLab operations via MCP":
  exec "nim c --hints:off -r -d:mcp_gitlab src/mcp_commands.nim"

task mcp_jujutsu, "Execute Jujutsu operations via MCP":
  exec "nim c --hints:off -r -d:mcp_jujutsu src/mcp_commands.nim"

task mcp_help, "Show MCP help information":
  exec "nim c --hints:off -r -d:mcp_help src/mcp_commands.nim"

# Advanced Testing Tasks
task mutation, "Run mutation testing":
  when defined(windows):
    exec "powershell -ExecutionPolicy Bypass -File scripts/advanced/mutation.ps1"
  else:
    exec "bash scripts/advanced/mutation.sh"

task fuzz, "Run fuzz testing":
  when defined(windows):
    exec "powershell -ExecutionPolicy Bypass -File scripts/advanced/fuzz.ps1"
  else:
    exec "bash scripts/advanced/fuzz.sh"

task benchmark, "Run benchmark tests":
  exec "nim c --hints:off -r -d:benchmark src/advanced_testing.nim"

task contract, "Run contract testing":
  exec "nim c --hints:off -r -d:contract src/advanced_testing.nim"

task integration, "Run integration tests":
  exec "nim c --hints:off -r -d:integration src/advanced_testing.nim"

# Platform-Specific Testing Tasks
task test_windows, "Run Windows-specific tests":
  when defined(windows):
    exec "nim c --hints:off -r -d:windows tests/platform/windows_test.nim"
  else:
    echo "Windows tests can only be run on Windows"

task test_macos, "Run macOS-specific tests":
  when defined(macosx):
    exec "nim c --hints:off -r -d:macosx tests/platform/macos_test.nim"
  else:
    echo "macOS tests can only be run on macOS"

task test_mobile, "Run mobile platform tests":
  when defined(ios):
    exec "nim c --hints:off -r -d:ios tests/platform/mobile_test.nim"
  elif defined(android):
    exec "nim c --hints:off -r -d:android tests/platform/mobile_test.nim"
  else:
    echo "Mobile tests require iOS or Android target"

task test_wasm, "Run WebAssembly tests":
  exec "nim js -d:js -o:build/wasm_test.js tests/platform/wasm_test.nim"
  echo "Open build/wasm_test.html in a browser to run WebAssembly tests"

task advanced_generate, "Generate advanced test types":
  exec "nim c --hints:off -r -d:advanced_generate src/advanced_testing.nim"
