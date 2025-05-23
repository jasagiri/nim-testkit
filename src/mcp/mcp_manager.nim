## MCP Manager for Nim TestKit
##
## Manages multiple MCP servers and provides unified VCS operations

import std/[asyncdispatch, json, tables, options, logging, os, strformat, strutils]
import mcp_types, mcp_client

type
  McpManager* = ref object
    clients*: Table[string, McpClient]
    config*: VcsMcpServers
    activeServers*: seq[string]

  VcsOperation* = object
    serverName*: string
    toolName*: string
    arguments*: JsonNode

  VcsOperationResult* = object
    serverName*: string
    success*: bool
    content*: string
    error*: string

proc newMcpManager*(): McpManager =
  ## Creates a new MCP manager
  result = McpManager(
    clients: initTable[string, McpClient](),
    config: VcsMcpServers(
      git: DEFAULT_GIT_SERVER,
      github: DEFAULT_GITHUB_SERVER,
      gitlab: DEFAULT_GITLAB_SERVER,
      jujutsu: DEFAULT_JUJUTSU_SERVER
    ),
    activeServers: @[]
  )

proc loadEnvironmentTokens*(manager: McpManager) =
  ## Loads authentication tokens from environment variables
  let githubToken = getEnv("GITHUB_TOKEN")
  if githubToken != "":
    manager.config.github.env["GITHUB_TOKEN"] = githubToken
    manager.config.github.enabled = true
  
  let gitlabToken = getEnv("GITLAB_PERSONAL_ACCESS_TOKEN")
  if gitlabToken != "":
    manager.config.gitlab.env["GITLAB_PERSONAL_ACCESS_TOKEN"] = gitlabToken
    manager.config.gitlab.enabled = true

proc setupServerPaths*(manager: McpManager, vendorPath: string = "vendor") =
  ## Sets up correct paths for MCP servers
  let absVendorPath = vendorPath.absolutePath()
  
  # Update Git server path
  manager.config.git.args = @[
    "--directory", absVendorPath / "servers" / "src" / "git",
    "run", "mcp-server-git"
  ]
  
  # Update GitHub server path
  manager.config.github.args = @[
    absVendorPath / "servers" / "src" / "github" / "index.js"
  ]
  
  # Update GitLab server path
  manager.config.gitlab.args = @[
    absVendorPath / "servers" / "src" / "gitlab" / "index.js"
  ]
  
  # Update Jujutsu server path (assuming it's in vendor/mcp-jujutsu)
  let jujutsuPath = absVendorPath / "mcp-jujutsu"
  if dirExists(jujutsuPath):
    manager.config.jujutsu.command = "nimble"
    manager.config.jujutsu.args = @[
      "--silent", "-d:release", 
      "--project:" & jujutsuPath,
      "run", "mcp_jujutsu"
    ]

proc addServer*(manager: McpManager, name: string, config: McpServerConfig) =
  ## Adds a custom MCP server configuration
  let client = newMcpClient(config)
  manager.clients[name] = client

proc startServer*(manager: McpManager, serverName: string): Future[bool] {.async.} =
  ## Starts a specific MCP server
  if serverName notin manager.clients:
    let config = case serverName:
      of "git": manager.config.git
      of "github": manager.config.github
      of "gitlab": manager.config.gitlab
      of "jujutsu": manager.config.jujutsu
      else:
        error "Unknown server: " & serverName
        return false
    
    if not config.enabled:
      info "Server " & serverName & " is disabled"
      return false
    
    manager.addServer(serverName, config)
  
  let client = manager.clients[serverName]
  
  try:
    await client.start()
    manager.activeServers.add(serverName)
    info "Started MCP server: " & serverName
    return true
  except Exception as e:
    error "Failed to start " & serverName & ": " & e.msg
    return false

proc stopServer*(manager: McpManager, serverName: string) =
  ## Stops a specific MCP server
  if serverName in manager.clients:
    manager.clients[serverName].stop()
    let idx = manager.activeServers.find(serverName)
    if idx >= 0:
      manager.activeServers.delete(idx)
    info "Stopped MCP server: " & serverName

proc startAllServers*(manager: McpManager): Future[seq[string]] {.async.} =
  ## Starts all enabled MCP servers
  var started: seq[string] = @[]
  
  for serverName in ["git", "github", "gitlab", "jujutsu"]:
    if await manager.startServer(serverName):
      started.add(serverName)
  
  return started

proc stopAllServers*(manager: McpManager) =
  ## Stops all running MCP servers
  for serverName in manager.activeServers:
    manager.stopServer(serverName)
  manager.activeServers = @[]

proc executeVcsOperation*(manager: McpManager, operation: VcsOperation): Future[VcsOperationResult] {.async.} =
  ## Executes a VCS operation on the specified server
  if operation.serverName notin manager.clients:
    return VcsOperationResult(
      serverName: operation.serverName,
      success: false,
      error: "Server " & operation.serverName & " not available"
    )
  
  let client = manager.clients[operation.serverName]
  
  try:
    let result = await client.callTool(operation.toolName, operation.arguments)
    
    if result.isError:
      return VcsOperationResult(
        serverName: operation.serverName,
        success: false,
        error: if result.content.len > 0: result.content[0].text.get("Unknown error") else: "Unknown error"
      )
    
    var content = ""
    for item in result.content:
      if item.text.isSome:
        content &= item.text.get() & "\n"
    
    return VcsOperationResult(
      serverName: operation.serverName,
      success: true,
      content: content.strip()
    )
    
  except Exception as e:
    return VcsOperationResult(
      serverName: operation.serverName,
      success: false,
      error: e.msg
    )

# Convenient VCS operations
proc gitStatus*(manager: McpManager, repoPath: string = "."): Future[VcsOperationResult] {.async.} =
  ## Gets Git repository status
  let operation = VcsOperation(
    serverName: "git",
    toolName: "git_status",
    arguments: %*{"repo_path": repoPath}
  )
  return await manager.executeVcsOperation(operation)

proc gitCommit*(manager: McpManager, message: string, repoPath: string = "."): Future[VcsOperationResult] {.async.} =
  ## Commits changes to Git repository
  let operation = VcsOperation(
    serverName: "git",
    toolName: "git_commit",
    arguments: %*{
      "repo_path": repoPath,
      "message": message
    }
  )
  return await manager.executeVcsOperation(operation)

proc githubCreateIssue*(manager: McpManager, owner: string, repo: string, 
                       title: string, body: string = ""): Future[VcsOperationResult] {.async.} =
  ## Creates a GitHub issue
  let operation = VcsOperation(
    serverName: "github",
    toolName: "create_issue",
    arguments: %*{
      "owner": owner,
      "repo": repo,
      "title": title,
      "body": body
    }
  )
  return await manager.executeVcsOperation(operation)

proc githubCreatePullRequest*(manager: McpManager, owner: string, repo: string,
                             title: string, head: string, base: string = "main",
                             body: string = ""): Future[VcsOperationResult] {.async.} =
  ## Creates a GitHub pull request
  let operation = VcsOperation(
    serverName: "github",
    toolName: "create_pull_request",
    arguments: %*{
      "owner": owner,
      "repo": repo,
      "title": title,
      "head": head,
      "base": base,
      "body": body
    }
  )
  return await manager.executeVcsOperation(operation)

proc gitlabCreateIssue*(manager: McpManager, projectId: string, 
                       title: string, description: string = ""): Future[VcsOperationResult] {.async.} =
  ## Creates a GitLab issue
  let operation = VcsOperation(
    serverName: "gitlab",
    toolName: "create_issue",
    arguments: %*{
      "project_id": projectId,
      "title": title,
      "description": description
    }
  )
  return await manager.executeVcsOperation(operation)

proc gitlabCreateMergeRequest*(manager: McpManager, projectId: string,
                              title: string, sourceBranch: string, 
                              targetBranch: string = "main",
                              description: string = ""): Future[VcsOperationResult] {.async.} =
  ## Creates a GitLab merge request
  let operation = VcsOperation(
    serverName: "gitlab",
    toolName: "create_merge_request",
    arguments: %*{
      "project_id": projectId,
      "title": title,
      "source_branch": sourceBranch,
      "target_branch": targetBranch,
      "description": description
    }
  )
  return await manager.executeVcsOperation(operation)

proc jujutsuStatus*(manager: McpManager): Future[VcsOperationResult] {.async.} =
  ## Gets Jujutsu repository status
  let operation = VcsOperation(
    serverName: "jujutsu",
    toolName: "jj_status",
    arguments: %*{}
  )
  return await manager.executeVcsOperation(operation)

proc listAvailableTools*(manager: McpManager, serverName: string): Future[seq[string]] {.async.} =
  ## Lists available tools for a server
  if serverName notin manager.clients:
    return @[]
  
  try:
    let client = manager.clients[serverName]
    let tools = await client.listTools()
    
    for tool in tools:
      if tool.hasKey("name"):
        result.add(tool["name"].getStr())
  except Exception as e:
    error "Failed to list tools for " & serverName & ": " & e.msg

proc getServerStatus*(manager: McpManager): Table[string, bool] =
  ## Gets the status of all servers
  result = initTable[string, bool]()
  
  for serverName in ["git", "github", "gitlab", "jujutsu"]:
    result[serverName] = serverName in manager.activeServers