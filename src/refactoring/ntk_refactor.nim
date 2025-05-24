## CLI interface for refactoring helper
## Part of nim-testkit unified CLI (ntk)

import std/[os, strutils, strformat, parseopt, tables]
import ./refactor_helper

proc showHelp() =
  echo """
ntk refactor - Code refactoring and cleanup tools

Usage:
  ntk refactor <command> [options]

Commands:
  analyze         Analyze project for refactoring opportunities
  clean           Clean build artifacts and temporary files
  duplicates      Find and report duplicate files
  unused          Find potentially unused files
  reorganize      Suggest file reorganization by type
  consolidate     Find similar files that could be merged
  deadcode        Detect potentially dead code
  empty-dirs      Find and remove empty directories
  backup          Create backup before refactoring
  help            Show this help message

Options:
  --dry-run       Show what would be done without making changes
  --verbose       Show detailed output
  --backup-dir    Directory for backups (default: .refactor-backup)
  --exclude       Patterns to exclude (can be used multiple times)
  --auto-fix      Automatically fix imports after moving files
  --threshold     Similarity threshold for consolidation (0.0-1.0)

Examples:
  ntk refactor analyze                    # Full analysis report
  ntk refactor clean --dry-run            # Preview cleanup
  ntk refactor duplicates                 # Find duplicate files
  ntk refactor reorganize --dry-run       # Preview reorganization
  ntk refactor consolidate --threshold=0.7 # Find similar files

Safety:
  - Always creates backups before modifications
  - Use --dry-run to preview changes
  - Review suggestions before applying
"""

proc formatBytes(bytes: int64): string =
  ## Format bytes in human-readable form
  if bytes < 1024:
    return fmt"{bytes} B"
  elif bytes < 1024 * 1024:
    return fmt"{bytes div 1024} KB"
  elif bytes < 1024 * 1024 * 1024:
    return fmt"{bytes div (1024 * 1024)} MB"
  else:
    return fmt"{bytes div (1024 * 1024 * 1024)} GB"

proc main() =
  var 
    command = ""
    dryRun = false
    verbose = false
    backupDir = ""
    excludePatterns: seq[string] = @[]
    autoFix = false
    threshold = 0.8
  
  # Parse command line arguments
  var p = initOptParser()
  var argCount = 0
  
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "dry-run":
        dryRun = true
      of "verbose", "v":
        verbose = true
      of "backup-dir":
        backupDir = p.val
      of "exclude":
        excludePatterns.add(p.val)
      of "auto-fix":
        autoFix = true
      of "threshold":
        try:
          threshold = parseFloat(p.val)
        except:
          echo "Invalid threshold value: ", p.val
          quit(1)
      of "help", "h":
        showHelp()
        quit(0)
      else:
        echo "Unknown option: ", p.key
        quit(1)
    of cmdArgument:
      if argCount == 0:
        command = p.key
      inc argCount
  
  if command == "" or command == "help":
    showHelp()
    quit(0)
  
  # Initialize refactor helper
  let rh = newRefactorHelper()
  rh.config.dryRun = dryRun
  rh.config.verbose = verbose
  if backupDir != "":
    rh.config.backupDir = backupDir
  if excludePatterns.len > 0:
    rh.config.excludePatterns = excludePatterns
  rh.config.autoFixImports = autoFix
  
  case command
  of "analyze":
    echo "Analyzing project for refactoring opportunities..."
    echo ""
    let report = rh.generateRefactorReport()
    echo report
    
  of "clean":
    echo "Cleaning build artifacts..."
    let result = rh.cleanBuildArtifacts()
    
    if result.removed.len > 0:
      echo fmt"Removed {result.removed.len} files/directories"
      echo fmt"Freed {formatBytes(result.bytesFreed)} of disk space"
      
      if verbose or dryRun:
        echo "\nRemoved items:"
        for item in result.removed:
          echo "  - ", item
    else:
      echo "No build artifacts found to clean"
    
    if result.errors.len > 0:
      echo "\nErrors:"
      for error in result.errors:
        echo "  ❌ ", error
    
  of "duplicates":
    echo "Finding duplicate files..."
    let duplicates = rh.findDuplicateFiles()
    
    if duplicates.len > 0:
      echo fmt"Found {duplicates.len} groups of duplicate files:"
      echo ""
      
      var totalDuplicates = 0
      var totalBytes: int64 = 0
      
      for hash, files in duplicates:
        echo fmt"Duplicate group (hash: {hash}):"
        for i, file in files:
          let size = getFileSize(file)
          echo fmt"  {i+1}. {file} ({formatBytes(size)})"
          if i > 0:  # Count duplicates (not the first one)
            inc totalDuplicates
            totalBytes += size
        echo ""
      
      echo fmt"Total duplicate files: {totalDuplicates}"
      echo fmt"Potential space savings: {formatBytes(totalBytes)}"
    else:
      echo "No duplicate files found"
    
  of "unused":
    echo "Finding potentially unused files..."
    let unused = rh.findUnusedFiles()
    
    if unused.len > 0:
      echo fmt"Found {unused.len} potentially unused files:"
      echo ""
      
      var totalSize: int64 = 0
      for file in unused:
        let size = getFileSize(file)
        totalSize += size
        echo fmt"  - {file} ({formatBytes(size)})"
      
      echo ""
      echo fmt"Total size: {formatBytes(totalSize)}"
      echo "\nNote: Please review these files before deletion."
      echo "Some may be entry points or used dynamically."
    else:
      echo "No unused files detected"
    
  of "reorganize":
    echo "Analyzing file organization..."
    let plan = rh.reorganizeByType()
    
    if plan.moves.len > 0:
      echo fmt"Suggested moves ({plan.moves.len} files):"
      for move in plan.moves:
        echo fmt"  {move.src}"
        echo fmt"    → {move.dst}"
      
      if not dryRun:
        echo "\nExecute reorganization? [y/N] "
        let answer = stdin.readLine()
        if answer.toLower() == "y":
          let results = rh.executeRefactorPlan(plan)
          for result in results:
            echo result
    else:
      echo "Files are already well organized"
    
    if plan.warnings.len > 0:
      echo "\nWarnings:"
      for warning in plan.warnings:
        echo "  ⚠️  ", warning
    
  of "consolidate":
    echo fmt"Finding similar files (threshold: {threshold})..."
    let plan = rh.consolidateSimilarFiles(threshold)
    
    if plan.warnings.len > 0:
      for warning in plan.warnings:
        echo warning
    else:
      echo "No similar files found for consolidation"
    
  of "deadcode":
    echo "Detecting potentially dead code..."
    let deadCode = rh.detectDeadCode()
    
    if deadCode.len > 0:
      echo fmt"Found {deadCode.len} potential dead code instances:"
      echo ""
      for item in deadCode:
        echo "  - ", item
      echo "\nNote: Some symbols may be used dynamically or exported."
    else:
      echo "No dead code detected"
    
  of "empty-dirs":
    echo "Finding empty directories..."
    let emptyDirs = rh.findEmptyDirectories()
    
    if emptyDirs.len > 0:
      echo fmt"Found {emptyDirs.len} empty directories:"
      for dir in emptyDirs:
        echo "  - ", dir
      
      if not dryRun:
        echo "\nRemove empty directories? [y/N] "
        let answer = stdin.readLine()
        if answer.toLower() == "y":
          for dir in emptyDirs:
            try:
              removeDir(dir)
              echo "✓ Removed: ", dir
            except:
              echo "✗ Failed to remove: ", dir
    else:
      echo "No empty directories found"
    
  of "backup":
    echo "Creating backup of project..."
    let timestamp = now().format("yyyyMMdd_HHmmss")
    let backupPath = rh.config.backupDir / timestamp
    
    # Find all source files
    var files: seq[string] = @[]
    for file in walkDirRec(rh.projectRoot):
      if file.endsWith(".nim") or 
         file.endsWith(".nims") or 
         file.endsWith(".nimble"):
        files.add(file)
    
    rh.createBackup(files)
    echo fmt"✓ Backup created: {backupPath}"
    echo fmt"  Backed up {files.len} files"
    
  else:
    echo fmt"Unknown command: {command}"
    echo "Run 'ntk refactor help' for usage information"
    quit(1)

when isMainModule:
  main()