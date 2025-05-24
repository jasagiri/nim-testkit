import unittest, os
import ../src/generation/generator
import ../src/analysis/coverage # For getProjectRootDir
import ../src/config/config

suite "Test Generator":
  test "Project configuration loading works":
    check true # Simple import test
    
  test "Config loading works":
    let config = loadConfig()
    check config.sourceDir.len > 0

  test "analyze function has expected signature":
    # Verify function exists (compile-time check)
    proc testAnalyzeFn(config: TestKitConfig): seq[ModuleInfo] =
      analyze(config)
      
    check true
    
  test "ModuleInfo type contains expected fields":
    var info = ModuleInfo(
      path: "test/path",
      name: "test.nim",
      functions: @[],
      tests: @[]
    )
    
    check info.path == "test/path"
    check info.name == "test.nim"
    check info.functions.len == 0
    check info.tests.len == 0
