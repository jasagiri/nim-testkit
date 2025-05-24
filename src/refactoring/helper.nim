## Refactoring helper for nim-testkit
## Provides tools for safe code refactoring, cleanup, and reorganization

import std/[os, strutils, sequtils, tables, sets, times, json, re, algorithm, strformat]
import ./config, ./standard_layout

type
  FileInfo* = object
    path*: string
    size*: int64
    modified*: Time
    hash*: string
    
  DependencyInfo* = object
    file*: string
    imports*: seq[string]
    exports*: seq[string]
    
  RefactorPlan* = object
    moves*: seq[tuple[src, dst: string]]
    deletes*: seq[string]
    renames*: seq[tuple[old, new: string]]
    warnings*: seq[string]
    
  CleanupResult* = object
    removed*: seq[string]
    bytesFreed*: int64
    errors*: seq[string]
    
  RefactorHelper* = ref object
    projectRoot*: string
    config*: RefactorConfig
    fileCache*: Table[string, FileInfo]
    dependencies*: Table[string, DependencyInfo]
    
  RefactorConfig* = object
    dryRun*: bool
    verbose*: bool
    backupDir*: string
    excludePatterns*: seq[string]
    includePatterns*: seq[string]
    autoFixImports*: bool
    preserveHistory*: bool

# File patterns for different file types
const
  SourcePatterns = @["*.nim", "*.nims", "*.nimble"]
  TestPatterns = @["test_*.nim", "*_test.nim", "t_*.nim"]
  DocPatterns = @["*.md", "*.rst", "*.txt", "*.adoc"]
  ConfigPatterns = @["*.json", "*.toml", "*.yaml", "*.yml", "*.cfg", "*.ini"]
  BuildArtifacts = @[
    "nimcache/", "build/", "dist/", "*.exe", "*.dll", "*.so", "*.dylib",
    "*.o", "*.obj", "*.pdb", "*.ilk", "*.exp", "*.lib", "*.a"
  ]

proc newRefactorHelper*(projectRoot = getCurrentDir()): RefactorHelper =
  result = RefactorHelper(
    projectRoot: projectRoot,
    config: RefactorConfig(
      dryRun: false,
      verbose: false,
      backupDir: projectRoot / ".refactor-backup",
      excludePatterns: @[".git/", ".svn/", ".hg/", "node_modules/", "vendor/"],
      autoFixImports: true,
      preserveHistory: true
    ),
    fileCache: initTable[string, FileInfo](),
    dependencies: initTable[string, DependencyInfo]()
  )

# File analysis functions
proc getFileHash(path: string): string =
  ## Calculate simple hash of file contents
  if not fileExists(path):
    return ""
  try:
    let content = readFile(path)
    result = $hash(content)
  except:
    result = ""

proc analyzeFile(rh: RefactorHelper, path: string): FileInfo =
  ## Analyze a single file
  if path in rh.fileCache:
    return rh.fileCache[path]
    
  result = FileInfo(
    path: path,
    size: getFileSize(path),
    modified: getLastModificationTime(path),
    hash: getFileHash(path)
  )
  rh.fileCache[path] = result

proc findDuplicateFiles*(rh: RefactorHelper): Table[string, seq[string]] =
  ## Find duplicate files based on content hash
  var hashGroups = initTable[string, seq[string]]()
  
  for file in walkDirRec(rh.projectRoot):
    if file.endsWith(".nim") or file.endsWith(".nims"):
      let info = rh.analyzeFile(file)
      if info.hash != "":
        if info.hash notin hashGroups:
          hashGroups[info.hash] = @[]
        hashGroups[info.hash].add(file)
  
  # Return only groups with duplicates
  for hash, files in hashGroups:
    if files.len > 1:
      result[hash] = files

proc findUnusedFiles*(rh: RefactorHelper): seq[string] =
  ## Find potentially unused files (not imported by any other file)
  var imported = initHashSet[string]()
  var allFiles = initHashSet[string]()
  
  # Collect all Nim files and their imports
  for file in walkDirRec(rh.projectRoot):
    if file.endsWith(".nim") or file.endsWith(".nims"):
      allFiles.incl(file)
      
      try:
        let content = readFile(file)
        # Simple import detection (could be improved with proper parsing)
        let importRe = re"import\s+([^,\s]+)"
        for match in content.findAll(importRe):
          let importPath = match.strip()
          imported.incl(importPath)
          imported.incl(importPath & ".nim")
          imported.incl(rh.projectRoot / importPath & ".nim")
      except:
        discard
  
  # Find files not imported anywhere
  for file in allFiles:
    let fileName = file.extractFilename()
    let fileBase = fileName.changeFileExt("")
    
    # Skip main files, tests, and config files
    if fileName == "main.nim" or 
       fileName.startsWith("test_") or
       fileName.endsWith("_test.nim") or
       file.contains("/tests/") or
       file.endsWith(".nims") or
       file.endsWith(".nimble"):
      continue
      
    # Check if file is imported
    var isImported = false
    for imp in imported:
      if fileBase in imp or file in imp:
        isImported = true
        break
        
    if not isImported:
      result.add(file)

proc findEmptyDirectories*(rh: RefactorHelper): seq[string] =
  ## Find empty directories that can be removed
  result = @[]
  
  proc isEmpty(dir: string): bool =
    for entry in walkDir(dir):
      return false
    return true
  
  for dir in walkDirRec(rh.projectRoot, yieldFilter = {pcDir}):
    if isEmpty(dir) and not any(rh.config.excludePatterns, proc(p: string): bool = p in dir):
      result.add(dir)

proc cleanBuildArtifacts*(rh: RefactorHelper): CleanupResult =
  ## Remove build artifacts and temporary files
  result = CleanupResult()
  
  for pattern in BuildArtifacts:
    for file in walkPattern(rh.projectRoot / "**" / pattern):
      if rh.config.dryRun:
        echo "[DRY RUN] Would remove: ", file
        result.removed.add(file)
      else:
        try:
          let size = getFileSize(file)
          if file.dirExists:
            removeDir(file)
          else:
            removeFile(file)
          result.removed.add(file)
          result.bytesFreed += size
        except:
          result.errors.add("Failed to remove: " & file & " - " & getCurrentExceptionMsg())

proc cleanUnusedImports*(rh: RefactorHelper, file: string): string =
  ## Remove unused imports from a file
  if not fileExists(file):
    return ""
    
  let content = readFile(file)
  var lines = content.splitLines()
  var usedSymbols = initHashSet[string]()
  
  # Collect all used symbols (simplified - real implementation would use AST)
  for line in lines:
    if not line.strip().startsWith("import"):
      # Extract identifiers (simplified)
      for word in line.split(re"[^a-zA-Z0-9_]"):
        if word.len > 0:
          usedSymbols.incl(word)
  
  # Check each import
  var newLines: seq[string] = @[]
  for line in lines:
    if line.strip().startsWith("import"):
      # Extract imported module name (simplified)
      let importedModule = line.strip().split()[1].split("/")[^1]
      if importedModule in usedSymbols or rh.config.verbose:
        newLines.add(line)
      else:
        if rh.config.verbose:
          echo "Removing unused import: ", importedModule, " from ", file
    else:
      newLines.add(line)
  
  result = newLines.join("\n")

proc reorganizeByType*(rh: RefactorHelper): RefactorPlan =
  ## Create a plan to reorganize files by type (following standard layout)
  result = RefactorPlan()
  let layout = detectProjectLayout(rh.projectRoot)
  
  for file in walkDirRec(rh.projectRoot):
    let fileName = file.extractFilename()
    let relPath = file.relativePath(rh.projectRoot)
    
    # Skip if already in correct location or excluded
    if any(rh.config.excludePatterns, proc(p: string): bool = p in relPath):
      continue
    
    # Determine target location based on file type
    var targetDir = ""
    
    # Test files
    if fileName.startsWith("test_") or fileName.endsWith("_test.nim"):
      if file.contains("/unit/"):
        targetDir = layout.unitTestDir
      elif file.contains("/integration/"):
        targetDir = layout.integrationTestDir
      else:
        targetDir = layout.testDir
    
    # Documentation
    elif any(DocPatterns, proc(p: string): bool = fileName.endsWith(p.substr(1))):
      targetDir = layout.docsDir
    
    # Configuration files
    elif any(ConfigPatterns, proc(p: string): bool = fileName.endsWith(p.substr(1))):
      targetDir = rh.projectRoot / "config"
    
    # Source files
    elif fileName.endsWith(".nim"):
      if "example" in fileName.toLower or "demo" in fileName.toLower:
        targetDir = rh.projectRoot / "examples"
      else:
        targetDir = layout.srcDir
    
    # Move if needed
    if targetDir != "" and not file.startsWith(targetDir):
      let targetPath = targetDir / fileName
      if not fileExists(targetPath):
        result.moves.add((src: file, dst: targetPath))
      else:
        result.warnings.add(fmt"Cannot move {file} to {targetPath}: target exists")

proc consolidateSimilarFiles*(rh: RefactorHelper, threshold = 0.8): RefactorPlan =
  ## Find and suggest consolidation of similar files
  result = RefactorPlan()
  
  # Simple similarity check based on file names and basic content analysis
  var fileGroups = initTable[string, seq[string]]()
  
  for file in walkDirRec(rh.projectRoot):
    if file.endsWith(".nim"):
      let baseName = file.extractFilename().toLower()
      # Remove common prefixes/suffixes
      let normalized = baseName
        .replace("test_", "")
        .replace("_test", "")
        .replace("_utils", "")
        .replace("_helper", "")
        .replace("_common", "")
      
      if normalized notin fileGroups:
        fileGroups[normalized] = @[]
      fileGroups[normalized].add(file)
  
  # Suggest consolidation for groups with multiple files
  for base, files in fileGroups:
    if files.len > 1:
      result.warnings.add(fmt"Similar files found that might be consolidated:")
      for file in files:
        result.warnings.add(fmt"  - {file}")

proc detectDeadCode*(rh: RefactorHelper): seq[string] =
  ## Detect potentially dead code (unused functions, types, etc.)
  result = @[]
  
  # Build symbol usage map
  var definedSymbols = initTable[string, string]()  # symbol -> file
  var usedSymbols = initHashSet[string]()
  
  for file in walkDirRec(rh.projectRoot):
    if file.endsWith(".nim"):
      try:
        let content = readFile(file)
        
        # Find definitions (simplified - real implementation would use AST)
        for match in content.findAll(re"proc\s+(\w+)\*|func\s+(\w+)\*|type\s+(\w+)\*"):
          let symbol = match.strip().split()[1].replace("*", "")
          definedSymbols[symbol] = file
        
        # Find usages
        for line in content.splitLines():
          if not (line.strip().startsWith("proc") or 
                  line.strip().startsWith("func") or
                  line.strip().startsWith("type")):
            for word in line.split(re"[^a-zA-Z0-9_]"):
              if word.len > 0:
                usedSymbols.incl(word)
      except:
        discard
  
  # Find unused symbols
  for symbol, file in definedSymbols:
    if symbol notin usedSymbols:
      result.add(fmt"{file}: Unused symbol '{symbol}'")

proc createBackup*(rh: RefactorHelper, files: seq[string]) =
  ## Create backup of files before modification
  if not rh.config.preserveHistory:
    return
    
  let timestamp = now().format("yyyyMMdd_HHmmss")
  let backupRoot = rh.config.backupDir / timestamp
  
  for file in files:
    let relPath = file.relativePath(rh.projectRoot)
    let backupPath = backupRoot / relPath
    
    createDir(backupPath.parentDir())
    copyFile(file, backupPath)

proc executeRefactorPlan*(rh: RefactorHelper, plan: RefactorPlan): seq[string] =
  ## Execute a refactoring plan
  result = @[]
  
  # Create backups
  var affectedFiles: seq[string] = @[]
  for move in plan.moves:
    affectedFiles.add(move.src)
  for rename in plan.renames:
    affectedFiles.add(rename.old)
  affectedFiles.add(plan.deletes)
  
  if not rh.config.dryRun and affectedFiles.len > 0:
    rh.createBackup(affectedFiles)
  
  # Execute moves
  for move in plan.moves:
    if rh.config.dryRun:
      result.add(fmt"[DRY RUN] Move: {move.src} -> {move.dst}")
    else:
      try:
        createDir(move.dst.parentDir())
        moveFile(move.src, move.dst)
        result.add(fmt"Moved: {move.src} -> {move.dst}")
        
        # Update imports if enabled
        if rh.config.autoFixImports:
          # This would need a proper implementation
          result.add(fmt"TODO: Update imports for {move.dst}")
      except:
        result.add(fmt"ERROR: Failed to move {move.src}: {getCurrentExceptionMsg()}")
  
  # Execute renames
  for rename in plan.renames:
    if rh.config.dryRun:
      result.add(fmt"[DRY RUN] Rename: {rename.old} -> {rename.new}")
    else:
      try:
        moveFile(rename.old, rename.new)
        result.add(fmt"Renamed: {rename.old} -> {rename.new}")
      except:
        result.add(fmt"ERROR: Failed to rename {rename.old}: {getCurrentExceptionMsg()}")
  
  # Execute deletes
  for file in plan.deletes:
    if rh.config.dryRun:
      result.add(fmt"[DRY RUN] Delete: {file}")
    else:
      try:
        if file.dirExists:
          removeDir(file)
        else:
          removeFile(file)
        result.add(fmt"Deleted: {file}")
      except:
        result.add(fmt"ERROR: Failed to delete {file}: {getCurrentExceptionMsg()}")

proc generateRefactorReport*(rh: RefactorHelper): string =
  ## Generate a comprehensive refactoring report
  result = "# Refactoring Analysis Report\n\n"
  result &= fmt"Project: {rh.projectRoot}\n"
  result &= fmt"Date: {now()}\n\n"
  
  # Duplicate files
  result &= "## Duplicate Files\n"
  let duplicates = rh.findDuplicateFiles()
  if duplicates.len > 0:
    for hash, files in duplicates:
      result &= fmt"- Hash {hash}:\n"
      for file in files:
        result &= fmt"  - {file}\n"
  else:
    result &= "No duplicate files found.\n"
  
  result &= "\n## Potentially Unused Files\n"
  let unused = rh.findUnusedFiles()
  if unused.len > 0:
    for file in unused:
      result &= fmt"- {file}\n"
  else:
    result &= "No unused files detected.\n"
  
  result &= "\n## Empty Directories\n"
  let emptyDirs = rh.findEmptyDirectories()
  if emptyDirs.len > 0:
    for dir in emptyDirs:
      result &= fmt"- {dir}\n"
  else:
    result &= "No empty directories found.\n"
  
  result &= "\n## Build Artifacts\n"
  rh.config.dryRun = true
  let cleanup = rh.cleanBuildArtifacts()
  if cleanup.removed.len > 0:
    result &= fmt"Found {cleanup.removed.len} artifacts:\n"
    for file in cleanup.removed[0..min(10, cleanup.removed.len-1)]:
      result &= fmt"- {file}\n"
    if cleanup.removed.len > 10:
      result &= fmt"... and {cleanup.removed.len - 10} more\n"
  else:
    result &= "No build artifacts found.\n"
  
  result &= "\n## Recommended Actions\n"
  result &= "1. Review and remove duplicate files\n"
  result &= "2. Check if unused files can be deleted\n"
  result &= "3. Clean empty directories\n"
  result &= "4. Run 'clean' to remove build artifacts\n"