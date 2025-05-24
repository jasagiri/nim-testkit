## Example of using nim-testkit with the new library integrations

import ../src/config
import ../src/integrations/[lang_core_integration, aspects_integration, design_patterns_integration]

# Example 1: Using nim-lang-core features
proc exampleLangCore() =
  echo "=== nim-lang-core integration example ==="
  
  # Using Result type for error handling
  let configResult = tryOp(proc(): TestKitConfig =
    loadConfig("nimtestkit.toml")
  )
  
  if configResult.isOk:
    let config = configResult.value
    echo "Config loaded successfully"
    
    # Using functional pipeline
    let processedPatterns = pipe(config.includePatterns)
      .map(proc(patterns: seq[string]): seq[string] =
        patterns.filterIt(it.endsWith(".nim"))
      )
      .collect()
    
    echo "Filtered patterns: ", processedPatterns
  else:
    echo "Failed to load config: ", configResult.error

# Example 2: Using nim-libaspects features
proc exampleAspects() =
  echo "\n=== nim-libaspects integration example ==="
  
  # Register aspects for test execution
  registerAspect("testRunner", timeExecution("testRunner"))
  registerAspect("testRunner", logEntry("testRunner"))
  registerAspect("testRunner", logExit("testRunner"))
  registerAspect("testRunner", countCalls("testRunner"))
  
  # Mock test execution
  proc runTest(name: string) =
    echo "Running test: ", name
  
  # Apply aspects
  runTest("example_test")
  
  # Get execution stats
  let stats = getExecutionStats("testRunner")
  echo "Execution stats: ", stats

# Example 3: Using nim-design-patterns features
proc exampleDesignPatterns() =
  echo "\n=== nim-design-patterns integration example ==="
  
  # Factory Pattern for test creation
  var testFactory = newTestFactory[proc(): string]()
  testFactory.register("unit", proc(): proc(): string =
    proc(): string = "unit test template"
  )
  testFactory.register("integration", proc(): proc(): string =
    proc(): string = "integration test template"
  )
  
  let unitTest = testFactory.create("unit")
  if unitTest.isSome:
    echo "Created test: ", unitTest.get()()
  
  # Observer Pattern for test events
  let testSubject = newTestSubject()
  let observer = newTestObserver("console", proc(event: TestEvent) =
    echo "Test event: ", event.name, " - ", event.data
  )
  testSubject.attach(observer)
  
  testSubject.notify(TestEvent(
    name: "test_started",
    data: {"test": "example_test", "time": "10:00"}.toTable
  ))
  
  # Builder Pattern for test configuration
  let testConfig = newTestConfigBuilder()
    .withTimeout("30s")
    .withParallel(true)
    .withReporter("junit")
    .build()
  
  echo "Test config: ", testConfig
  
  # Strategy Pattern for test execution
  let parallelStrategy = ParallelTestStrategy(name: "parallel", workers: 4)
  let runner = newTestRunner(parallelStrategy)
  echo "Test runner strategy: ", runner.runTests()

# Main execution
when isMainModule:
  exampleLangCore()
  exampleAspects()
  exampleDesignPatterns()
  
  echo "\n=== Integration complete ==="
  echo "nim-testkit is now using:"
  echo "- nim-lang-core for enhanced language features"
  echo "- nim-libaspects for aspect-oriented programming"
  echo "- nim-design-patterns for design pattern implementations"