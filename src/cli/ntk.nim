## Unified CLI entry point for nim-testkit
## Provides short command: ntk

import std/[os, strutils, parseopt, terminal]

const Version = "0.1.0"

proc showHelp() =
  echo """
ntk - Nim TestKit CLI

Usage: ntk <command> [options]

Commands:
  init          Initialize project with standard layout (nimtestkit_init)
  test          Run tests (nimtestkit_runner)
  gen           Generate missing tests (nimtestkit_generator)
  cov           Generate coverage report (coverage_helper)
  watch         Watch for changes and run tests (test_guard)
  module-sync   Manage external modules (replaces sh-module-sync)
  refactor      Code refactoring and cleanup tools
  
  # Shortcuts
  i             Alias for 'init'
  t             Alias for 'test'
  g             Alias for 'gen'
  c             Alias for 'cov'
  w             Alias for 'watch'
  ms            Alias for 'module-sync'
  rf            Alias for 'refactor'

Options:
  -h, --help     Show help for a command
  -v, --version  Show version

Examples:
  ntk init                      # Initialize new project
  ntk test                      # Run all tests
  ntk test -p pattern           # Run tests matching pattern
  ntk gen                       # Generate missing tests
  ntk cov                       # Generate coverage report
  ntk watch                     # Start test watcher
  ntk module-sync list          # List configured modules
  ntk ms add lib https://...    # Add a module (using alias)

Project: https://github.com/nim-testkit/nim-testkit
"""

proc runCommand(cmd: string, args: seq[string]) =
  ## Execute the actual tool with arguments
  let actualCmd = case cmd
  of "init", "i": "nimtestkit_init"
  of "test", "t": "nimtestkit_runner"
  of "gen", "g": "nimtestkit_generator"
  of "cov", "c": "coverage_helper"
  of "watch", "w": "test_guard"
  of "module-sync", "ms": "ntk_module_sync"
  of "refactor", "rf": "ntk_refactor"
  else: ""
  
  if actualCmd == "":
    echo "Unknown command: ", cmd
    echo "Run 'ntk --help' for usage"
    quit(1)
  
  # Build command with arguments
  var fullCmd = actualCmd
  for arg in args:
    fullCmd.add(" ")
    fullCmd.add(arg.quoteShell)
  
  # Execute
  let exitCode = execShellCmd(fullCmd)
  quit(exitCode)

proc main() =
  var p = initOptParser()
  var command = ""
  var commandArgs: seq[string] = @[]
  
  # Parse first argument as command
  p.next()
  case p.kind
  of cmdArgument:
    command = p.key
  of cmdLongOption:
    case p.key
    of "help", "h":
      showHelp()
      quit(0)
    of "version", "v":
      echo "ntk version ", Version
      quit(0)
    else:
      discard
  else:
    showHelp()
    quit(0)
  
  # Collect remaining arguments for the subcommand
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdArgument:
      commandArgs.add(p.key)
    of cmdShortOption, cmdLongOption:
      if p.val == "":
        commandArgs.add("-" & p.key)
      else:
        commandArgs.add("-" & p.key & "=" & p.val)
  
  if command == "":
    showHelp()
    quit(0)
  
  runCommand(command, commandArgs)

when isMainModule:
  main()