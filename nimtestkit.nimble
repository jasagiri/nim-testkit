# Package
version       = "0.0.0"
author        = "jasagiri"
description   = "Minimal, zero-dependency test framework for Nim"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 2.2.0"

# Tasks
task test, "Run nim-testkit tests":
  exec "./scripts/run_tests.sh"

task test_coverage, "Run tests with coverage analysis":
  exec "nim c -d:coverage --passC:--coverage --passL:--coverage -r tests/test_all.nim"
  echo "Coverage report generated"

task test_unit, "Run only unit tests":
  exec "nim c -r tests/spec/unit/test_core_types.nim"
  exec "nim c -r tests/spec/unit/test_core_results.nim"
  exec "nim c -r tests/spec/unit/test_core_runner.nim"
  exec "nim c -r tests/spec/unit/test_mece_detector.nim"
  exec "nim c -r tests/spec/unit/test_config_parser.nim"
  exec "nim c -r tests/spec/unit/test_nimtestkit.nim"

task example, "Run example tests":
  exec "nim c -r examples/basic_example.nim"

task mece, "Analyze MECE test structure":
  exec "nim c -r src/nimtestkit.nim --analyze-mece"

task mece_generate, "Generate MECE test structure":
  exec "nim c -r src/nimtestkit.nim --generate-mece"

task config_generate, "Generate default configuration":
  exec "nim c -r src/nimtestkit.nim --generate-config"

task docs, "Generate documentation":
  exec "nim doc --project --index:on --outdir:docs/api src/nimtestkit.nim"

task clean, "Clean build artifacts":
  rmDir "docs/api"
  rmFile "nimtestkit"
  for file in listFiles("."):
    if file.endsWith(".gcno") or file.endsWith(".gcda"):
      rmFile file
