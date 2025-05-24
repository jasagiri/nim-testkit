## Nim TestKit VCS Commands
##
## Provides version control system integration commands for Git, GitHub, GitLab, and Jujutsu

import std/[os, osproc, strformat, strutils, json, httpclient, uri, tables, times, asyncdispatch]
import ./jujutsu
import ../mcp/[mcp_types, mcp_client, mcp_manager]

type
  VcsType* = enum
    vcsNone = "none"
    vcsGit = "git"
    vcsJujutsu = "jujutsu"
    
  GitHubConfig* = object
    token*: string
    apiUrl*: string
    
  GitLabConfig* = object
    token*: string
    apiUrl*: string
    
  VcsConfig* = object
    vcsType*: VcsType
    remoteUrl*: string
    github*: GitHubConfig
    gitlab*: GitLabConfig

proc detectVcsType*(): VcsType =
  ## Detects the VCS type of the current repository
  if checkJujutsuRepo():
    return vcsJujutsu
  elif dirExists(".git"):
    return vcsGit
  else:
    return vcsNone

proc getRemoteUrl*(): string =
  ## Gets the remote URL for the repository
  case detectVcsType():
  of vcsGit:
    let (output, exitCode) = execCmdEx("git remote get-url origin")
    if exitCode == 0:
      return output.strip()
  of vcsJujutsu:
    let (output, exitCode) = execCmdEx("jj config get git.push-remote")
    if exitCode == 0:
      return output.strip()
  of vcsNone:
    discard
  return ""

proc parseRepoInfo*(remoteUrl: string): tuple[platform: string, owner: string, repo: string] =
  ## Parses remote URL to extract platform, owner, and repo name
  var url = remoteUrl
  
  # Handle SSH URLs
  if url.startsWith("git@"):
    # git@github.com:user/repo.git -> https://github.com/user/repo.git
    # Remove git@ prefix
    url = url[4..^1]  # Remove "git@"
    # Replace : with /
    let colonPos = url.find(":")
    if colonPos >= 0:
      url = "https://" & url[0..<colonPos] & "/" & url[colonPos+1..^1]
  
  # Remove .git suffix
  url = url.replace(".git", "")
  
  let uri = parseUri(url)
  let pathParts = uri.path.split("/")
  
  # Filter out empty parts
  var validParts: seq[string] = @[]
  for part in pathParts:
    if part != "":
      validParts.add(part)
  
  if validParts.len >= 2:
    let platform = if "github" in uri.hostname: "github"
                  elif "gitlab" in uri.hostname: "gitlab"
                  else: "unknown"
    return (platform: platform, owner: validParts[0], repo: validParts[1])
  
  return (platform: "unknown", owner: "", repo: "")

proc loadVcsConfig*(): VcsConfig =
  ## Loads VCS configuration
  result.vcsType = detectVcsType()
  result.remoteUrl = getRemoteUrl()
  
  # Load tokens from environment
  result.github.token = getEnv("GITHUB_TOKEN", "")
  result.github.apiUrl = getEnv("GITHUB_API_URL", "https://api.github.com")
  result.gitlab.token = getEnv("GITLAB_TOKEN", "")
  result.gitlab.apiUrl = getEnv("GITLAB_API_URL", "https://gitlab.com/api/v4")

var globalMcpManager*: McpManager = nil

proc initializeMcpManager*(): McpManager =
  ## Initializes the global MCP manager
  if globalMcpManager == nil:
    globalMcpManager = newMcpManager()
    globalMcpManager.loadEnvironmentTokens()
    globalMcpManager.setupServerPaths()
  return globalMcpManager

proc setupMcpIntegration*() {.async.} =
  ## Sets up MCP integration for VCS operations
  let manager = initializeMcpManager()
  
  echo "Setting up MCP integration..."
  let started = await manager.startAllServers()
  
  if started.len > 0:
    echo "Started MCP servers: " & started.join(", ")
  else:
    echo "No MCP servers could be started. Check configuration and dependencies."
  
  # Test connectivity
  for serverName in started:
    let tools = await manager.listAvailableTools(serverName)
    echo "Server " & serverName & " has " & $tools.len & " tools available"

proc shutdownMcpIntegration*() =
  ## Shuts down MCP integration
  if globalMcpManager != nil:
    globalMcpManager.stopAllServers()
    echo "MCP integration shut down"

proc getMcpManager*(): McpManager =
  ## Gets the global MCP manager, initializing if needed
  return initializeMcpManager()

proc setupHooksCommand*() =
  ## Sets up VCS hooks for automatic testing
  case detectVcsType():
  of vcsJujutsu:
    setupJujutsuHooks()
  of vcsGit:
    echo "Git repository detected, installing Git hooks..."
    let hookScript = """#!/bin/sh
# Nim TestKit pre-commit hook

# Run tests before allowing commits
nimble test

# Exit with the test result
exit $?
"""
    
    let hookFile = ".git/hooks/pre-commit"
    writeFile(hookFile, hookScript)
    
    when not defined(windows):
      discard execCmd("chmod +x " & hookFile)
    
    echo "Git hooks installed successfully"
  of vcsNone:
    echo "No version control system detected"

# MCP-based VCS operations
proc mcpGitStatus*(repoPath: string = "."): Future[string] {.async.} =
  ## Gets Git status using MCP
  let manager = getMcpManager()
  let result = await manager.gitStatus(repoPath)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpGitCommit*(message: string, repoPath: string = "."): Future[string] {.async.} =
  ## Commits changes using MCP
  let manager = getMcpManager()
  let result = await manager.gitCommit(message, repoPath)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpCreateGitHubIssue*(owner: string, repo: string, title: string, 
                          body: string = ""): Future[string] {.async.} =
  ## Creates a GitHub issue using MCP
  let manager = getMcpManager()
  let result = await manager.githubCreateIssue(owner, repo, title, body)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpCreateGitHubPR*(owner: string, repo: string, title: string, 
                       head: string, base: string = "main", 
                       body: string = ""): Future[string] {.async.} =
  ## Creates a GitHub pull request using MCP
  let manager = getMcpManager()
  let result = await manager.githubCreatePullRequest(owner, repo, title, head, base, body)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpCreateGitLabIssue*(projectId: string, title: string, 
                          description: string = ""): Future[string] {.async.} =
  ## Creates a GitLab issue using MCP
  let manager = getMcpManager()
  let result = await manager.gitlabCreateIssue(projectId, title, description)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpCreateGitLabMR*(projectId: string, title: string, sourceBranch: string,
                       targetBranch: string = "main", 
                       description: string = ""): Future[string] {.async.} =
  ## Creates a GitLab merge request using MCP
  let manager = getMcpManager()
  let result = await manager.gitlabCreateMergeRequest(projectId, title, sourceBranch, targetBranch, description)
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc mcpJujutsuStatus*(): Future[string] {.async.} =
  ## Gets Jujutsu status using MCP
  let manager = getMcpManager()
  let result = await manager.jujutsuStatus()
  
  if result.success:
    return result.content
  else:
    raise newException(CatchableError, result.error)

proc detectAndSetupVcs*() {.async.} =
  ## Detects VCS type and sets up appropriate MCP integration
  let vcsType = detectVcsType()
  let remoteUrl = getRemoteUrl()
  
  echo "Detected VCS: " & $vcsType
  
  if remoteUrl != "":
    let repoInfo = parseRepoInfo(remoteUrl)
    echo "Remote: " & repoInfo.platform & " - " & repoInfo.owner & "/" & repoInfo.repo
  
  # Initialize MCP integration
  await setupMcpIntegration()
  
  echo "VCS integration ready"

proc getVcsInfo*(): tuple[vcsType: VcsType, remoteUrl: string, platform: string, owner: string, repo: string] =
  ## Gets comprehensive VCS information
  result.vcsType = detectVcsType()
  result.remoteUrl = getRemoteUrl()
  
  if result.remoteUrl != "":
    let repoInfo = parseRepoInfo(result.remoteUrl)
    result.platform = repoInfo.platform
    result.owner = repoInfo.owner
    result.repo = repoInfo.repo
  else:
    result.platform = "unknown"
    result.owner = ""
    result.repo = ""

proc validateChangeDescription*(): bool =
  ## Validates Jujutsu change descriptions
  if not checkJujutsuRepo():
    return true
  
  let (descOutput, exitCode) = execCmdEx("jj log -r @ --template description")
  if exitCode != 0:
    return false
  
  let description = descOutput.strip()
  
  # Basic validation rules
  if description.len < 10:
    echo "Change description too short (minimum 10 characters)"
    return false
  
  if not description.contains(" "):
    echo "Change description should contain multiple words"
    return false
  
  # Check for conventional commit format (optional)
  let conventionalPrefixes = @[
    "feat:", "fix:", "docs:", "style:", "refactor:",
    "test:", "chore:", "perf:", "ci:", "build:"
  ]
  
  var hasPrefix = false
  for prefix in conventionalPrefixes:
    if description.toLower().startsWith(prefix):
      hasPrefix = true
      break
  
  if not hasPrefix:
    echo "Consider using conventional commit format (feat:, fix:, etc.)"
  
  return true

proc runOnNewChange*() =
  ## Runs when creating a new Jujutsu change
  if not checkJujutsuRepo():
    return
  
  echo "New change detected, running tests..."
  
  # Run tests
  let (testOutput, testCode) = execCmdEx("nimble test")
  
  if testCode != 0:
    echo "Tests failed! Consider fixing issues before continuing."
    echo testOutput
  else:
    echo "All tests passed!"

proc supportSplitWorkflow*() =
  ## Support for jj split workflow
  if not checkJujutsuRepo():
    return
  
  echo "Preparing for split operation..."
  
  # Get list of modified files
  let (filesOutput, _) = execCmdEx("jj diff --name-only")
  let modifiedFiles = filesOutput.strip().splitLines()
  
  echo "Modified files: " & $modifiedFiles.len
  for file in modifiedFiles:
    echo "  - " & file
  
  # Run tests for each file group
  echo "Running tests for modified files..."
  let (testOutput, testCode) = execCmdEx("nimble test")
  
  if testCode == 0:
    echo "All tests pass - safe to split changes"
  else:
    echo "Some tests fail - review before splitting"

proc evolveSupport*() =
  ## Support for jj evolve workflow
  echo "Checking evolve compatibility..."
  
  if not checkJujutsuRepo():
    return
  
  # Check for conflicts
  let (statusOutput, _) = execCmdEx("jj status")
  if statusOutput.contains("Conflict"):
    echo "Conflicts detected - resolve before evolving"
    return
  
  # Run tests to ensure stability
  echo "Running tests before evolve..."
  let (testOutput, testCode) = execCmdEx("nimble test")
  
  if testCode == 0:
    echo "Tests pass - safe to evolve"
  else:
    echo "Tests fail - fix issues before evolving"

proc setupJJIntegration*() =
  ## Main setup function for Jujutsu integration
  echo "Setting up Jujutsu integration..."
  
  # Install hooks
  setupHooksCommand()
  
  # Create jj config if needed
  let jjConfigDir = expandTilde("~/.jjconfig")
  createDir(jjConfigDir)
  
  let jjConfig = """
# Nim TestKit integration
[aliases]
test = ["!nimble test"]
test-changed = ["!nimble test --jj-changed"]

[hooks]
post-checkout = "nimble test --quick"
pre-commit = "nimble test"
"""
  
  writeFile(jjConfigDir / "nimtestkit.toml", jjConfig)
  echo "Jujutsu configuration installed"