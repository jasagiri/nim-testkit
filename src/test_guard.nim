## Nim TestKit Guard
##
## Monitors for source code changes and automatically runs tests

import std/[os, osproc, times, strformat, terminal]

# Get root directory
proc getProjectRootDir*(): string =
  result = getCurrentDir() / "../../../"
  
  # Fallback if run directly
  if not dirExists(result / "src"):
    result = getCurrentDir() / "../../"
    
  # Normalize the path
  result = result.normalizedPath

# Function to check directory for changes
proc getLatestModTime*(dir: string, pattern = "*.nim"): Time =
  var latestTime: Time
  var hasFile = false
  
  # First find any matching file to initialize the time
  for file in walkFiles(dir / pattern):
    latestTime = file.getLastModificationTime()
    hasFile = true
    break
  
  # If no files found, return empty time
  if not hasFile:
    return latestTime
  
  # Check all files
  for file in walkFiles(dir / pattern):
    let fileTime = file.getLastModificationTime()
    if fileTime > latestTime:
      latestTime = fileTime
  
  # Also check subdirectories
  for subdir in walkDirs(dir / "*"):
    for file in walkFiles(subdir / pattern):
      let fileTime = file.getLastModificationTime()
      if fileTime > latestTime:
        latestTime = fileTime
  
  return latestTime

proc runTestGuard*() =
  echo "===== Nim TestKit Guard ====="
  echo "Monitoring for source code changes..."
  
  let 
    rootDir = getProjectRootDir()
    sourceDir = rootDir / "src"
    testsDir = rootDir / "tests"
    scriptsDir = rootDir / "scripts"
  
  if not dirExists(sourceDir):
    echo "Error: Source directory not found at " & sourceDir
    quit(1)
  
  if not dirExists(testsDir):
    echo "Error: Tests directory not found at " & testsDir
    quit(1)
  
  var 
    lastSourceTime: Time
    lastScriptsTime: Time
    lastCheckTime = cpuTime()
    checkInterval = 5.0  # Check every 5 seconds
    runCount = 0
    indicatorState = 0
    indicatorChars = @["|", "/", "-", "\\"]
  
  # Main monitoring loop
  while true:
    # Get current time
    let currentTime = cpuTime()
    
    # Check if it's time to scan files
    if currentTime - lastCheckTime >= checkInterval:
      lastCheckTime = currentTime
      
      # Check for source modifications
      let 
        currentSourceTime = getLatestModTime(sourceDir)
        currentScriptsTime = getLatestModTime(scriptsDir)
      
      # If source files changed since last check
      if currentSourceTime > lastSourceTime or currentScriptsTime > lastScriptsTime:
        # Clear previous progress indicator
        stdout.eraseLine()
        stdout.flushFile()
        
        # Update timestamps
        lastSourceTime = currentSourceTime
        lastScriptsTime = currentScriptsTime
        runCount += 1
        
        # Print change information
        let changeTime = if currentSourceTime > currentScriptsTime: currentSourceTime else: currentScriptsTime
        let changeTimeStr = $changeTime.format("yyyy-MM-dd HH:mm:ss")
        echo fmt"[{changeTimeStr}] Source code changes detected (run #{runCount})"
        
        # Run test generator
        echo "Regenerating tests..."
        discard execCmd(fmt"cd {getCurrentDir()}/.. && nimble generate")
        
        # Run tests
        echo "Running tests..."
        discard execCmd(fmt"cd {getCurrentDir()}/.. && nimble run")
      
      # Show progress indicator
      indicatorState = (indicatorState + 1) mod indicatorChars.len
      let timeStr = $now().format("HH:mm:ss")
      stdout.write(fmt"\r[{timeStr}] Monitoring for changes {indicatorChars[indicatorState]}")
      stdout.flushFile()
    
    # Prevent CPU spinning
    sleep(1000)

when isMainModule:
  runTestGuard()