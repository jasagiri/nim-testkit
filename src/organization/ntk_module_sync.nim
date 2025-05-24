## Command-line interface for module synchronization
## Part of nim-testkit unified CLI (ntk)

import std/[os, strutils, strformat, parseopt, tables]
import ./module_sync

proc showHelp() =
  echo """
ntk module-sync - Module synchronization for nim-testkit

Usage:
  ntk module-sync <command> [options]

Commands:
  list              List all configured modules
  add               Add a new module
  update            Update a specific module
  remove            Remove a module
  sync              Sync all modules
  publish           Publish modules as SDKs
  skip              Add module to skip list
  unskip            Remove module from skip list
  progress          Show sync progress
  help              Show this help message

Examples:
  ntk module-sync add mylib https://github.com/user/mylib.git
  ntk module-sync update mylib
  ntk module-sync sync --resume
  ntk module-sync publish --sdk-dir=dist/sdk
  ntk module-sync skip problematic-module

Options:
  --config=PATH     Path to modules.json config file
  --resume          Resume interrupted sync operation
  --sdk-dir=PATH    Directory for published SDKs
  --branch=NAME     Branch to use (default: main)
"""

proc main() =
  var 
    command = ""
    moduleName = ""
    repoUrl = ""
    configFile = "config/modules.json"
    resume = false
    sdkDir = "sdk"
    branch = "main"
  
  # Parse command line arguments
  var p = initOptParser()
  var argCount = 0
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "config":
        configFile = p.val
      of "resume":
        resume = true
      of "sdk-dir":
        sdkDir = p.val
      of "branch":
        branch = p.val
      of "help", "h":
        showHelp()
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      case argCount
      of 0: command = p.key
      of 1: moduleName = p.key
      of 2: repoUrl = p.key
      else: discard
      inc argCount
  
  if command == "" or command == "help":
    showHelp()
    quit(0)
  
  # Initialize module sync
  let ms = newModuleSync(configFile)
  
  case command
  of "list":
    echo ms.listModules()
    
  of "add":
    if moduleName == "" or repoUrl == "":
      echo "Error: Module name and repository URL required"
      echo "Usage: ntk module-sync add <name> <repo-url> [--branch=main]"
      quit(1)
    
    let result = ms.addModule(moduleName, repoUrl, branch)
    if result.success:
      echo fmt"✓ {result.message}"
    else:
      echo fmt"✗ {result.message}"
      quit(1)
    
  of "update":
    if moduleName == "":
      echo "Error: Module name required"
      echo "Usage: ntk module-sync update <name>"
      quit(1)
    
    let result = ms.updateModule(moduleName)
    if result.success:
      echo fmt"✓ {result.message}"
    else:
      echo fmt"✗ {result.message}"
      quit(1)
    
  of "remove":
    if moduleName == "":
      echo "Error: Module name required"
      echo "Usage: ntk module-sync remove <name>"
      quit(1)
    
    let result = ms.removeModule(moduleName)
    if result.success:
      echo fmt"✓ {result.message}"
    else:
      echo fmt"✗ {result.message}"
      quit(1)
    
  of "sync":
    echo "Syncing all modules..."
    let results = ms.syncAll(resume)
    
    var successCount = 0
    var failureCount = 0
    
    for result in results:
      if result.success:
        inc successCount
        echo fmt"✓ {result.module}: {result.message}"
      else:
        inc failureCount
        echo fmt"✗ {result.module}: {result.message}"
    
    echo fmt"\nSync complete: {successCount} succeeded, {failureCount} failed"
    
    if failureCount > 0:
      quit(1)
    
  of "publish":
    echo fmt"Publishing all modules to {sdkDir}..."
    let results = ms.publishAll(sdkDir)
    
    var successCount = 0
    var failureCount = 0
    
    for result in results:
      if result.success:
        inc successCount
        echo fmt"✓ {result.module}: {result.message}"
      else:
        inc failureCount
        echo fmt"✗ {result.module}: {result.message}"
    
    echo fmt"\nPublish complete: {successCount} succeeded, {failureCount} failed"
    
    if failureCount > 0:
      quit(1)
    
  of "skip":
    if moduleName == "":
      echo "Error: Module name required"
      echo "Usage: ntk module-sync skip <name>"
      quit(1)
    
    ms.skipModule(moduleName)
    echo fmt"✓ Module '{moduleName}' added to skip list"
    
  of "unskip":
    if moduleName == "":
      echo "Error: Module name required"
      echo "Usage: ntk module-sync unskip <name>"
      quit(1)
    
    ms.unskipModule(moduleName)
    echo fmt"✓ Module '{moduleName}' removed from skip list"
    
  of "progress":
    echo ms.showProgress()
    
  else:
    echo fmt"Unknown command: {command}"
    echo "Run 'ntk module-sync help' for usage information"
    quit(1)

when isMainModule:
  main()