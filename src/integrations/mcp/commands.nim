## MCP Commands for Nim TestKit
##
## Provides command-line interface for MCP operations

import std/[asyncdispatch, strformat, json, strutils, os]
import ../vcs/commands

proc mcpStatusCommand*() {.async.} =
  ## Shows MCP server status
  echo "MCP Server Status:"
  echo "=================="
  
  let manager = getMcpManager()
  let status = manager.getServerStatus()
  
  for serverName, running in status:
    let statusStr = if running: "✓ Running" else: "✗ Stopped"
    echo serverName & ": " & statusStr
  
  echo ""
  
  # Show VCS information
  let vcsInfo = getVcsInfo()
  echo "VCS Information:"
  echo "Type: " & $vcsInfo.vcsType
  if vcsInfo.remoteUrl != "":
    echo "Remote: " & vcsInfo.remoteUrl
    echo "Platform: " & vcsInfo.platform
    if vcsInfo.owner != "" and vcsInfo.repo != "":
      echo "Repository: " & vcsInfo.owner & "/" & vcsInfo.repo

proc mcpSetupCommand*() {.async.} =
  ## Sets up MCP integration
  echo "Setting up MCP integration..."
  
  # Check environment variables
  let githubToken = getEnv("GITHUB_TOKEN")
  let gitlabToken = getEnv("GITLAB_PERSONAL_ACCESS_TOKEN")
  
  echo "\nEnvironment Check:"
  echo fmt"GITHUB_TOKEN: {if githubToken != \"\": \"✓ Set\" else: \"✗ Not set\"}"
  echo fmt"GITLAB_PERSONAL_ACCESS_TOKEN: {if gitlabToken != \"\": \"✓ Set\" else: \"✗ Not set\"}"
  
  if githubToken == "" and gitlabToken == "":
    echo "\nWarning: No tokens found. GitHub and GitLab features will be limited."
    echo "Set GITHUB_TOKEN and/or GITLAB_PERSONAL_ACCESS_TOKEN environment variables."
  
  echo "\nDetecting VCS and setting up MCP..."
  await detectAndSetupVcs()

proc mcpStopCommand*() =
  ## Stops all MCP servers
  echo "Stopping MCP integration..."
  shutdownMcpIntegration()

proc mcpListToolsCommand*(serverName: string = "") {.async.} =
  ## Lists available tools for MCP servers
  let manager = getMcpManager()
  
  if serverName != "":
    echo fmt"Tools for {serverName}:"
    echo "======================"
    let tools = await manager.listAvailableTools(serverName)
    for tool in tools:
      echo fmt"  - {tool}"
  else:
    echo "Available Tools by Server:"
    echo "=========================="
    
    for server in ["git", "github", "gitlab", "jujutsu"]:
      let tools = await manager.listAvailableTools(server)
      if tools.len > 0:
        echo fmt"\n{server}:"
        for tool in tools:
          echo fmt"  - {tool}"

proc mcpGitCommand*(args: seq[string]) {.async.} =
  ## Executes Git commands via MCP
  if args.len == 0:
    echo "Usage: nimble mcp-git <command> [args...]"
    return
  
  let command = args[0]
  
  try:
    case command:
    of "status":
      let result = await mcpGitStatus()
      echo result
    of "commit":
      if args.len < 2:
        echo "Usage: nimble mcp-git commit <message>"
        return
      let message = args[1..^1].join(" ")
      let result = await mcpGitCommit(message)
      echo result
    else:
      echo fmt"Unknown git command: {command}"
      echo "Available commands: status, commit"
  except Exception as e:
    echo fmt"Error: {e.msg}"

proc mcpGithubCommand*(args: seq[string]) {.async.} =
  ## Executes GitHub commands via MCP
  if args.len == 0:
    echo "Usage: nimble mcp-github <command> [args...]"
    return
  
  let vcsInfo = getVcsInfo()
  if vcsInfo.platform != "github":
    echo "Error: Not a GitHub repository or remote not detected"
    return
  
  let command = args[0]
  
  try:
    case command:
    of "create-issue":
      if args.len < 2:
        echo "Usage: nimble mcp-github create-issue <title> [body]"
        return
      let title = args[1]
      let body = if args.len > 2: args[2..^1].join(" ") else: ""
      let result = await mcpCreateGitHubIssue(vcsInfo.owner, vcsInfo.repo, title, body)
      echo result
    of "create-pr":
      if args.len < 3:
        echo "Usage: nimble mcp-github create-pr <title> <head-branch> [base-branch] [body]"
        return
      let title = args[1]
      let head = args[2]
      let base = if args.len > 3: args[3] else: "main"
      let body = if args.len > 4: args[4..^1].join(" ") else: ""
      let result = await mcpCreateGitHubPR(vcsInfo.owner, vcsInfo.repo, title, head, base, body)
      echo result
    else:
      echo fmt"Unknown GitHub command: {command}"
      echo "Available commands: create-issue, create-pr"
  except Exception as e:
    echo fmt"Error: {e.msg}"

proc mcpGitlabCommand*(args: seq[string]) {.async.} =
  ## Executes GitLab commands via MCP
  if args.len == 0:
    echo "Usage: nimble mcp-gitlab <command> [args...]"
    return
  
  let vcsInfo = getVcsInfo()
  if vcsInfo.platform != "gitlab":
    echo "Error: Not a GitLab repository or remote not detected"
    return
  
  let projectId = vcsInfo.owner & "/" & vcsInfo.repo
  let command = args[0]
  
  try:
    case command:
    of "create-issue":
      if args.len < 2:
        echo "Usage: nimble mcp-gitlab create-issue <title> [description]"
        return
      let title = args[1]
      let description = if args.len > 2: args[2..^1].join(" ") else: ""
      let result = await mcpCreateGitLabIssue(projectId, title, description)
      echo result
    of "create-mr":
      if args.len < 3:
        echo "Usage: nimble mcp-gitlab create-mr <title> <source-branch> [target-branch] [description]"
        return
      let title = args[1]
      let sourceBranch = args[2]
      let targetBranch = if args.len > 3: args[3] else: "main"
      let description = if args.len > 4: args[4..^1].join(" ") else: ""
      let result = await mcpCreateGitLabMR(projectId, title, sourceBranch, targetBranch, description)
      echo result
    else:
      echo fmt"Unknown GitLab command: {command}"
      echo "Available commands: create-issue, create-mr"
  except Exception as e:
    echo fmt"Error: {e.msg}"

proc mcpJujutsuCommand*(args: seq[string]) {.async.} =
  ## Executes Jujutsu commands via MCP
  if args.len == 0:
    echo "Usage: nimble mcp-jujutsu <command> [args...]"
    return
  
  let command = args[0]
  
  try:
    case command:
    of "status":
      let result = await mcpJujutsuStatus()
      echo result
    else:
      echo fmt"Unknown Jujutsu command: {command}"
      echo "Available commands: status"
  except Exception as e:
    echo fmt"Error: {e.msg}"

proc mcpHelpCommand*() =
  ## Shows MCP help information
  echo """
MCP (Model Context Protocol) Integration for Nim TestKit

Commands:
  mcp-status         Show MCP server status and VCS information
  mcp-setup          Set up MCP integration and start servers
  mcp-stop           Stop all MCP servers
  mcp-list-tools     List available tools for all servers
  mcp-git            Execute Git operations via MCP
  mcp-github         Execute GitHub operations via MCP
  mcp-gitlab         Execute GitLab operations via MCP
  mcp-jujutsu        Execute Jujutsu operations via MCP

Examples:
  nimble mcp-setup
  nimble mcp-status
  nimble mcp-git status
  nimble mcp-git commit "Add new feature"
  nimble mcp-github create-issue "Bug report" "Description of the bug"
  nimble mcp-github create-pr "Fix bug" "feature-branch" "main" "Fixes the bug"
  nimble mcp-gitlab create-issue "Enhancement request"
  nimble mcp-gitlab create-mr "Add feature" "feature-branch"
  nimble mcp-jujutsu status

Environment Variables:
  GITHUB_TOKEN                   GitHub personal access token
  GITLAB_PERSONAL_ACCESS_TOKEN   GitLab personal access token

Note: Tokens are required for GitHub and GitLab operations.
"""

# Main execution block for command-line usage
when isMainModule:
  import std/[os, strutils]
  
  proc main() {.async.} =
    when defined(mcp_setup):
      await mcpSetupCommand()
    elif defined(mcp_status):
      await mcpStatusCommand()
    elif defined(mcp_stop):
      mcpStopCommand()
    elif defined(mcp_list_tools):
      await mcpListToolsCommand()
    elif defined(mcp_git):
      let args = commandLineParams()
      await mcpGitCommand(args)
    elif defined(mcp_git_help):
      await mcpGitCommand(@[])
    elif defined(mcp_github):
      let args = commandLineParams()
      await mcpGithubCommand(args)
    elif defined(mcp_github_help):
      await mcpGithubCommand(@[])
    elif defined(mcp_gitlab):
      let args = commandLineParams()
      await mcpGitlabCommand(args)
    elif defined(mcp_gitlab_help):
      await mcpGitlabCommand(@[])
    elif defined(mcp_jujutsu):
      let args = commandLineParams()
      await mcpJujutsuCommand(args)
    elif defined(mcp_jujutsu_help):
      await mcpJujutsuCommand(@[])
    elif defined(mcp_help):
      mcpHelpCommand()
    else:
      mcpHelpCommand()
  
  waitFor main()