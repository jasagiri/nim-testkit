## Module synchronization functionality for nim-testkit
## Replaces sh-module-sync shell scripts with native Nim implementation

import std/[os, json, strutils, sequtils, tables, times, strformat, asyncdispatch]
import ./config

type
  ModuleConfig* = object
    name*: string
    repoUrl*: string
    branch*: string
    path*: string  # Local path for the module
    
  SyncProgress* = object
    inProgress*: bool
    currentModule*: string
    timestamp*: string
    operation*: string  # "sync" or "publish"
    
  ModuleSync* = ref object
    configFile*: string
    progressFile*: string
    modules*: seq[ModuleConfig]
    skipList*: seq[string]
    progress*: SyncProgress
    
  SyncResult* = object
    success*: bool
    message*: string
    module*: string

proc newModuleSync*(configFile = "config/modules.json"): ModuleSync =
  ## Create a new module sync manager
  result = ModuleSync(
    configFile: configFile,
    progressFile: "config/.sync-progress.json",
    modules: @[],
    skipList: @[]
  )
  result.loadConfig()
  result.loadProgress()

proc loadConfig*(ms: ModuleSync) =
  ## Load module configuration from JSON file
  if not fileExists(ms.configFile):
    # Create default config if it doesn't exist
    let defaultConfig = %*{
      "modules": []
    }
    createDir(ms.configFile.parentDir())
    writeFile(ms.configFile, defaultConfig.pretty())
    return
    
  try:
    let configData = parseFile(ms.configFile)
    if configData.hasKey("modules"):
      for moduleNode in configData["modules"]:
        var module = ModuleConfig(
          name: moduleNode["name"].getStr(),
          repoUrl: moduleNode["repo_url"].getStr(),
          branch: moduleNode.getOrDefault("branch", %"main").getStr()
        )
        module.path = "modules" / module.name
        ms.modules.add(module)
  except:
    echo "Error loading module configuration: ", getCurrentExceptionMsg()

proc saveConfig*(ms: ModuleSync) =
  ## Save module configuration to JSON file
  var configData = %*{
    "modules": []
  }
  
  for module in ms.modules:
    configData["modules"].add(%*{
      "name": module.name,
      "repo_url": module.repoUrl,
      "branch": module.branch
    })
  
  writeFile(ms.configFile, configData.pretty())

proc loadProgress*(ms: ModuleSync) =
  ## Load sync progress information
  if not fileExists(ms.progressFile):
    ms.progress = SyncProgress(inProgress: false)
    return
    
  try:
    let progressData = parseFile(ms.progressFile)
    ms.progress = SyncProgress(
      inProgress: progressData.getOrDefault("in_progress", %false).getBool(),
      currentModule: progressData.getOrDefault("current_module", %"").getStr(),
      timestamp: progressData.getOrDefault("timestamp", %"").getStr(),
      operation: progressData.getOrDefault("operation", %"").getStr()
    )
    
    if progressData.hasKey("skip_list"):
      for skip in progressData["skip_list"]:
        ms.skipList.add(skip.getStr())
  except:
    ms.progress = SyncProgress(inProgress: false)

proc saveProgress*(ms: ModuleSync) =
  ## Save sync progress information
  let progressData = %*{
    "in_progress": ms.progress.inProgress,
    "current_module": ms.progress.currentModule,
    "timestamp": ms.progress.timestamp,
    "operation": ms.progress.operation,
    "skip_list": ms.skipList
  }
  writeFile(ms.progressFile, progressData.pretty())

proc execCommand*(cmd: string): tuple[output: string, exitCode: int] =
  ## Execute a shell command and return output and exit code
  try:
    let (output, exitCode) = gorgeEx(cmd)
    result = (output, exitCode)
  except:
    result = (getCurrentExceptionMsg(), 1)

proc checkGitRepo*(): bool =
  ## Check if current directory is a git repository
  let (_, exitCode) = execCommand("git rev-parse --git-dir")
  result = exitCode == 0

proc checkJujutsu*(): bool =
  ## Check if jujutsu is available and initialized
  let (_, exitCode) = execCommand("jj --version")
  if exitCode != 0:
    return false
  let (_, repoCheck) = execCommand("jj status")
  result = repoCheck == 0

proc addModule*(ms: ModuleSync, name, repoUrl: string, branch = "main"): SyncResult =
  ## Add a new module to the configuration
  # Check if module already exists
  for module in ms.modules:
    if module.name == name:
      return SyncResult(success: false, message: "Module already exists", module: name)
  
  # Validate repository URL
  if not (repoUrl.startsWith("https://") or repoUrl.startsWith("git@")):
    return SyncResult(success: false, message: "Invalid repository URL", module: name)
  
  # Add module to configuration
  let newModule = ModuleConfig(
    name: name,
    repoUrl: repoUrl,
    branch: branch,
    path: "modules" / name
  )
  ms.modules.add(newModule)
  ms.saveConfig()
  
  # Add module using git subtree
  if checkGitRepo():
    let cmd = fmt"git subtree add --prefix={newModule.path} {repoUrl} {branch} --squash"
    let (output, exitCode) = execCommand(cmd)
    if exitCode != 0:
      return SyncResult(success: false, message: "Failed to add module: " & output, module: name)
  
  result = SyncResult(success: true, message: "Module added successfully", module: name)

proc updateModule*(ms: ModuleSync, name: string): SyncResult =
  ## Update a specific module from upstream
  var moduleConfig: ModuleConfig
  var found = false
  
  for module in ms.modules:
    if module.name == name:
      moduleConfig = module
      found = true
      break
  
  if not found:
    return SyncResult(success: false, message: "Module not found", module: name)
  
  # Skip if in skip list
  if name in ms.skipList:
    return SyncResult(success: false, message: "Module is in skip list", module: name)
  
  # Update progress
  ms.progress.inProgress = true
  ms.progress.currentModule = name
  ms.progress.timestamp = $now()
  ms.progress.operation = "update"
  ms.saveProgress()
  
  # Perform update using git subtree
  if checkGitRepo():
    let cmd = fmt"git subtree pull --prefix={moduleConfig.path} {moduleConfig.repoUrl} {moduleConfig.branch} --squash"
    let (output, exitCode) = execCommand(cmd)
    
    if exitCode != 0:
      return SyncResult(success: false, message: "Failed to update: " & output, module: name)
  
  # Clear progress
  ms.progress.inProgress = false
  ms.progress.currentModule = ""
  ms.saveProgress()
  
  result = SyncResult(success: true, message: "Module updated successfully", module: name)

proc removeModule*(ms: ModuleSync, name: string): SyncResult =
  ## Remove a module from the project
  var moduleIdx = -1
  var moduleConfig: ModuleConfig
  
  for i, module in ms.modules:
    if module.name == name:
      moduleIdx = i
      moduleConfig = module
      break
  
  if moduleIdx == -1:
    return SyncResult(success: false, message: "Module not found", module: name)
  
  # Remove from file system
  if dirExists(moduleConfig.path):
    removeDir(moduleConfig.path)
  
  # Remove from git if in git repo
  if checkGitRepo():
    discard execCommand(fmt"git rm -rf {moduleConfig.path}")
    discard execCommand(fmt"git commit -m 'Remove module {name}'")
  
  # Remove from configuration
  ms.modules.delete(moduleIdx)
  ms.saveConfig()
  
  # Remove from skip list if present
  ms.skipList = ms.skipList.filterIt(it != name)
  ms.saveProgress()
  
  result = SyncResult(success: true, message: "Module removed successfully", module: name)

proc syncAll*(ms: ModuleSync, resume = false): seq[SyncResult] =
  ## Synchronize all modules
  result = @[]
  
  var startIdx = 0
  if resume and ms.progress.inProgress:
    # Find where to resume
    for i, module in ms.modules:
      if module.name == ms.progress.currentModule:
        startIdx = i
        break
  
  for i in startIdx..<ms.modules.len:
    let module = ms.modules[i]
    
    # Skip if in skip list
    if module.name in ms.skipList:
      result.add(SyncResult(success: false, message: "Skipped", module: module.name))
      continue
    
    echo fmt"Syncing module {i+1}/{ms.modules.len}: {module.name}"
    let syncResult = ms.updateModule(module.name)
    result.add(syncResult)
    
    if not syncResult.success:
      echo fmt"Error syncing {module.name}: {syncResult.message}"

proc skipModule*(ms: ModuleSync, name: string) =
  ## Add a module to the skip list
  if name notin ms.skipList:
    ms.skipList.add(name)
    ms.saveProgress()

proc unskipModule*(ms: ModuleSync, name: string) =
  ## Remove a module from the skip list
  ms.skipList = ms.skipList.filterIt(it != name)
  ms.saveProgress()

proc listModules*(ms: ModuleSync): string =
  ## List all configured modules
  result = "Configured Modules:\n"
  result &= "==================\n\n"
  
  for i, module in ms.modules:
    let status = if module.name in ms.skipList: " [SKIPPED]" else: ""
    result &= fmt"{i+1}. {module.name}{status}\n"
    result &= fmt"   Repository: {module.repoUrl}\n"
    result &= fmt"   Branch: {module.branch}\n"
    result &= fmt"   Path: {module.path}\n"
    result &= "\n"
  
  if ms.skipList.len > 0:
    result &= "\nSkipped Modules:\n"
    result &= "===============\n"
    for skip in ms.skipList:
      result &= fmt"- {skip}\n"

proc showProgress*(ms: ModuleSync): string =
  ## Show current sync progress
  result = "Sync Progress:\n"
  result &= "=============\n\n"
  
  if ms.progress.inProgress:
    result &= fmt"Status: IN PROGRESS\n"
    result &= fmt"Current Module: {ms.progress.currentModule}\n"
    result &= fmt"Operation: {ms.progress.operation}\n"
    result &= fmt"Started: {ms.progress.timestamp}\n"
  else:
    result &= "Status: No operation in progress\n"

proc publishModule*(ms: ModuleSync, name: string, targetDir: string): SyncResult =
  ## Publish a module as an SDK
  var moduleConfig: ModuleConfig
  var found = false
  
  for module in ms.modules:
    if module.name == name:
      moduleConfig = module
      found = true
      break
  
  if not found:
    return SyncResult(success: false, message: "Module not found", module: name)
  
  # Create target directory
  createDir(targetDir)
  
  # Copy module files
  let sourceDir = moduleConfig.path
  if not dirExists(sourceDir):
    return SyncResult(success: false, message: "Module directory not found", module: name)
  
  # Use rsync or cp to copy files
  let cmd = fmt"cp -R {sourceDir}/* {targetDir}/"
  let (output, exitCode) = execCommand(cmd)
  
  if exitCode != 0:
    return SyncResult(success: false, message: "Failed to publish: " & output, module: name)
  
  result = SyncResult(success: true, message: "Module published successfully", module: name)

proc publishAll*(ms: ModuleSync, sdkDir = "sdk"): seq[SyncResult] =
  ## Publish all modules as SDKs
  result = @[]
  createDir(sdkDir)
  
  for module in ms.modules:
    if module.name in ms.skipList:
      result.add(SyncResult(success: false, message: "Skipped", module: module.name))
      continue
    
    let targetDir = sdkDir / module.name
    echo fmt"Publishing {module.name} to {targetDir}"
    let publishResult = ms.publishModule(module.name, targetDir)
    result.add(publishResult)

# Async versions for better performance
proc syncAllAsync*(ms: ModuleSync): Future[seq[SyncResult]] {.async.} =
  ## Asynchronously sync all modules
  result = @[]
  
  for module in ms.modules:
    if module.name in ms.skipList:
      result.add(SyncResult(success: false, message: "Skipped", module: module.name))
      continue
    
    # In a real implementation, this would use async processes
    let syncResult = ms.updateModule(module.name)
    result.add(syncResult)
    
    # Small delay to not overwhelm the system
    await sleepAsync(100)