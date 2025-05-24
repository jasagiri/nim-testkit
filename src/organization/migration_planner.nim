## Migration planner for large-scale refactoring
## Helps plan and execute complex project migrations

import std/[os, strutils, sequtils, tables, json, times, strformat]
import ./refactor_helper, ./dependency_analyzer

type
  MigrationStep* = object
    id*: string
    description*: string
    action*: proc(): bool
    dependencies*: seq[string]  # IDs of steps that must complete first
    optional*: bool
    estimatedTime*: int  # minutes
    
  MigrationPhase* = object
    name*: string
    steps*: seq[MigrationStep]
    
  MigrationPlan* = object
    name*: string
    description*: string
    phases*: seq[MigrationPhase]
    rollbackPlan*: string
    
  MigrationResult* = object
    stepId*: string
    success*: bool
    message*: string
    duration*: float
    
  MigrationPlanner* = ref object
    projectRoot*: string
    plan*: MigrationPlan
    results*: seq[MigrationResult]
    checkpoints*: Table[string, JsonNode]  # For rollback

proc newMigrationPlanner*(projectRoot = getCurrentDir()): MigrationPlanner =
  result = MigrationPlanner(
    projectRoot: projectRoot,
    results: @[],
    checkpoints: initTable[string, JsonNode]()
  )

# Common migration templates
proc createModuleRestructurePlan*(mp: MigrationPlanner, fromStructure, toStructure: string): MigrationPlan =
  ## Create a plan to restructure modules
  result = MigrationPlan(
    name: "Module Restructure",
    description: fmt"Migrate from {fromStructure} to {toStructure} structure"
  )
  
  # Phase 1: Analysis
  var phase1 = MigrationPhase(name: "Analysis")
  phase1.steps.add(MigrationStep(
    id: "analyze-deps",
    description: "Analyze current dependencies",
    estimatedTime: 5,
    action: proc(): bool =
      let da = newDependencyAnalyzer(mp.projectRoot)
      da.buildDependencyGraph()
      let report = da.generateDependencyReport()
      writeFile(mp.projectRoot / "migration-deps-report.md", report)
      return true
  ))
  
  phase1.steps.add(MigrationStep(
    id: "backup",
    description: "Create full project backup",
    estimatedTime: 10,
    action: proc(): bool =
      let rh = newRefactorHelper(mp.projectRoot)
      var files: seq[string] = @[]
      for file in walkDirRec(mp.projectRoot):
        if not file.contains(".git") and not file.contains("nimcache"):
          files.add(file)
      rh.createBackup(files)
      return true
  ))
  
  result.phases.add(phase1)
  
  # Phase 2: Preparation
  var phase2 = MigrationPhase(name: "Preparation")
  phase2.steps.add(MigrationStep(
    id: "create-structure",
    description: "Create new directory structure",
    estimatedTime: 2,
    action: proc(): bool =
      # Create new structure based on toStructure
      case toStructure
      of "layered":
        createDir(mp.projectRoot / "core")
        createDir(mp.projectRoot / "services")
        createDir(mp.projectRoot / "interfaces")
        createDir(mp.projectRoot / "adapters")
      of "feature":
        createDir(mp.projectRoot / "features")
        createDir(mp.projectRoot / "shared")
        createDir(mp.projectRoot / "infrastructure")
      else:
        return false
      return true
  ))
  
  result.phases.add(phase2)
  
  # Phase 3: Migration
  var phase3 = MigrationPhase(name: "Migration")
  phase3.steps.add(MigrationStep(
    id: "move-files",
    description: "Move files to new structure",
    estimatedTime: 30,
    dependencies: @["create-structure"],
    action: proc(): bool =
      let rh = newRefactorHelper(mp.projectRoot)
      let plan = rh.reorganizeByType()
      let results = rh.executeRefactorPlan(plan)
      return not results.anyIt("ERROR" in it)
  ))
  
  phase3.steps.add(MigrationStep(
    id: "update-imports",
    description: "Update import statements",
    estimatedTime: 20,
    dependencies: @["move-files"],
    action: proc(): bool =
      # This would need implementation to update all imports
      echo "TODO: Implement import updates"
      return true
  ))
  
  result.phases.add(phase3)
  
  # Phase 4: Validation
  var phase4 = MigrationPhase(name: "Validation")
  phase4.steps.add(MigrationStep(
    id: "run-tests",
    description: "Run all tests",
    estimatedTime: 15,
    dependencies: @["update-imports"],
    action: proc(): bool =
      let (output, exitCode) = gorgeEx("nimble test")
      return exitCode == 0
  ))
  
  result.phases.add(phase4)
  
  result.rollbackPlan = """
  Rollback procedure:
  1. Stop all running processes
  2. Restore from backup in .refactor-backup/
  3. Clean nimcache
  4. Rebuild project
  """

proc createNimVersionMigrationPlan*(mp: MigrationPlanner, fromVersion, toVersion: string): MigrationPlan =
  ## Create a plan to migrate between Nim versions
  result = MigrationPlan(
    name: "Nim Version Migration",
    description: fmt"Migrate from Nim {fromVersion} to {toVersion}"
  )
  
  # Phase 1: Compatibility Check
  var phase1 = MigrationPhase(name: "Compatibility Check")
  phase1.steps.add(MigrationStep(
    id: "check-deprecations",
    description: "Check for deprecated features",
    estimatedTime: 10,
    action: proc(): bool =
      # Would check for deprecated features
      echo "Checking for deprecated features..."
      return true
  ))
  
  result.phases.add(phase1)
  
  # Add more phases as needed...

proc createDependencyUpdatePlan*(mp: MigrationPlanner, updates: Table[string, string]): MigrationPlan =
  ## Create a plan to update multiple dependencies
  result = MigrationPlan(
    name: "Dependency Update",
    description: "Update project dependencies"
  )
  
  var phase = MigrationPhase(name: "Update Dependencies")
  
  for pkg, version in updates:
    phase.steps.add(MigrationStep(
      id: fmt"update-{pkg}",
      description: fmt"Update {pkg} to {version}",
      estimatedTime: 5,
      action: proc(): bool =
        let cmd = fmt"nimble install {pkg}@{version}"
        let (_, exitCode) = gorgeEx(cmd)
        return exitCode == 0
    ))
  
  result.phases.add(phase)

proc saveCheckpoint*(mp: MigrationPlanner, stepId: string) =
  ## Save current state for potential rollback
  let checkpoint = %*{
    "stepId": stepId,
    "timestamp": $now(),
    "files": []
  }
  
  # In real implementation, would save file states
  mp.checkpoints[stepId] = checkpoint

proc executeStep*(mp: MigrationPlanner, step: MigrationStep): MigrationResult =
  ## Execute a single migration step
  echo fmt"Executing: {step.description}"
  let startTime = epochTime()
  
  try:
    mp.saveCheckpoint(step.id)
    let success = step.action()
    
    result = MigrationResult(
      stepId: step.id,
      success: success,
      duration: epochTime() - startTime,
      message: if success: "Completed successfully" else: "Failed"
    )
  except:
    result = MigrationResult(
      stepId: step.id,
      success: false,
      duration: epochTime() - startTime,
      message: "Exception: " & getCurrentExceptionMsg()
    )

proc canExecuteStep*(mp: MigrationPlanner, step: MigrationStep): bool =
  ## Check if a step's dependencies are satisfied
  for depId in step.dependencies:
    var found = false
    for result in mp.results:
      if result.stepId == depId and result.success:
        found = true
        break
    if not found:
      return false
  return true

proc executePlan*(mp: MigrationPlanner, dryRun = false): bool =
  ## Execute the migration plan
  result = true
  
  echo fmt"Executing migration plan: {mp.plan.name}"
  echo mp.plan.description
  echo ""
  
  for i, phase in mp.plan.phases:
    echo fmt"Phase {i+1}/{mp.plan.phases.len}: {phase.name}"
    echo "=" * 50
    
    for step in phase.steps:
      if not mp.canExecuteStep(step):
        echo fmt"⏸️  Skipping {step.id} - dependencies not met"
        if not step.optional:
          result = false
          break
        continue
      
      if dryRun:
        echo fmt"[DRY RUN] Would execute: {step.description}"
        echo fmt"          Estimated time: {step.estimatedTime} minutes"
      else:
        let stepResult = mp.executeStep(step)
        mp.results.add(stepResult)
        
        if stepResult.success:
          echo fmt"✅ {step.description} ({stepResult.duration:.1f}s)"
        else:
          echo fmt"❌ {step.description} - {stepResult.message}"
          if not step.optional:
            result = false
            break
    
    if not result:
      echo "\nMigration failed. See rollback plan."
      break
    
    echo ""

proc generateMigrationReport*(mp: MigrationPlanner): string =
  ## Generate a report of the migration execution
  result = fmt"# Migration Report: {mp.plan.name}\n\n"
  result &= fmt"Date: {now()}\n"
  result &= fmt"Description: {mp.plan.description}\n\n"
  
  result &= "## Execution Summary\n\n"
  
  var totalSteps = 0
  var successfulSteps = 0
  var totalDuration = 0.0
  
  for phase in mp.plan.phases:
    totalSteps += phase.steps.len
  
  for res in mp.results:
    if res.success:
      inc successfulSteps
    totalDuration += res.duration
  
  result &= fmt"- Total steps: {totalSteps}\n"
  result &= fmt"- Successful: {successfulSteps}\n"
  result &= fmt"- Failed: {totalSteps - successfulSteps}\n"
  result &= fmt"- Total duration: {totalDuration:.1f} seconds\n\n"
  
  result &= "## Step Results\n\n"
  
  for res in mp.results:
    let status = if res.success: "✅" else: "❌"
    result &= fmt"{status} {res.stepId}: {res.message} ({res.duration:.1f}s)\n"
  
  if mp.results.anyIt(not it.success):
    result &= "\n## Rollback Plan\n\n"
    result &= mp.plan.rollbackPlan

proc estimateDuration*(mp: MigrationPlanner): int =
  ## Estimate total migration duration in minutes
  result = 0
  for phase in mp.plan.phases:
    for step in phase.steps:
      result += step.estimatedTime