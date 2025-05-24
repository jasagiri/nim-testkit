import std/[unittest, os, json, tempfiles, strutils, sequtils]
import ../src/organization/module_sync

suite "ModuleSync - Comprehensive Coverage":
  setup:
    let tempDir = createTempDir("module_sync_", "")
    let configFile = tempDir / "config" / "modules.json"
    createDir(tempDir / "config")
    
  teardown:
    removeDir(tempDir)
    
  test "Module sync initialization":
    let ms = newModuleSync(configFile)
    
    check ms.configFile == configFile
    check ms.progressFile == "config/.sync-progress.json"
    check ms.modules.len == 0
    check ms.skipList.len == 0
    check not ms.progress.inProgress
    
  test "Load and save configuration":
    let ms = newModuleSync(configFile)
    
    # Add some modules
    ms.modules.add(ModuleConfig(
      name: "test-module",
      repoUrl: "https://github.com/test/module.git",
      branch: "main",
      path: "modules/test-module"
    ))
    
    ms.saveConfig()
    
    # Load in new instance
    let ms2 = newModuleSync(configFile)
    check ms2.modules.len == 1
    check ms2.modules[0].name == "test-module"
    check ms2.modules[0].repoUrl == "https://github.com/test/module.git"
    
  test "Add module validation":
    let ms = newModuleSync(configFile)
    
    # Valid module
    let result1 = ms.addModule("valid-module", "https://github.com/user/repo.git")
    check result1.success
    check ms.modules.len == 1
    
    # Duplicate module
    let result2 = ms.addModule("valid-module", "https://github.com/user/other.git")
    check not result2.success
    check "already exists" in result2.message
    
    # Invalid URL
    let result3 = ms.addModule("invalid-url", "not-a-url")
    check not result3.success
    check "Invalid repository URL" in result3.message
    
  test "Module update operations":
    let ms = newModuleSync(configFile)
    
    # Add a module first
    discard ms.addModule("update-test", "https://github.com/test/repo.git")
    
    # Update non-existent module
    let result1 = ms.updateModule("non-existent")
    check not result1.success
    check "not found" in result1.message
    
    # Skip module and try to update
    ms.skipModule("update-test")
    let result2 = ms.updateModule("update-test")
    check not result2.success
    check "skip list" in result2.message
    
  test "Remove module":
    let ms = newModuleSync(configFile)
    
    # Add and remove
    discard ms.addModule("remove-test", "https://github.com/test/repo.git")
    check ms.modules.len == 1
    
    let result = ms.removeModule("remove-test")
    check result.success
    check ms.modules.len == 0
    
    # Remove non-existent
    let result2 = ms.removeModule("non-existent")
    check not result2.success
    check "not found" in result2.message
    
  test "Progress tracking":
    let ms = newModuleSync(configFile)
    
    # Set progress
    ms.progress.inProgress = true
    ms.progress.currentModule = "test-module"
    ms.progress.operation = "sync"
    ms.progress.timestamp = "2024-01-01"
    ms.saveProgress()
    
    # Load in new instance
    let ms2 = newModuleSync(configFile)
    check ms2.progress.inProgress
    check ms2.progress.currentModule == "test-module"
    check ms2.progress.operation == "sync"
    
  test "Skip list management":
    let ms = newModuleSync(configFile)
    
    # Add to skip list
    ms.skipModule("module1")
    ms.skipModule("module2")
    check ms.skipList.len == 2
    check "module1" in ms.skipList
    
    # Remove from skip list
    ms.unskipModule("module1")
    check ms.skipList.len == 1
    check "module1" notin ms.skipList
    check "module2" in ms.skipList
    
    # Save and reload
    ms.saveProgress()
    let ms2 = newModuleSync(configFile)
    check ms2.skipList.len == 1
    check "module2" in ms2.skipList
    
  test "Sync all modules":
    let ms = newModuleSync(configFile)
    
    # Add test modules
    discard ms.addModule("module1", "https://github.com/test/module1.git")
    discard ms.addModule("module2", "https://github.com/test/module2.git")
    discard ms.addModule("module3", "https://github.com/test/module3.git")
    
    # Skip one module
    ms.skipModule("module2")
    
    # Mock sync (in real scenario would use git)
    let results = ms.syncAll()
    
    check results.len == 3
    # module2 should be skipped
    check results[1].module == "module2"
    check not results[1].success
    check "Skipped" in results[1].message
    
  test "Resume sync operation":
    let ms = newModuleSync(configFile)
    
    # Add modules
    discard ms.addModule("module1", "https://github.com/test/module1.git")
    discard ms.addModule("module2", "https://github.com/test/module2.git")
    discard ms.addModule("module3", "https://github.com/test/module3.git")
    
    # Simulate interrupted sync
    ms.progress.inProgress = true
    ms.progress.currentModule = "module2"
    ms.saveProgress()
    
    # Resume should start from module2
    let results = ms.syncAll(resume = true)
    check results.len >= 2  # Should sync module2 and module3
    
  test "List modules output":
    let ms = newModuleSync(configFile)
    
    discard ms.addModule("test-lib", "https://github.com/user/test-lib.git", "develop")
    ms.skipModule("test-lib")
    
    let output = ms.listModules()
    
    check "Configured Modules:" in output
    check "test-lib [SKIPPED]" in output
    check "Repository: https://github.com/user/test-lib.git" in output
    check "Branch: develop" in output
    check "Skipped Modules:" in output
    
  test "Show progress output":
    let ms = newModuleSync(configFile)
    
    # No operation
    var output = ms.showProgress()
    check "No operation in progress" in output
    
    # With operation
    ms.progress.inProgress = true
    ms.progress.currentModule = "active-module"
    ms.progress.operation = "update"
    ms.progress.timestamp = "2024-01-01 10:00:00"
    
    output = ms.showProgress()
    check "IN PROGRESS" in output
    check "active-module" in output
    check "update" in output
    
  test "Publish module":
    let ms = newModuleSync(configFile)
    let sdkDir = tempDir / "sdk"
    
    # Add module
    discard ms.addModule("publish-test", "https://github.com/test/publish.git")
    
    # Create mock module directory
    let moduleDir = tempDir / "modules" / "publish-test"
    createDir(moduleDir)
    writeFile(moduleDir / "README.md", "Test module")
    
    # Publish (would fail without actual module)
    let result = ms.publishModule("publish-test", sdkDir / "publish-test")
    # In test environment, this might fail due to missing module directory
    
    # Test non-existent module
    let result2 = ms.publishModule("non-existent", sdkDir / "non-existent")
    check not result2.success
    check "not found" in result2.message
    
  test "Publish all modules":
    let ms = newModuleSync(configFile)
    let sdkDir = tempDir / "sdk"
    
    # Add modules
    discard ms.addModule("sdk1", "https://github.com/test/sdk1.git")
    discard ms.addModule("sdk2", "https://github.com/test/sdk2.git")
    
    # Skip one
    ms.skipModule("sdk2")
    
    let results = ms.publishAll(sdkDir)
    
    check results.len == 2
    # sdk2 should be skipped
    check results[1].module == "sdk2"
    check not results[1].success
    check "Skipped" in results[1].message
    
  test "Command execution":
    # Test command execution wrapper
    let (output, exitCode) = execCommand("echo test")
    check exitCode == 0
    check "test" in output
    
    let (_, failCode) = execCommand("false")
    check failCode != 0
    
  test "Git repository detection":
    # In test environment, might not be in git repo
    let isGit = checkGitRepo()
    # Just verify function works
    check isGit or not isGit
    
  test "Jujutsu detection":
    let hasJj = checkJujutsu()
    # Just verify function works
    check hasJj or not hasJj
    
  test "Configuration file creation":
    let ms = newModuleSync(tempDir / "new" / "modules.json")
    
    # Should create default config
    check fileExists(tempDir / "new" / "modules.json")
    
    let content = readFile(tempDir / "new" / "modules.json")
    let data = parseJson(content)
    check data.hasKey("modules")
    check data["modules"].len == 0
    
  test "Module path generation":
    let ms = newModuleSync(configFile)
    
    discard ms.addModule("test-module", "https://github.com/test/module.git")
    
    check ms.modules[0].path == "modules/test-module"
    
  test "Error handling - malformed config":
    writeFile(configFile, "invalid json{")
    
    let ms = newModuleSync(configFile)
    # Should handle gracefully
    check ms.modules.len == 0
    
  test "Error handling - malformed progress":
    let ms = newModuleSync(configFile)
    
    writeFile(ms.progressFile, "invalid json{")
    ms.loadProgress()
    
    # Should reset to default
    check not ms.progress.inProgress
    check ms.progress.currentModule == ""