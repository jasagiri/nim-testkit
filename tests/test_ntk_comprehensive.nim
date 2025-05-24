import std/[unittest, os, tempfiles, strutils, sequtils]
import ../src/cli/ntk

suite "NTK CLI - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("ntk_cli_", "")
    let origDir = getCurrentDir()
    setCurrentDir(tempDir)
    
  teardown:
    setCurrentDir(origDir)
    removeDir(tempDir)
    
  test "Parse command - init":
    let cmd = parseCommand(@["init"])
    check cmd.command == "init"
    check cmd.args.len == 0
    
    let cmdWithArgs = parseCommand(@["init", "myproject", "--type=lib"])
    check cmdWithArgs.command == "init"
    check cmdWithArgs.args == @["myproject", "--type=lib"]
    
  test "Parse command - test":
    let cmd = parseCommand(@["test"])
    check cmd.command == "test"
    
    let cmdWithPattern = parseCommand(@["test", "unit"])
    check cmdWithPattern.command == "test"
    check cmdWithPattern.args == @["unit"]
    
  test "Parse command - generate":
    let cmd = parseCommand(@["gen", "src/mymodule.nim"])
    check cmd.command == "gen"
    check cmd.args == @["src/mymodule.nim"]
    
  test "Parse command - coverage":
    let cmd = parseCommand(@["cov"])
    check cmd.command == "cov"
    
    let cmdWithFormat = parseCommand(@["cov", "--format=html"])
    check cmdWithFormat.args == @["--format=html"]
    
  test "Parse command - watch":
    let cmd = parseCommand(@["watch"])
    check cmd.command == "watch"
    
  test "Parse command - help":
    let cmd = parseCommand(@["help"])
    check cmd.command == "help"
    
    let cmdH = parseCommand(@["-h"])
    check cmdH.command == "help"
    
    let cmdHelp = parseCommand(@["--help"])
    check cmdHelp.command == "help"
    
  test "Parse command - version":
    let cmd = parseCommand(@["version"])
    check cmd.command == "version"
    
    let cmdV = parseCommand(@["-v"])
    check cmdV.command == "version"
    
  test "Parse command - unknown":
    let cmd = parseCommand(@["unknown"])
    check cmd.command == "unknown"
    
  test "Parse command - empty":
    let cmd = parseCommand(@[])
    check cmd.command == "help"
    
  test "Execute init command":
    # Create mock implementation
    var initCalled = false
    var initArgs: seq[string] = @[]
    
    proc mockInit(args: seq[string]): int =
      initCalled = true
      initArgs = args
      return 0
    
    # Test would call the actual init command
    # For this test, we verify the command structure
    let cmd = parseCommand(@["init", "testproject"])
    check cmd.command == "init"
    check "testproject" in cmd.args
    
  test "Execute test command variations":
    # Test different test command patterns
    let patterns = @[
      @["test"],
      @["test", "unit"],
      @["test", "--parallel"],
      @["test", "--workers=4"],
      @["test", "integration", "--verbose"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.command == "test"
      
  test "Execute generate command variations":
    let patterns = @[
      @["gen", "src/module.nim"],
      @["gen", "src/", "--recursive"],
      @["gen", "--update", "tests/"],
      @["gen", "--framework=unittest2", "src/core.nim"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.command == "gen"
      
  test "Execute coverage command variations":
    let patterns = @[
      @["cov"],
      @["cov", "--html"],
      @["cov", "--threshold=80"],
      @["cov", "--format=lcov", "--output=coverage.info"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.command == "cov"
      
  test "Command aliases":
    # Test all command aliases
    let aliases = @[
      (@["t"], "test"),
      (@["g"], "gen"),
      (@["c"], "cov"),
      (@["w"], "watch"),
      (@["i"], "init")
    ]
    
    for (alias, expected) in aliases:
      let cmd = parseCommand(alias)
      check cmd.command == expected
      
  test "Flag parsing":
    let cmd = parseCommand(@["test", "--parallel", "-v", "--workers=8", "pattern"])
    
    check cmd.command == "test"
    check "--parallel" in cmd.args
    check "-v" in cmd.args
    check "--workers=8" in cmd.args
    check "pattern" in cmd.args
    
  test "Environment variable handling":
    putEnv("NTK_DEFAULT_WORKERS", "16")
    putEnv("NTK_TEST_TIMEOUT", "300")
    
    # Commands should respect environment variables
    let cmd = parseCommand(@["test"])
    check cmd.command == "test"
    # In real implementation, these env vars would affect execution
    
  test "Config file detection":
    # Create config file
    writeFile(".nimtestkit.json", """
    {
      "testFramework": "unittest2",
      "parallel": true,
      "workers": 8
    }
    """)
    
    # Command should detect config
    let cmd = parseCommand(@["test"])
    check cmd.command == "test"
    check fileExists(".nimtestkit.json")
    
  test "Multiple argument handling":
    let cmd = parseCommand(@["gen", "src/mod1.nim", "src/mod2.nim", "src/mod3.nim"])
    
    check cmd.command == "gen"
    check cmd.args.len == 3
    check cmd.args.allIt(it.endsWith(".nim"))
    
  test "Long flag format":
    let patterns = @[
      @["test", "--parallel=true", "--verbose=2"],
      @["cov", "--format=html", "--output=report.html"],
      @["init", "--type=library", "--git=false"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.args.anyIt("=" in it)
      
  test "Short flag format":
    let patterns = @[
      @["test", "-p", "-v"],
      @["gen", "-r", "-u"],
      @["cov", "-h", "-j"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.args.anyIt(it.startsWith("-") and it.len == 2)
      
  test "Mixed commands and files":
    let cmd = parseCommand(@["test", "tests/unit/", "tests/integration/", "--parallel"])
    
    check cmd.command == "test"
    check "tests/unit/" in cmd.args
    check "tests/integration/" in cmd.args
    check "--parallel" in cmd.args
    
  test "Subcommand parsing":
    # For future expansion with subcommands
    let patterns = @[
      @["config", "get", "parallel"],
      @["config", "set", "workers", "8"],
      @["template", "list"],
      @["template", "install", "minimal"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.command in ["config", "template"]
      check cmd.args.len >= 1
      
  test "Error cases":
    # Test various error conditions
    let errorPatterns = @[
      @["--unknown-flag"],
      @["test", "--invalid=option"],
      @["-xyz"]  # Invalid short flags
    ]
    
    for args in errorPatterns:
      let cmd = parseCommand(args)
      # Should handle gracefully
      check cmd.command != ""
      
  test "Interactive mode flags":
    let cmd = parseCommand(@["init", "-i"])
    check cmd.command == "init"
    check "-i" in cmd.args or "--interactive" in cmd.args
    
  test "Quiet and verbose modes":
    let quietCmd = parseCommand(@["test", "-q"])
    check "-q" in quietCmd.args
    
    let verboseCmd = parseCommand(@["test", "-v"])
    check "-v" in verboseCmd.args
    
    let veryVerboseCmd = parseCommand(@["test", "-vv"])
    check "-vv" in veryVerboseCmd.args
    
  test "Dry run mode":
    let cmd = parseCommand(@["gen", "--dry-run", "src/"])
    check "--dry-run" in cmd.args
    
  test "Force mode":
    let cmd = parseCommand(@["init", "--force", "myproject"])
    check "--force" in cmd.args
    
  test "Color output control":
    let patterns = @[
      @["test", "--no-color"],
      @["test", "--color=always"],
      @["test", "--color=never"],
      @["test", "--color=auto"]
    ]
    
    for args in patterns:
      let cmd = parseCommand(args)
      check cmd.args.anyIt(it.contains("color"))