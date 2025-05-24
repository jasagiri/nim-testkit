## Nim TestKit Automated Test Generator
##
## This tool analyzes a Nim codebase and generates test files
## for functions that don't have associated tests.

import std/[os, strutils, strformat, sequtils]
import ../config/config
import ../integrations/lang/[lang_core_integration, design_patterns_integration, optional_dependencies]

# Conditional imports
whenVCS:
  import ../integrations/vcs/common
else:
  # Stub for when VCS is disabled
  type VCSInterface* = object
  proc getVCSStatusSummary*(vcs: VCSInterface): string = "VCS integration disabled"

when EnableJujutsu or EnableMCP:
  import ../advanced/testing
  import ../utils/platform

type
  ProjectConfig* = TestKitConfig
    
  ModuleInfo* = object
    path*: string
    name*: string
    functions*: seq[FunctionInfo]
    tests*: seq[string]
    
  FunctionInfo* = object
    name*: string
    signature*: string
    hasTest*: bool

proc loadProjectConfig(): ProjectConfig =
  ## Loads project configuration from nimtestkit.toml or defaults
  result = loadConfig()
  
  let configFile = "nimtestkit.toml"
  if fileExists(configFile):
    echo fmt"Config file found: {configFile}"
  else:
    echo "Using default configuration"
    echo "Creating default nimtestkit.toml..."
    createDefaultConfigFile()

proc analyze*(config: ProjectConfig): seq[ModuleInfo] =
  ## Analyzes the codebase and returns module information using Factory pattern
  # Create module analyzer factory
  var analyzerFactory = newTestFactory[proc(file: string): ModuleInfo]()
  
  # Register analyzers for different file types
  analyzerFactory.register("nim", proc(): proc(file: string): ModuleInfo =
    proc(file: string): ModuleInfo =
      var moduleInfo = ModuleInfo(
        path: file,
        name: extractFilename(file),
        functions: @[],
        tests: @[]
      )
      # Analysis logic will be added below
      moduleInfo
  )
  
  result = @[]

  # Process .nim files in the source directory
  for pattern in config.includePatterns:
    for file in walkFiles(config.sourceDir / pattern):
      let fileName = extractFilename(file)
      
      # Skip excluded files
      var skip = false
      for excludePattern in config.excludePatterns:
        if fileName.contains(excludePattern.replace("*", "")):
          skip = true
          break
      
      if skip:
        continue
      
      var moduleInfo = ModuleInfo(
        path: file,
        name: fileName,
        functions: @[],
        tests: @[]
      )
      
      # Extract function definitions
      let content = readFile(file)
      for line in content.splitLines():
        var trimmedLine = line.strip()
        
        # Enhanced function detection
        if (trimmedLine.startsWith("proc ") or 
            trimmedLine.startsWith("method ") or
            trimmedLine.startsWith("func ") or
            trimmedLine.startsWith("template ") or
            trimmedLine.startsWith("macro ")):
          
          # Only consider exported functions
          if line.contains("*") and not line.contains("forward"):
            var name = ""
            var signature = trimmedLine
            let isAsync = signature.contains("{.async.}")
            
            # Extract function name
            let funcType = trimmedLine.split(" ")[0]
            var remaining = trimmedLine[funcType.len..^1].strip()
            
            if remaining.contains("("):
              name = remaining.split("(")[0].strip()
              # Remove the * from exported names
              if name.endsWith("*"):
                name = name[0..^2]
            else:
              # Handle functions without parameters
              let parts = remaining.split(":", 1)
              if parts.len > 0:
                name = parts[0].strip()
                if name.endsWith("*"):
                  name = name[0..^2]
            
            # Add the function if we could extract its name
            if name.len > 0:
              moduleInfo.functions.add(FunctionInfo(
                name: name,
                signature: signature,
                hasTest: false
              ))
      
      # Find corresponding test files
      let baseName = moduleInfo.name.replace(".nim", "")
      let testFileName = config.testNamePattern.replace("${module}", baseName)
      
      # Check for test files matching the pattern
      for testFile in walkFiles(config.testsDir / testFileName):
        moduleInfo.tests.add(testFile)
        
        # Analyze test file to determine which functions are covered
        let testContent = readFile(testFile)
        for i, fn in moduleInfo.functions:
          if testContent.contains(fn.name):
            moduleInfo.functions[i].hasTest = true
      
      # Add to result
      result.add(moduleInfo)

proc generateTestFile*(config: ProjectConfig, module: ModuleInfo, isNew = true) =
  ## Generates a test file for a module using Builder pattern
  # Create test file builder
  let testBuilder = newTestConfigBuilder()
    .withTimeout("10s")
    .withReporter("junit")
    .withParallel(config.parallelTests)
  
  let baseName = module.name.replace(".nim", "")
  let testFileName = config.testNamePattern.replace("${module}", baseName)
  let testFilePath = config.testsDir / testFileName
  
  var testContent = ""
  
  if isNew:
    # Use template from config
    let relPath = relativePath(module.path, getCurrentDir())
    let modulePath = relPath.replace(".nim", "")
    testContent = config.testTemplate
      .replace("$MODULE", modulePath)
      .replace("$MODULE_NAME", baseName)
  else:
    # Add to existing file
    testContent = readFile(testFilePath)
  
  # Generate test skeletons for uncovered functions
  var newTests = ""
  for fn in module.functions:
    if not fn.hasTest:
      let testName = fn.name.replace("*", "")
      
      # Generate appropriate test based on function type
      let assertKeyword = if config.usePowerAssert: "assert" else: "check"
      
      if fn.signature.contains("{.async.}"):
        # Async function test
        newTests &= fmt"""
  test "{testName} async":
    # TODO: Implement async test for {testName}
    # Function signature: {fn.signature}
    waitFor(proc() {{.async.}} =
      # Add test implementation here
      {assertKeyword} true # Placeholder
    )()
"""
      elif fn.signature.contains("Result["):
        # Function returning Result type
        newTests &= fmt"""
  test "{testName} result":
    # TODO: Implement test for {testName}
    # Function signature: {fn.signature}
    let result = {testName}()
    check result.isOk()
    # check result.get() == expectedValue
"""
      elif fn.signature.contains("seq["):
        # Function returning sequence
        newTests &= fmt"""
  test "{testName} sequence":
    # TODO: Implement test for {testName}
    # Function signature: {fn.signature}
    let result = {testName}()
    check result.len > 0
    # check result[0] == expectedValue
"""
      else:
        # Standard function test with edge cases
        newTests &= fmt"""
  test "{testName}":
    # TODO: Implement test for {testName}
    # Function signature: {fn.signature}
    check true # Placeholder test

  test "{testName} - edge cases":
    # Test with nil/empty values
    when compiles({testName}(nil)):
      check {testName}(nil).isOk == false
    
    # Test with boundary values
    when compiles({testName}(0)):
      discard {testName}(0)
    when compiles({testName}(int.high)):
      discard {testName}(int.high)
    when compiles({testName}("")):
      discard {testName}("")

  test "{testName} - property based":
    # Property-based test template
    import std/random
    randomize()
    
    for _ in 0..100:
      # Generate random inputs based on function signature
      # Example for int parameter:
      when compiles({testName}(0)):
        let input = rand(int.high)
        let result = {testName}(input)
        # Add property assertions here
        {assertKeyword} true # Placeholder
"""
  
  # Add new tests
  if newTests.len > 0:
    if not isNew:
      testContent &= newTests
    else:
      testContent &= newTests
    
    # Write to file
    writeFile(testFilePath, testContent)
    echo fmt"Generated/updated test file: {testFilePath}"

proc generateMissingTests(config: ProjectConfig, modules: seq[ModuleInfo]) =
  ## Generates test files for modules with missing test coverage using Strategy pattern
  
  # Create test generation strategies
  let parallelStrategy = ParallelTestStrategy(name: "parallel", workers: 4)
  let sequentialStrategy = SequentialTestStrategy(name: "sequential")
  
  # Use strategy based on config
  let runner = newTestRunner(
    if config.parallelTests: parallelStrategy
    else: sequentialStrategy
  )
  
  # Create observer for progress reporting
  let progressSubject = newTestSubject()
  let progressObserver = newTestObserver("progress", proc(event: TestEvent) =
    echo fmt"{event.data[\"module\"]}: {event.data[\"message\"]}"
  )
  progressSubject.attach(progressObserver)
  
  for module in modules:
    if module.tests.len == 0:
      # No test file exists, create a new one
      progressSubject.notify(TestEvent(
        name: "generating",
        data: {"module": module.name, "message": "Creating new test file"}.toTable
      ))
      generateTestFile(config, module, true)
    else:
      # Test file exists, check for untested functions
      var untested = 0
      for fn in module.functions:
        if not fn.hasTest:
          untested += 1
      
      if untested > 0:
        progressSubject.notify(TestEvent(
          name: "updating",
          data: {"module": module.name, "message": fmt"{untested} functions need tests"}.toTable
        ))
        generateTestFile(config, module, false)

# Main function using Template Method pattern
type
  TestGeneratorTemplate = ref object of TestTemplate
    config: ProjectConfig
    modules: seq[ModuleInfo]

method setUp(tmpl: TestGeneratorTemplate) =
  echo "Nim TestKit Test Generator"
  tmpl.config = loadProjectConfig()
  tmpl.modules = @[]

method runTest(tmpl: TestGeneratorTemplate) =
  # Analyze modules
  tmpl.modules = analyze(tmpl.config)
  
  # Generate missing tests
  generateMissingTests(tmpl.config, tmpl.modules)

method tearDown(tmpl: TestGeneratorTemplate) =
  echo fmt"\nTotal modules analyzed: {tmpl.modules.len}"
  var totalFunctions = 0
  var totalUntested = 0
  
  for module in tmpl.modules:
    totalFunctions += module.functions.len
    for fn in module.functions:
      if not fn.hasTest:
        totalUntested += 1
  
  echo fmt"Total functions found: {totalFunctions}"
  echo fmt"Functions missing tests: {totalUntested}"
  
  # Calculate coverage
  let coverage = if totalFunctions > 0:
    ((totalFunctions - totalUntested) / totalFunctions) * 100
  else:
    100.0
  
  echo fmt"Test coverage: {coverage:.1f}%"

proc main() =
  # Use Template Method pattern
  let generator = TestGeneratorTemplate()
  generator.execute()
  
  # Old implementation preserved below for reference
  when false:
    echo "Nim TestKit Test Generator"
    
    # Load project configuration
  let config = loadProjectConfig()
  
  echo fmt"Source directory: {config.sourceDir}"
  echo fmt"Tests directory: {config.testsDir}"
  
  # Show VCS status
  let vcsInterface = newVCSInterface(config.vcs)
  echo ""
  echo vcsInterface.getVCSStatusSummary()
  
  # Analyze the codebase
  echo "Analyzing codebase..."
  let modules = analyze(config)
  
  # Report analysis results
  echo "Analysis results:"
  var 
    totalFunctions = 0
    testedFunctions = 0
  
  for module in modules:
    let functionCount = module.functions.len
    let testedCount = module.functions.countIt(it.hasTest)
    
    totalFunctions += functionCount
    testedFunctions += testedCount
    
    echo fmt"- {module.name}: {functionCount} functions, {testedCount} tested"
    for test in module.tests:
      echo fmt"  - Test: {extractFilename(test)}"
    
    if testedCount < functionCount:
      echo fmt"  - {functionCount - testedCount} functions need tests"
  
  # Calculate coverage percentage
  let coveragePercent = 
    if totalFunctions > 0: 
      (testedFunctions.float / totalFunctions.float) * 100.0
    else: 
      0.0
  
  echo fmt"Overall function test coverage: {testedFunctions}/{totalFunctions} ({coveragePercent:.1f}%)"
  
  # Generate missing tests
  echo "Generating missing tests..."
  generateMissingTests(config, modules)
  
  echo "Done! Nim TestKit test generator completed."

when isMainModule:
  main()