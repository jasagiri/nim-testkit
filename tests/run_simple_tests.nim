## Simple test runner that avoids memory management issues
import std/[os, strformat]

proc runTest(testFile: string): bool =
  echo &"Running {testFile}..."
  let cmd = &"nim c --mm:refc --hints:off -r {testFile}"
  let exitCode = execShellCmd(cmd)
  result = exitCode == 0
  if result:
    echo &"✓ {testFile} passed"
  else:
    echo &"✗ {testFile} failed"

proc main() =
  echo "nim-testkit Test Suite"
  echo "====================="
  
  var passed = 0
  var failed = 0
  
  # List of comprehensive tests
  let tests = @[
    "test_config_comprehensive.nim",
    "test_standard_layout_comprehensive.nim", 
    "test_integrations_comprehensive.nim",
    "test_test_runner_comprehensive.nim",
    "test_test_generator_comprehensive.nim",
    "test_coverage_helper_comprehensive.nim",
    "test_nimtestkit_init_comprehensive.nim",
    "test_ntk_comprehensive.nim",
    "test_test_guard_comprehensive.nim",
    "test_mece_test_organizer_comprehensive.nim"
  ]
  
  echo &"\nFound {tests.len} comprehensive test files"
  echo ""
  
  for test in tests:
    if fileExists(test):
      if runTest(test):
        inc passed
      else:
        inc failed
    else:
      echo &"! {test} not found"
      inc failed
  
  echo "\nTest Summary"
  echo "============"
  echo &"Total:  {tests.len}"
  echo &"Passed: {passed}"
  echo &"Failed: {failed}"
  
  if failed == 0:
    echo "\nAll tests passed! ✨"
    quit(0)
  else:
    echo "\nSome tests failed! ❌"
    quit(1)

when isMainModule:
  main()