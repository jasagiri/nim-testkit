import std/[unittest, os]

suite "Simple Validation":
  test "nim-testkit structure exists":
    check fileExists("../src/config/config.nim")
    check fileExists("../src/execution/runner.nim")
    check fileExists("../src/generation/generator.nim")
    check fileExists("../src/analysis/coverage.nim")
    check fileExists("../src/organization/standard_layout.nim")
    check fileExists("../src/cli/ntk.nim")
    
  test "comprehensive tests created":
    check fileExists("test_config_comprehensive.nim")
    check fileExists("test_standard_layout_comprehensive.nim")
    check fileExists("test_integrations_comprehensive.nim")
    check fileExists("test_test_runner_comprehensive.nim")
    check fileExists("test_test_generator_comprehensive.nim")
    check fileExists("test_coverage_helper_comprehensive.nim")
    check fileExists("test_nimtestkit_init_comprehensive.nim")
    check fileExists("test_ntk_comprehensive.nim")
    check fileExists("test_test_guard_comprehensive.nim")
    check fileExists("test_mece_test_organizer_comprehensive.nim")
    
  test "test runner script exists":
    check fileExists("run_all_tests.nim")
    check fileExists("../run_tests.sh")
    
  test "configuration files exist":
    check fileExists("nim.cfg")
    check fileExists("panicoverride.nim")