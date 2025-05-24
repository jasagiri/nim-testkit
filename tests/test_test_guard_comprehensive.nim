import std/[unittest, os, tempfiles, strutils, times, tables]
import ../src/execution/guard

suite "TestGuard - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("test_guard_", "")
    
  teardown:
    removeDir(tempDir)
    
  test "Resource monitoring - memory":
    let guard = newTestGuard()
    guard.config.maxMemoryMB = 100
    
    # Start monitoring
    guard.startMonitoring()
    
    # Simulate memory usage
    var data: seq[string]
    for i in 0..1000:
      data.add("x".repeat(1000))  # ~1KB per string
    
    # Check memory usage
    let usage = guard.getCurrentMemoryUsage()
    check usage > 0
    
    guard.stopMonitoring()
    
  test "Resource monitoring - time limit":
    let guard = newTestGuard()
    guard.config.maxDurationSeconds = 1
    
    guard.startMonitoring()
    let start = epochTime()
    
    # Simulate work
    sleep(100)
    
    check not guard.isTimeLimitExceeded()
    
    # Don't actually exceed time limit in test
    guard.stopMonitoring()
    let duration = epochTime() - start
    check duration < 1.0
    
  test "Resource monitoring - file handles":
    let guard = newTestGuard()
    guard.config.maxFileHandles = 10
    
    guard.startMonitoring()
    
    # Open some files
    var files: seq[File]
    for i in 0..4:
      let path = tempDir / $"test_" & $i & ".txt"
      writeFile(path, "test")
      files.add(open(path))
    
    let handles = guard.getCurrentFileHandles()
    check handles >= 5
    
    # Close files
    for f in files:
      f.close()
    
    guard.stopMonitoring()
    
  test "Test isolation - environment variables":
    let guard = newTestGuard()
    
    # Save current environment
    guard.saveEnvironment()
    
    # Modify environment
    putEnv("TEST_VAR", "test_value")
    putEnv("ANOTHER_VAR", "another_value")
    
    check getEnv("TEST_VAR") == "test_value"
    
    # Restore environment
    guard.restoreEnvironment()
    
    check getEnv("TEST_VAR") == ""
    
  test "Test isolation - working directory":
    let guard = newTestGuard()
    let originalDir = getCurrentDir()
    
    guard.saveWorkingDirectory()
    
    # Change directory
    setCurrentDir(tempDir)
    check getCurrentDir() == tempDir
    
    # Restore directory
    guard.restoreWorkingDirectory()
    check getCurrentDir() == originalDir
    
  test "Test isolation - global state":
    let guard = newTestGuard()
    
    # Register cleanup handlers
    var cleaned = false
    guard.registerCleanup(proc() = cleaned = true)
    
    # Run cleanup
    guard.runCleanups()
    
    check cleaned
    
  test "Parallel test safety - mutex":
    let guard = newTestGuard()
    guard.config.enableParallelSafety = true
    
    # Acquire resource lock
    let lock = guard.acquireResourceLock("test_resource")
    check lock.acquired
    
    # Try to acquire same resource (would block in real scenario)
    let lock2 = guard.tryAcquireResourceLock("test_resource")
    check not lock2.acquired
    
    # Release lock
    guard.releaseResourceLock(lock)
    
    # Now can acquire
    let lock3 = guard.tryAcquireResourceLock("test_resource")
    check lock3.acquired
    guard.releaseResourceLock(lock3)
    
  test "Deadlock detection":
    let guard = newTestGuard()
    guard.config.deadlockTimeout = 1
    
    # Simulate potential deadlock scenario
    let lock1 = guard.acquireResourceLock("resource1")
    let lock2 = guard.acquireResourceLock("resource2")
    
    # Check for circular dependencies
    check not guard.hasDeadlock()
    
    guard.releaseResourceLock(lock2)
    guard.releaseResourceLock(lock1)
    
  test "Test timeout enforcement":
    let guard = newTestGuard()
    guard.config.testTimeout = 0.1  # 100ms timeout
    
    var timedOut = false
    guard.onTimeout = proc() = timedOut = true
    
    guard.startTest("timeout_test")
    
    # Don't actually timeout
    sleep(50)
    
    guard.endTest("timeout_test")
    check not timedOut
    
  test "Memory leak detection":
    let guard = newTestGuard()
    guard.config.detectMemoryLeaks = true
    
    guard.startMemoryTracking()
    
    # Allocate and free memory
    var data = newSeq[int](1000)
    data = @[]
    
    let leaks = guard.checkMemoryLeaks()
    check leaks.len == 0
    
  test "File system sandbox":
    let guard = newTestGuard()
    let sandbox = tempDir / "sandbox"
    createDir(sandbox)
    
    guard.createSandbox(sandbox)
    
    # Operations should be restricted to sandbox
    let testFile = sandbox / "test.txt"
    writeFile(testFile, "sandboxed")
    
    check fileExists(testFile)
    
    # Cleanup sandbox
    guard.cleanupSandbox()
    check not fileExists(testFile)
    
  test "Network isolation":
    let guard = newTestGuard()
    guard.config.allowNetwork = false
    
    # In real implementation, this would block network calls
    check not guard.isNetworkAllowed()
    
  test "CPU usage monitoring":
    let guard = newTestGuard()
    guard.config.maxCpuPercent = 80
    
    guard.startMonitoring()
    
    # Some CPU work
    var sum = 0
    for i in 0..100000:
      sum += i
    
    let cpuUsage = guard.getCurrentCpuUsage()
    check cpuUsage >= 0
    check cpuUsage <= 100
    
    guard.stopMonitoring()
    
  test "Test fixtures management":
    let guard = newTestGuard()
    
    # Setup fixture
    let fixtureDir = tempDir / "fixtures"
    guard.setupFixture("test_data", fixtureDir)
    
    createDir(fixtureDir)
    writeFile(fixtureDir / "data.txt", "fixture data")
    
    # Use fixture
    let data = guard.getFixture("test_data")
    check data == fixtureDir
    check fileExists(data / "data.txt")
    
    # Cleanup fixtures
    guard.cleanupFixtures()
    
  test "Assertion tracking":
    let guard = newTestGuard()
    guard.config.trackAssertions = true
    
    guard.startAssertionTracking()
    
    # Track assertions
    guard.recordAssertion("check", true, "1 == 1")
    guard.recordAssertion("check", false, "1 == 2")
    guard.recordAssertion("require", true, "true")
    
    let stats = guard.getAssertionStats()
    check stats.total == 3
    check stats.passed == 2
    check stats.failed == 1
    
  test "Performance benchmarking":
    let guard = newTestGuard()
    
    # Start benchmark
    guard.startBenchmark("operation1")
    sleep(10)
    let time1 = guard.endBenchmark("operation1")
    
    check time1 > 0.009  # At least 9ms
    
    # Multiple iterations
    guard.benchmarkIterations("operation2", 5):
      sleep(1)
    
    let avgTime = guard.getBenchmarkAverage("operation2")
    check avgTime > 0.0009  # At least 0.9ms average
    
  test "Test dependencies":
    let guard = newTestGuard()
    
    # Define test dependencies
    guard.addDependency("test_b", "test_a")
    guard.addDependency("test_c", "test_b")
    
    # Check dependency order
    let order = guard.getExecutionOrder(@["test_c", "test_b", "test_a"])
    check order == @["test_a", "test_b", "test_c"]
    
    # Detect circular dependencies
    guard.addDependency("test_a", "test_c")
    check guard.hasCircularDependency()
    
  test "Test data providers":
    let guard = newTestGuard()
    
    # Register data provider
    guard.registerDataProvider("numbers", proc(): seq[int] = @[1, 2, 3, 4, 5])
    guard.registerDataProvider("strings", proc(): seq[string] = @["a", "b", "c"])
    
    # Use data providers
    let numbers = guard.getTestData[seq[int]]("numbers")
    check numbers == @[1, 2, 3, 4, 5]
    
    let strings = guard.getTestData[seq[string]]("strings")
    check strings == @["a", "b", "c"]
    
  test "Mock verification":
    let guard = newTestGuard()
    guard.config.strictMocks = true
    
    # Register mock
    var callCount = 0
    guard.registerMock("myService.getData", proc(args: varargs[string]): string =
      inc callCount
      return "mocked data"
    )
    
    # Use mock
    let result = guard.callMock("myService.getData", "arg1")
    check result == "mocked data"
    check callCount == 1
    
    # Verify mock was called
    check guard.verifyMockCalled("myService.getData", times = 1)
    
  test "Test output capture":
    let guard = newTestGuard()
    
    guard.startOutputCapture()
    
    echo "Test output"
    echo "More output"
    
    let output = guard.stopOutputCapture()
    check "Test output" in output
    check "More output" in output
    
  test "Error injection":
    let guard = newTestGuard()
    
    # Inject error for testing error handling
    guard.injectError("file_not_found", proc() = 
      raise newException(IOError, "File not found")
    )
    
    # Trigger injected error
    var caught = false
    try:
      guard.triggerError("file_not_found")
    except IOError:
      caught = true
    
    check caught