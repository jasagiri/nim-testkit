## Test MCP Integration
##
## Tests for MCP (Model Context Protocol) integration functionality

import unittest
import std/[os, asyncdispatch, strformat, tables, strutils, json, options]
import ../src/vcs_commands
import ../src/mcp/[mcp_types, mcp_client, mcp_manager]

suite "MCP Integration Tests":
  
  test "VCS type detection":
    let vcsType = detectVcsType()
    check vcsType in [vcsNone, vcsGit, vcsJujutsu]
  
  test "VCS info retrieval":
    let vcsInfo = getVcsInfo()
    check vcsInfo.vcsType in [vcsNone, vcsGit, vcsJujutsu]
    # Remote URL can be empty for local repos
  
  test "MCP types creation":
    let config = DEFAULT_GIT_SERVER
    check config.name == "git"
    check config.enabled == true
    check mcpTools in config.capabilities
  
  test "MCP manager creation":
    let manager = newMcpManager()
    check manager != nil
    check len(manager.clients) == 0
    check manager.activeServers.len == 0
  
  test "MCP manager initialization":
    let manager = initializeMcpManager()
    check manager != nil
    
    # Test environment token loading
    manager.loadEnvironmentTokens()
    
    # Test server path setup
    manager.setupServerPaths("vendor")
    
    # Verify paths are updated
    check "vendor" in manager.config.git.args[1]
  
  test "MCP message creation":
    let msg = newMcpMessage(id = %1, `method` = "test", params = %*{"test": "value"})
    check msg.jsonrpc == "2.0"
    check msg.id.isSome
    check msg.`method`.isSome
    check msg.params.isSome
  
  test "MCP error creation":
    let error = newMcpError(MCP_INVALID_REQUEST, "Invalid request")
    check error.code == MCP_INVALID_REQUEST
    check error.message == "Invalid request"
  
  test "URL parsing for GitHub":
    let repoInfo = parseRepoInfo("https://github.com/user/repo.git")
    check repoInfo.platform == "github"
    check repoInfo.owner == "user"
    check repoInfo.repo == "repo"
  
  test "URL parsing for GitLab":
    let repoInfo = parseRepoInfo("https://gitlab.com/user/repo.git")
    check repoInfo.platform == "gitlab"
    check repoInfo.owner == "user"
    check repoInfo.repo == "repo"
  
  test "SSH URL parsing":
    let repoInfo = parseRepoInfo("git@github.com:user/repo.git")
    check repoInfo.platform == "github"
    check repoInfo.owner == "user" 
    check repoInfo.repo == "repo"

# Only run server tests if vendor directory exists
if dirExists("vendor"):
  suite "MCP Server Integration Tests":
    
    test "Server configuration validation":
      # Check if required files exist
      let gitServerPath = "vendor/servers/src/git"
      let githubServerPath = "vendor/servers/src/github/index.js"
      let gitlabServerPath = "vendor/servers/src/gitlab/index.js"
      
      if dirExists(gitServerPath):
        echo "Git MCP server found at: " & gitServerPath
      else:
        echo "Git MCP server not found, skipping server tests"
      
      if fileExists(githubServerPath):
        echo "GitHub MCP server found at: " & githubServerPath
      else:
        echo "GitHub MCP server not found"
      
      if fileExists(gitlabServerPath):
        echo "GitLab MCP server found at: " & gitlabServerPath
      else:
        echo "GitLab MCP server not found"
    
    test "MCP manager server status":
      let manager = initializeMcpManager()
      let status = manager.getServerStatus()
      
      # Initially all servers should be stopped
      for serverName, running in status:
        check running == false
        echo "Server " & serverName & ": " & (if running: "running" else: "stopped")

else:
  echo "Vendor directory not found - skipping server integration tests"
  echo "Run 'git submodule update --init --recursive' to get MCP servers"